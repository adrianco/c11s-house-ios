/*
 * CONTEXT & PURPOSE:
 * HomeKitService provides integration with Apple's HomeKit framework to discover and read
 * home configurations. It converts HomeKit entities (homes, rooms, accessories) into notes
 * that are stored in the NotesService, making HomeKit configuration part of the app's
 * persistent memory and AI context.
 *
 * DECISION HISTORY:
 * - 2025-07-23: Initial implementation
 *   - Protocol-based design for testability
 *   - Async/await API for HomeKit operations
 *   - Automatic permission handling with HMHomeManager
 *   - Converts HomeKit data to notes for persistence
 *   - Summary note for entire configuration
 *   - Individual notes for rooms and devices
 *   - Thread-safe with @MainActor annotations
 *   - Error handling for permission and discovery failures
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  HomeKitService.swift
//  C11SHouse
//
//  Service for HomeKit integration and configuration discovery
//

import Foundation
import HomeKit
import Combine

/// Protocol defining HomeKit service interface
protocol HomeKitServiceProtocol {
    /// Publisher for HomeKit authorization status
    var authorizationStatusPublisher: AnyPublisher<HMHomeManagerAuthorizationStatus, Never> { get }
    
    /// Request HomeKit authorization if needed
    func requestAuthorization() async -> Bool
    
    /// Discover all HomeKit homes and configurations
    func discoverHomes() async throws -> HomeKitDiscoverySummary
    
    /// Save HomeKit configuration as notes
    func saveConfigurationAsNotes(summary: HomeKitDiscoverySummary) async throws
    
    /// Get specific home by name
    func getHome(named name: String) async -> HomeKitHome?
    
    /// Get all discovered homes
    func getAllHomes() async -> [HomeKitHome]
}

/// Concrete implementation of HomeKit service
@MainActor
class HomeKitService: NSObject, HomeKitServiceProtocol {
    
    // MARK: - Properties
    
    private let homeManager = HMHomeManager()
    private let notesService: NotesServiceProtocol
    private var discoveredHomes: [HomeKitHome] = []
    
    private let authorizationStatusSubject = CurrentValueSubject<HMHomeManagerAuthorizationStatus, Never>(.determined)
    var authorizationStatusPublisher: AnyPublisher<HMHomeManagerAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }
    
    private var homeManagerReadyContinuation: CheckedContinuation<Void, Never>?
    private var isHomeManagerReady = false
    
    // MARK: - Initialization
    
    init(notesService: NotesServiceProtocol) {
        self.notesService = notesService
        super.init()
        
        homeManager.delegate = self
        print("[HomeKitService] Initialized with delegate set, initial status: \(homeManager.authorizationStatus.rawValue)")
        
        // Update initial authorization status
        authorizationStatusSubject.send(homeManager.authorizationStatus)
        
        // Trigger HomeManager to start loading homes
        _ = homeManager.homes
    }
    
    // MARK: - Public Methods
    
    func requestAuthorization() async -> Bool {
        // HomeKit authorization is handled automatically when accessing homes
        // Just check if we have access
        // Note: Status 5 appears to be a special case in some environments
        let status = homeManager.authorizationStatus
        return status == .authorized || status.rawValue == 5
    }
    
    func discoverHomes() async throws -> HomeKitDiscoverySummary {
        // Ensure we have authorization
        // Note: Status 5 appears to be a special case in some environments
        let status = homeManager.authorizationStatus
        guard status == .authorized || status.rawValue == 5 else {
            print("[HomeKitService] Authorization check failed. Status: \(status.rawValue)")
            throw HomeKitError.notAuthorized
        }
        
        // Wait for HomeManager to be ready if needed
        if !isHomeManagerReady {
            await withCheckedContinuation { continuation in
                self.homeManagerReadyContinuation = continuation
                // Check if already ready
                if self.isHomeManagerReady {
                    continuation.resume()
                    self.homeManagerReadyContinuation = nil
                }
            }
        }
        
        // Convert HMHome objects to our models
        discoveredHomes = homeManager.homes.map { HomeKitHome(from: $0) }
        
        return HomeKitDiscoverySummary(
            homes: discoveredHomes,
            discoveredAt: Date()
        )
    }
    
    func saveConfigurationAsNotes(summary: HomeKitDiscoverySummary) async throws {
        print("[HomeKitService] Saving HomeKit configuration as notes...")
        print("[HomeKitService] Found \(summary.homes.count) homes")
        
        // Save the main summary note
        let summaryNote = summary.generateFullSummary()
        await notesService.saveCustomNote(
            title: "HomeKit Configuration Summary",
            content: summaryNote,
            category: "homekit_summary"
        )
        print("[HomeKitService] Saved summary note")
        
        var roomCount = 0
        var accessoryCount = 0
        
        // Save individual room notes
        for home in summary.homes {
            for room in home.rooms {
                let roomAccessories = home.accessories.filter { $0.roomId == room.id }
                let roomNote = room.generateNote(with: roomAccessories)
                
                await notesService.saveCustomNote(
                    title: "Room: \(room.name) (\(home.name))",
                    content: roomNote,
                    category: "homekit_room"
                )
                roomCount += 1
            }
            
            // Save individual accessory notes for accessories not in rooms
            let unassignedAccessories = home.accessories.filter { $0.roomId == nil }
            for accessory in unassignedAccessories {
                let accessoryNote = accessory.generateNote()
                
                await notesService.saveCustomNote(
                    title: "Device: \(accessory.name) (\(home.name))",
                    content: accessoryNote,
                    category: "homekit_device"
                )
                accessoryCount += 1
            }
        }
        
        print("[HomeKitService] Saved \(roomCount) room notes and \(accessoryCount) unassigned accessory notes")
    }
    
    func getHome(named name: String) async -> HomeKitHome? {
        discoveredHomes.first { $0.name.lowercased() == name.lowercased() }
    }
    
    func getAllHomes() async -> [HomeKitHome] {
        discoveredHomes
    }
}

// MARK: - HMHomeManagerDelegate

extension HomeKitService: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        print("[HomeKitService] homeManagerDidUpdateHomes called, homes count: \(manager.homes.count)")
        
        // Mark home manager as ready
        if !isHomeManagerReady {
            isHomeManagerReady = true
            homeManagerReadyContinuation?.resume()
            homeManagerReadyContinuation = nil
        }
        
        // Update discovered homes when HomeKit configuration changes
        Task {
            _ = try? await discoverHomes()
        }
    }
    
    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        print("[HomeKitService] Authorization status updated to: \(status.rawValue)")
        authorizationStatusSubject.send(status)
        
        // If not authorized (and not the special status 5), mark as ready to avoid hanging
        if status != .authorized && status.rawValue != 5 && !isHomeManagerReady {
            isHomeManagerReady = true
            homeManagerReadyContinuation?.resume()
            homeManagerReadyContinuation = nil
        }
    }
}

// MARK: - Error Types

enum HomeKitError: LocalizedError {
    case notAuthorized
    case noHomesFound
    case discoveryFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "HomeKit access not authorized. Please grant permission in Settings."
        case .noHomesFound:
            return "No HomeKit homes found. Set up homes in the Home app first."
        case .discoveryFailed(let reason):
            return "Failed to discover HomeKit configuration: \(reason)"
        }
    }
}
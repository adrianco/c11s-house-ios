/*
 * CONTEXT & PURPOSE:
 * HomeKitCoordinator manages the business logic for HomeKit integration. It coordinates
 * between the HomeKitService and NotesService to discover HomeKit configurations and
 * save them as notes. This follows the app's pattern of using coordinators to separate
 * business logic from services and UI.
 *
 * DECISION HISTORY:
 * - 2025-07-23: Initial implementation
 *   - Coordinates HomeKit discovery and note creation
 *   - Handles authorization flow
 *   - Manages error states and retry logic
 *   - Provides status updates via Combine
 *   - Thread-safe with @MainActor
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  HomeKitCoordinator.swift
//  C11SHouse
//
//  Coordinator for HomeKit discovery and note creation
//

import Foundation
import Combine
import HomeKit

/// Status of HomeKit discovery process
enum HomeKitDiscoveryStatus {
    case idle
    case checkingAuthorization
    case discovering
    case savingNotes
    case completed(HomeKitDiscoverySummary)
    case failed(Error)
}

/// Coordinator for HomeKit integration
@MainActor
class HomeKitCoordinator: ObservableObject {
    
    // MARK: - Properties
    
    private let homeKitService: HomeKitServiceProtocol
    private let notesService: NotesServiceProtocol
    
    @Published private(set) var discoveryStatus: HomeKitDiscoveryStatus = .idle
    @Published private(set) var isAuthorized: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(homeKitService: HomeKitServiceProtocol, notesService: NotesServiceProtocol) {
        self.homeKitService = homeKitService
        self.notesService = notesService
        
        // Monitor authorization status
        // Note: Status 5 appears to be a special case in some environments
        homeKitService.authorizationStatusPublisher
            .map { $0 == .authorized || $0.rawValue == 5 }
            .assign(to: &$isAuthorized)
    }
    
    // MARK: - Public Methods
    
    /// Discover HomeKit configuration and save as notes
    func discoverAndSaveConfiguration() async {
        discoveryStatus = .checkingAuthorization
        
        // Check authorization
        let authorized = await homeKitService.requestAuthorization()
        guard authorized else {
            discoveryStatus = .failed(HomeKitError.notAuthorized)
            return
        }
        
        // Check if we already have HomeKit notes saved
        let hasExistingNotes = await checkForExistingHomeKitNotes()
        
        discoveryStatus = .discovering
        
        do {
            // Discover homes
            let summary = try await homeKitService.discoverHomes()
            
            if summary.homes.isEmpty {
                discoveryStatus = .failed(HomeKitError.noHomesFound)
                return
            }
            
            // Only save notes if we don't have existing ones
            if !hasExistingNotes {
                discoveryStatus = .savingNotes
                
                // Save configuration as notes
                try await homeKitService.saveConfigurationAsNotes(summary: summary)
            }
            
            discoveryStatus = .completed(summary)
            
        } catch {
            discoveryStatus = .failed(error)
        }
    }
    
    /// Check if HomeKit notes already exist
    private func checkForExistingHomeKitNotes() async -> Bool {
        do {
            let notesStore = try await notesService.loadNotesStore()
            // Check if we have any HomeKit custom notes
            return notesStore.questions.contains { question in
                if let metadata = notesStore.notes[question.id]?.metadata,
                   let category = metadata["category"] {
                    return category == "homekit_summary" || 
                           category == "homekit_room" || 
                           category == "homekit_device"
                }
                return false
            }
        } catch {
            return false
        }
    }
    
    /// Reset discovery status to idle
    func reset() {
        discoveryStatus = .idle
    }
    
    /// Check if HomeKit has been configured
    func hasHomeKitConfiguration() async -> Bool {
        let homes = await homeKitService.getAllHomes()
        return !homes.isEmpty
    }
    
    /// Get a specific home by name
    func getHome(named name: String) async -> HomeKitHome? {
        await homeKitService.getHome(named: name)
    }
    
    /// Refresh HomeKit configuration
    func refreshConfiguration() async {
        await discoverAndSaveConfiguration()
    }
}
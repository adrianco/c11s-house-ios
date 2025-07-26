/*
 * CONTEXT & PURPOSE:
 * PermissionManager centralizes the management of microphone and speech recognition permissions
 * required for voice-based interactions in the C11S House app. It provides a reactive interface
 * using Combine publishers to track permission states and handles permission requests with 
 * proper async/await patterns.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Singleton pattern for app-wide permission state management
 *   - @MainActor for thread-safe UI state updates
 *   - Separate tracking of microphone and speech recognition permissions
 *   - Combined allPermissionsGranted flag for convenience
 *   - Published properties for reactive UI updates via Combine
 *   - Async/await API using withCheckedContinuation for permission requests
 *   - Auto-recheck permissions when app becomes active
 *   - Error messages stored for user feedback
 *   - Helper method to open Settings app for manual permission grants
 *   - Typed permission enum for type-safe permission queries
 *   - Human-readable status descriptions for UI display
 *   - Extension methods for convenience boolean checks
 *
 * - 2025-01-09: iOS 18+ migration and Swift 6 concurrency fixes
 *   - Kept AVAudioSession.RecordPermission type (still used in iOS 18)
 *   - Updated requestRecordPermission to use AVAudioApplication async/await API
 *   - Removed withCheckedContinuation wrapper for cleaner async code
 *   - Fixed recordPermission property access to use AVAudioSession.sharedInstance()
 *   - Use fully qualified enum cases (AVAudioSession.RecordPermission.*) to avoid deprecation warnings
 *   - Added @preconcurrency to Speech import to suppress Sendable warnings
 * - 2025-07-25: Fixed method accessibility
 *   - Changed checkCurrentPermissionsExceptHomeKit from private to internal
 *   - Allows ConversationView to call it when checking initial mute state
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  PermissionManager.swift
//  C11SHouse
//
//  Created on 2025-07-03
//  Manages microphone and speech recognition permissions for voice control
//

import Foundation
import AVFoundation
import AVFAudio
@preconcurrency import Speech
import Combine
import UIKit
import CoreLocation
import HomeKit

/// Manages permissions for microphone and speech recognition
@MainActor
public final class PermissionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current microphone permission status
    @Published public private(set) var microphonePermissionStatus: AVAudioSession.RecordPermission = AVAudioSession.RecordPermission.undetermined
    
    /// Current speech recognition permission status
    @Published public private(set) var speechRecognitionPermissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    /// Current location permission status
    @Published public private(set) var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    
    /// Current HomeKit permission status
    @Published public private(set) var homeKitPermissionStatus: HMHomeManagerAuthorizationStatus = .determined
    
    /// Combined status indicating if all permissions are granted
    @Published public private(set) var allPermissionsGranted: Bool = false
    
    /// Error message if permission request fails
    @Published public private(set) var permissionError: String?
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    public static let shared = PermissionManager()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var _homeManager: HMHomeManager?
    private var homeKitAuthorizationContinuation: CheckedContinuation<Void, Never>?
    
    // Lazy initialization to prevent permission dialog at startup
    private var homeManager: HMHomeManager {
        if _homeManager == nil {
            print("[PermissionManager] Initializing HMHomeManager for first time")
            _homeManager = HMHomeManager()
            _homeManager?.delegate = self
        }
        return _homeManager!
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        #if !DEBUG
        setupObservers()
        // Don't check HomeKit permissions here - it will trigger the dialog
        checkCurrentPermissionsExceptHomeKit()
        #endif
        // In DEBUG builds, don't set up observers or check permissions for test instances
    }
    
    // MARK: - Public Methods
    
    /// Check if a specific permission is granted
    public func isPermissionGranted(_ permission: PermissionType) -> Bool {
        switch permission {
        case .microphone:
            return microphonePermissionStatus == .granted
        case .speechRecognition:
            return speechRecognitionPermissionStatus == .authorized
        case .location:
            return locationPermissionStatus == .authorizedWhenInUse || locationPermissionStatus == .authorizedAlways
        case .homeKit:
            return homeKitPermissionStatus == .authorized
        }
    }
    
    /// Open app settings for user to manually enable permissions
    public func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Monitor app becoming active to recheck permissions
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkCurrentPermissions()
                }
            }
            .store(in: &cancellables)
    }
    
    public func checkCurrentPermissions() {
        microphonePermissionStatus = AVAudioSession.sharedInstance().recordPermission
        speechRecognitionPermissionStatus = SFSpeechRecognizer.authorizationStatus()
        locationPermissionStatus = CLLocationManager().authorizationStatus
        
        // Only check HomeKit if already initialized
        if _homeManager != nil {
            let oldHomeKitStatus = homeKitPermissionStatus
            homeKitPermissionStatus = homeManager.authorizationStatus
            
            if oldHomeKitStatus != homeKitPermissionStatus {
                print("[PermissionManager] checkCurrentPermissions: HomeKit status changed from \(oldHomeKitStatus.rawValue) to \(homeKitPermissionStatus.rawValue)")
            }
        }
        
        updateAllPermissionsStatus()
    }
    
    func checkCurrentPermissionsExceptHomeKit() {
        microphonePermissionStatus = AVAudioSession.sharedInstance().recordPermission
        speechRecognitionPermissionStatus = SFSpeechRecognizer.authorizationStatus()
        locationPermissionStatus = CLLocationManager().authorizationStatus
        // Don't check HomeKit here
        updateAllPermissionsStatus()
    }
    
    private func updateAllPermissionsStatus() {
        allPermissionsGranted = microphonePermissionStatus == AVAudioSession.RecordPermission.granted &&
                               speechRecognitionPermissionStatus == .authorized
        // Location is optional, so don't require it for allPermissionsGranted
        
        // Clear error if all permissions are granted
        if allPermissionsGranted {
            permissionError = nil
        }
    }
}

// MARK: - Supporting Types

/// Types of permissions managed by PermissionManager
public enum PermissionType {
    case microphone
    case speechRecognition
    case location
    case homeKit
}

// MARK: - Extensions

extension PermissionManager {
    /// Convenience computed properties for permission status
    public var isMicrophoneGranted: Bool {
        microphonePermissionStatus == AVAudioSession.RecordPermission.granted
    }
    
    public var isSpeechRecognitionGranted: Bool {
        speechRecognitionPermissionStatus == .authorized
    }
    
    public var hasLocationPermission: Bool {
        locationPermissionStatus == .authorizedWhenInUse || locationPermissionStatus == .authorizedAlways
    }
    
    public var isHomeKitGranted: Bool {
        // Don't check if homeManager isn't initialized yet
        guard _homeManager != nil else {
            print("[PermissionManager] isHomeKitGranted check: HomeManager not initialized, returning false")
            return false
        }
        
        // Check the raw value to understand what the actual status is
        let rawValue = homeKitPermissionStatus.rawValue
        
        // HMHomeManagerAuthorizationStatus raw values (from iOS logs):
        // 0 = determined (initial state, changes to 5 when delegate is set)
        // 1 = restricted 
        // 2 = authorized
        // 5 = not determined (need to ask for permission) - seen in logs
        // The status changes from 0 to 5 when HMHomeManager delegate is set
        let granted = rawValue == 2 // authorized
        
        print("[PermissionManager] isHomeKitGranted check: rawValue=\(rawValue), granted=\(granted)")
        return granted
    }
    
    /// Human-readable permission status descriptions
    public var microphoneStatusDescription: String {
        switch microphonePermissionStatus {
        case AVAudioSession.RecordPermission.undetermined:
            return "Not requested"
        case AVAudioSession.RecordPermission.denied:
            return "Denied"
        case AVAudioSession.RecordPermission.granted:
            return "Granted"
        @unknown default:
            return "Unknown"
        }
    }
    
    public var speechRecognitionStatusDescription: String {
        switch speechRecognitionPermissionStatus {
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .authorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }
    
    public var locationStatusDescription: String {
        switch locationPermissionStatus {
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .authorizedAlways:
            return "Always authorized"
        case .authorizedWhenInUse:
            return "When in use"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - HMHomeManagerDelegate

extension PermissionManager: HMHomeManagerDelegate {
    public func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        // Update permission status when homes are updated
        let oldStatus = homeKitPermissionStatus
        homeKitPermissionStatus = manager.authorizationStatus
        print("[PermissionManager] homeManagerDidUpdateHomes called: oldStatus=\(oldStatus.rawValue), newStatus=\(manager.authorizationStatus.rawValue)")
        
        // Force UI update if status changed
        if oldStatus != manager.authorizationStatus {
            Task { @MainActor in
                objectWillChange.send()
            }
        }
    }
    
    public func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        // Update permission status when authorization changes
        let oldStatus = homeKitPermissionStatus
        print("[PermissionManager] homeManager:didUpdate:status called: oldStatus=\(oldStatus.rawValue), newStatus=\(status.rawValue)")
        homeKitPermissionStatus = status
        
        // Force UI update and trigger any waiting continuations
        Task { @MainActor in
            objectWillChange.send()
            updateAllPermissionsStatus()
            
            // Resume any waiting continuation
            if let continuation = homeKitAuthorizationContinuation {
                homeKitAuthorizationContinuation = nil
                continuation.resume()
            }
        }
    }
}
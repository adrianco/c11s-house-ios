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
public final class PermissionManager: ObservableObject {
    
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
    private let homeManager = HMHomeManager()
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        checkCurrentPermissions()
        // Set HomeKit delegate
        homeManager.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// Request all required permissions (microphone and speech recognition)
    public func requestAllPermissions() async {
        await requestMicrophonePermission()
        await requestSpeechRecognitionPermission()
        await requestLocationPermission()
    }
    
    /// Request microphone permission
    public func requestMicrophonePermission() async {
        let currentPermission = AVAudioSession.sharedInstance().recordPermission
        
        switch currentPermission {
        case AVAudioSession.RecordPermission.undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            microphonePermissionStatus = granted ? AVAudioSession.RecordPermission.granted : AVAudioSession.RecordPermission.denied
            updateAllPermissionsStatus()
        case AVAudioSession.RecordPermission.denied:
            microphonePermissionStatus = AVAudioSession.RecordPermission.denied
            permissionError = "Microphone access denied. Please enable it in Settings."
        case AVAudioSession.RecordPermission.granted:
            microphonePermissionStatus = AVAudioSession.RecordPermission.granted
        @unknown default:
            microphonePermissionStatus = AVAudioSession.RecordPermission.denied
        }
        updateAllPermissionsStatus()
    }
    
    /// Request speech recognition permission
    public func requestSpeechRecognitionPermission() async {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { [weak self] status in
                    Task { @MainActor in
                        self?.speechRecognitionPermissionStatus = status
                        self?.updateAllPermissionsStatus()
                        continuation.resume()
                    }
                }
            }
        case .denied:
            speechRecognitionPermissionStatus = .denied
            permissionError = "Speech recognition access denied. Please enable it in Settings."
        case .restricted:
            speechRecognitionPermissionStatus = .restricted
            permissionError = "Speech recognition is restricted on this device."
        case .authorized:
            speechRecognitionPermissionStatus = .authorized
        @unknown default:
            speechRecognitionPermissionStatus = .denied
        }
        updateAllPermissionsStatus()
    }
    
    /// Request location permission
    public func requestLocationPermission() async {
        let locationManager = CLLocationManager()
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .notDetermined:
            // Request permission through location manager
            locationManager.requestWhenInUseAuthorization()
            // Note: The actual permission result will be received through the delegate
            // For now, we just update the status
            locationPermissionStatus = currentStatus
        case .denied, .restricted:
            locationPermissionStatus = currentStatus
            permissionError = "Location access denied. Please enable it in Settings."
        case .authorizedAlways, .authorizedWhenInUse:
            locationPermissionStatus = currentStatus
        @unknown default:
            locationPermissionStatus = .denied
        }
        updateAllPermissionsStatus()
    }
    
    /// Request HomeKit permission
    public func requestHomeKitPermission() async {
        // HomeKit permission is requested automatically when accessing homes
        // We just need to check the current status
        homeKitPermissionStatus = homeManager.authorizationStatus
        
        // If it's determined (not asked yet), accessing homes will trigger the permission dialog
        if homeManager.authorizationStatus == .determined {
            // Access homes to trigger permission dialog
            _ = homeManager.homes
            // Wait a moment for the permission dialog to be handled
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            homeKitPermissionStatus = homeManager.authorizationStatus
            
            // Force refresh UI
            await MainActor.run {
                objectWillChange.send()
            }
        }
        
        updateAllPermissionsStatus()
    }
    
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
        homeKitPermissionStatus = homeManager.authorizationStatus
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
        homeKitPermissionStatus == .authorized
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
        homeKitPermissionStatus = manager.authorizationStatus
    }
    
    public func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        // Update permission status when authorization changes
        homeKitPermissionStatus = status
    }
}
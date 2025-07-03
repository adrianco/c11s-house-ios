//
//  PermissionManager.swift
//  C11SHouse
//
//  Created on 2025-07-03
//  Manages microphone and speech recognition permissions for voice control
//

import Foundation
import AVFoundation
import Speech
import Combine
import UIKit

/// Manages permissions for microphone and speech recognition
@MainActor
public final class PermissionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current microphone permission status
    @Published public private(set) var microphonePermissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    /// Current speech recognition permission status
    @Published public private(set) var speechRecognitionPermissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    /// Combined status indicating if all permissions are granted
    @Published public private(set) var allPermissionsGranted: Bool = false
    
    /// Error message if permission request fails
    @Published public private(set) var permissionError: String?
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    public static let shared = PermissionManager()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        checkCurrentPermissions()
    }
    
    // MARK: - Public Methods
    
    /// Request all required permissions (microphone and speech recognition)
    public func requestAllPermissions() async {
        await requestMicrophonePermission()
        await requestSpeechRecognitionPermission()
    }
    
    /// Request microphone permission
    public func requestMicrophonePermission() async {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                    Task { @MainActor in
                        self?.microphonePermissionStatus = granted ? .granted : .denied
                        self?.updateAllPermissionsStatus()
                        continuation.resume()
                    }
                }
            }
        case .denied:
            microphonePermissionStatus = .denied
            permissionError = "Microphone access denied. Please enable it in Settings."
        case .granted:
            microphonePermissionStatus = .granted
        @unknown default:
            microphonePermissionStatus = .denied
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
    
    /// Check if a specific permission is granted
    public func isPermissionGranted(_ permission: PermissionType) -> Bool {
        switch permission {
        case .microphone:
            return microphonePermissionStatus == .granted
        case .speechRecognition:
            return speechRecognitionPermissionStatus == .authorized
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
    
    private func checkCurrentPermissions() {
        microphonePermissionStatus = AVAudioSession.sharedInstance().recordPermission
        speechRecognitionPermissionStatus = SFSpeechRecognizer.authorizationStatus()
        updateAllPermissionsStatus()
    }
    
    private func updateAllPermissionsStatus() {
        allPermissionsGranted = microphonePermissionStatus == .granted &&
                               speechRecognitionPermissionStatus == .authorized
        
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
}

// MARK: - Extensions

extension PermissionManager {
    /// Convenience computed properties for permission status
    public var isMicrophoneGranted: Bool {
        microphonePermissionStatus == .granted
    }
    
    public var isSpeechRecognitionGranted: Bool {
        speechRecognitionPermissionStatus == .authorized
    }
    
    /// Human-readable permission status descriptions
    public var microphoneStatusDescription: String {
        switch microphonePermissionStatus {
        case .undetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .granted:
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
}
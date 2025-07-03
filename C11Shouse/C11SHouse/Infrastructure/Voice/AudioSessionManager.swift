//
//  AudioSessionManager.swift
//  C11SHouse
//
//  Created on 2025-07-03
//

import Foundation
import AVFoundation
import Combine

/// Manages the AVAudioSession configuration and lifecycle for voice recording
@MainActor
final class AudioSessionManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    /// Singleton instance for app-wide audio session management
    static let shared = AudioSessionManager()
    
    /// Published state for session activation status
    @Published private(set) var isSessionActive = false
    
    /// Published state for recording permission
    @Published private(set) var hasRecordingPermission = false
    
    /// Published state for current audio route
    @Published private(set) var currentRoute: AVAudioSession.RouteDescription?
    
    /// The audio session instance
    private let audioSession = AVAudioSession.sharedInstance()
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupNotifications()
        checkRecordingPermission()
    }
    
    // MARK: - Public Methods
    
    /// Configures the audio session for recording
    /// - Throws: AudioSessionError if configuration fails
    func configureForRecording() async throws {
        do {
            // Set the audio session category with options for recording
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            
            // Configure preferred settings
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms buffer for low latency
            
            // Update the current route
            currentRoute = audioSession.currentRoute
            
        } catch {
            throw AudioSessionError.configurationFailed(error)
        }
    }
    
    /// Activates the audio session
    /// - Throws: AudioSessionError if activation fails
    func activateSession() async throws {
        guard hasRecordingPermission else {
            throw AudioSessionError.permissionDenied
        }
        
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isSessionActive = true
        } catch {
            throw AudioSessionError.activationFailed(error)
        }
    }
    
    /// Deactivates the audio session
    /// - Throws: AudioSessionError if deactivation fails
    func deactivateSession() async throws {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isSessionActive = false
        } catch {
            throw AudioSessionError.deactivationFailed(error)
        }
    }
    
    /// Requests recording permission from the user
    /// - Returns: Boolean indicating if permission was granted
    @discardableResult
    func requestRecordingPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.hasRecordingPermission = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up audio session notifications
    private func setupNotifications() {
        // Audio interruption notifications
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .compactMap { $0.userInfo }
            .sink { [weak self] userInfo in
                self?.handleInterruption(userInfo: userInfo)
            }
            .store(in: &cancellables)
        
        // Route change notifications
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .compactMap { $0.userInfo }
            .sink { [weak self] userInfo in
                self?.handleRouteChange(userInfo: userInfo)
            }
            .store(in: &cancellables)
        
        // Media services reset notification
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleMediaServicesReset()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Checks the current recording permission status
    private func checkRecordingPermission() {
        switch audioSession.recordPermission {
        case .granted:
            hasRecordingPermission = true
        case .denied, .undetermined:
            hasRecordingPermission = false
        @unknown default:
            hasRecordingPermission = false
        }
    }
    
    /// Handles audio interruptions
    /// - Parameter userInfo: Notification user info dictionary
    private func handleInterruption(userInfo: [AnyHashable: Any]) {
        guard let typeValue = userInfo[AVAudioSession.interruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio session was interrupted
            Task { @MainActor in
                isSessionActive = false
                NotificationCenter.default.post(
                    name: .audioSessionInterruptionBegan,
                    object: nil
                )
            }
            
        case .ended:
            // Interruption ended, check if we should resume
            if let optionsValue = userInfo[AVAudioSession.interruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    Task { @MainActor in
                        do {
                            try await activateSession()
                            NotificationCenter.default.post(
                                name: .audioSessionInterruptionEnded,
                                object: nil,
                                userInfo: ["shouldResume": true]
                            )
                        } catch {
                            print("Failed to reactivate session after interruption: \(error)")
                        }
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
    
    /// Handles audio route changes
    /// - Parameter userInfo: Notification user info dictionary
    private func handleRouteChange(userInfo: [AnyHashable: Any]) {
        guard let reasonValue = userInfo[AVAudioSession.routeChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        Task { @MainActor in
            currentRoute = audioSession.currentRoute
            
            switch reason {
            case .newDeviceAvailable:
                NotificationCenter.default.post(
                    name: .audioRouteChanged,
                    object: nil,
                    userInfo: ["reason": "newDeviceAvailable"]
                )
                
            case .oldDeviceUnavailable:
                NotificationCenter.default.post(
                    name: .audioRouteChanged,
                    object: nil,
                    userInfo: ["reason": "oldDeviceUnavailable"]
                )
                
            default:
                break
            }
        }
    }
    
    /// Handles media services reset
    private func handleMediaServicesReset() async {
        // Reconfigure audio session after media services reset
        do {
            try await configureForRecording()
            if isSessionActive {
                try await activateSession()
            }
            NotificationCenter.default.post(
                name: .audioSessionMediaServicesReset,
                object: nil
            )
        } catch {
            print("Failed to reconfigure audio session after media services reset: \(error)")
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during audio session management
enum AudioSessionError: LocalizedError {
    case permissionDenied
    case configurationFailed(Error)
    case activationFailed(Error)
    case deactivationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required for voice recording"
        case .configurationFailed(let error):
            return "Failed to configure audio session: \(error.localizedDescription)"
        case .activationFailed(let error):
            return "Failed to activate audio session: \(error.localizedDescription)"
        case .deactivationFailed(let error):
            return "Failed to deactivate audio session: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let audioSessionInterruptionBegan = Notification.Name("audioSessionInterruptionBegan")
    static let audioSessionInterruptionEnded = Notification.Name("audioSessionInterruptionEnded")
    static let audioRouteChanged = Notification.Name("audioRouteChanged")
    static let audioSessionMediaServicesReset = Notification.Name("audioSessionMediaServicesReset")
}
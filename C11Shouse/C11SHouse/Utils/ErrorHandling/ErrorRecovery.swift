//
//  ErrorRecovery.swift
//  c11s-house-ios
//
//  Created by Claude on 2025-07-15.
//

import SwiftUI
import CoreLocation

/// Common error recovery actions that can be performed
struct ErrorRecovery {
    
    /// Opens the app's settings page where users can grant permissions
    static func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    /// Checks network connectivity status
    static func checkNetworkConnectivity() async -> Bool {
        // Simple connectivity check - try to reach a reliable endpoint
        guard let url = URL(string: "https://www.apple.com") else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    /// Request location permissions if not already granted
    static func requestLocationPermission() {
        let locationManager = CLLocationManager()
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            openAppSettings()
        default:
            break
        }
    }
    
    /// Request microphone permissions
    static func requestMicrophonePermission() async -> Bool {
        #if os(iOS)
        return await AVAudioApplication.requestRecordPermission()
        #else
        // For macOS or other platforms
        return true
        #endif
    }
    
    /// Retry a failed operation with exponential backoff
    static func retryWithBackoff<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxAttempts - 1 {
                    let delay = initialDelay * pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AppError.unknown(NSError(domain: "ErrorRecovery", code: -1))
    }
    
    /// Clear app caches to recover from data corruption
    static func clearAppCaches() {
        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear temporary directory
        let tempDirectory = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        // Clear user defaults cache (be selective about what to clear)
        UserDefaults.standard.synchronize()
    }
    
    /// Performs a series of recovery actions based on the error type
    static func performRecovery(for error: UserFriendlyError) async -> RecoveryResult {
        switch error {
        case let appError as AppError:
            return await performAppErrorRecovery(appError)
        default:
            return .failed(reason: "No recovery action available")
        }
    }
    
    private static func performAppErrorRecovery(_ error: AppError) async -> RecoveryResult {
        switch error {
        case .networkUnavailable:
            let isConnected = await checkNetworkConnectivity()
            return isConnected ? .succeeded : .failed(reason: "Still no network connection")
            
        case .locationAccessDenied:
            requestLocationPermission()
            return .requiresUserAction(action: "Grant location permission in Settings")
            
        case .microphoneAccessDenied:
            let granted = await requestMicrophonePermission()
            return granted ? .succeeded : .requiresUserAction(action: "Grant microphone permission in Settings")
            
        case .weatherServiceUnavailable:
            // Try again with backoff
            return .retry
            
        case .voiceRecognitionFailed:
            // User should try again
            return .retry
            
        case .dataCorrupted:
            clearAppCaches()
            return .succeeded
            
        case .unknown:
            return .failed(reason: "Unknown error cannot be automatically recovered")
        }
    }
}

/// Result of a recovery attempt
enum RecoveryResult {
    case succeeded
    case failed(reason: String)
    case retry
    case requiresUserAction(action: String)
    
    var message: String {
        switch self {
        case .succeeded:
            return "Issue resolved successfully"
        case .failed(let reason):
            return "Recovery failed: \(reason)"
        case .retry:
            return "Please try again"
        case .requiresUserAction(let action):
            return action
        }
    }
    
    var wasSuccessful: Bool {
        switch self {
        case .succeeded:
            return true
        default:
            return false
        }
    }
}

/// A view modifier that handles error recovery automatically
struct ErrorRecoveryModifier: ViewModifier {
    @Binding var error: UserFriendlyError?
    let onRecoveryComplete: ((RecoveryResult) -> Void)?
    
    @State private var isRecovering = false
    @State private var recoveryResult: RecoveryResult?
    
    func body(content: Content) -> some View {
        content
            .overlay(recoveryOverlay)
            .onChange(of: error) { _, newError in
                if newError != nil {
                    attemptRecovery()
                }
            }
    }
    
    @ViewBuilder
    private var recoveryOverlay: some View {
        if isRecovering {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Attempting to recover...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3))
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    private func attemptRecovery() {
        guard let error = error else { return }
        
        Task {
            await MainActor.run {
                isRecovering = true
            }
            
            let result = await ErrorRecovery.performRecovery(for: error)
            
            await MainActor.run {
                isRecovering = false
                recoveryResult = result
                onRecoveryComplete?(result)
                
                // Clear error if recovery succeeded
                if result.wasSuccessful {
                    self.error = nil
                }
            }
        }
    }
}

extension View {
    func errorRecovery(
        _ error: Binding<UserFriendlyError?>,
        onRecoveryComplete: ((RecoveryResult) -> Void)? = nil
    ) -> some View {
        modifier(ErrorRecoveryModifier(
            error: error,
            onRecoveryComplete: onRecoveryComplete
        ))
    }
}

#if os(iOS)
import AVFoundation

extension ErrorRecovery {
    /// iOS-specific audio session recovery
    static func recoverAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
    }
}
#endif
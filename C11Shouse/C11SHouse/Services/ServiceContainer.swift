/*
 * CONTEXT & PURPOSE:
 * ServiceContainer implements a dependency injection pattern to manage service instances and their
 * dependencies throughout the app. It provides centralized service creation, configuration, and
 * lifecycle management while enabling easy testing through dependency injection.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Singleton pattern for app-wide service access
 *   - ObservableObject for SwiftUI integration
 *   - Lazy initialization for services to optimize startup
 *   - Protocol-based services for flexibility and testability
 *   - Factory method pattern for ViewModel creation with proper DI
 *   - Configuration management centralized in container
 *   - Runtime service switching (standard vs on-device transcription)
 *   - PermissionManager shared instance reused
 *   - Environment injection support via EnvironmentKey
 *   - View extension for convenient container injection
 *   - Private initializer enforces singleton usage
 *   - Service references are read-only externally for encapsulation
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  ServiceContainer.swift
//  C11SHouse
//
//  Service container for dependency injection and integration
//

import Foundation
import SwiftUI

/// Service container that manages all service instances and their dependencies
class ServiceContainer: ObservableObject {
    
    // MARK: - Shared Instance
    
    static let shared = ServiceContainer()
    
    // MARK: - Services
    
    private(set) lazy var audioRecorder: AudioRecorderService = {
        AudioRecorderServiceImpl()
    }()
    
    private(set) lazy var transcriptionService: TranscriptionService = {
        // Use standard service by default, can switch to on-device if needed
        TranscriptionServiceImpl()
    }()
    
    private(set) lazy var permissionManager = PermissionManager.shared
    
    // MARK: - Configuration
    
    private(set) var configuration = TranscriptionConfiguration.default
    
    // MARK: - Factory Methods
    
    /// Create a new VoiceTranscriptionViewModel with injected dependencies
    @MainActor
    func makeVoiceTranscriptionViewModel() -> VoiceTranscriptionViewModel {
        return VoiceTranscriptionViewModel(
            configuration: configuration,
            audioRecorder: audioRecorder,
            transcriptionService: transcriptionService,
            permissionManager: permissionManager
        )
    }
    
    /// Update configuration
    func updateConfiguration(_ newConfiguration: TranscriptionConfiguration) {
        configuration = newConfiguration
    }
    
    /// Switch to on-device transcription for privacy
    func useOnDeviceTranscription() {
        transcriptionService = OnDeviceTranscriptionService()
    }
    
    /// Switch back to standard transcription
    func useStandardTranscription() {
        transcriptionService = TranscriptionServiceImpl()
    }
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton
    }
}

// MARK: - Environment Key

/// Environment key for injecting service container
struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue = ServiceContainer.shared
}

extension EnvironmentValues {
    var serviceContainer: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Inject service container into environment
    func withServiceContainer(_ container: ServiceContainer = .shared) -> some View {
        self.environment(\.serviceContainer, container)
    }
}
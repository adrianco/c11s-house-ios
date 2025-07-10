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
 * - 2025-01-09: Added coordinators to Phase 2 refactoring
 *   - Added WeatherCoordinator for weather business logic
 *   - Updated ContentViewModel factory to use coordinators
 *
 * - 2025-07-10: Refactored ViewModel creation
 *   - Moved ViewModel factory methods to ViewModelFactory class
 *   - Added ViewModelFactory property for centralized ViewModel creation
 *   - Follows Single Responsibility Principle
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
    
    @MainActor
    private(set) lazy var permissionManager = PermissionManager.shared
    
    private(set) lazy var notesService: NotesService = {
        NotesServiceImpl()
    }()
    
    private(set) lazy var ttsService: TTSService = {
        TTSServiceImpl()
    }()
    
    private(set) lazy var locationService: LocationServiceProtocol = {
        LocationServiceImpl()
    }()
    
    private(set) lazy var weatherService: WeatherServiceProtocol = {
        WeatherKitServiceImpl()
    }()
    
    // MARK: - Configuration
    
    private(set) var configuration = TranscriptionConfiguration.default
    
    // MARK: - Coordinators
    
    private(set) lazy var questionFlowCoordinator: QuestionFlowCoordinator = {
        QuestionFlowCoordinator(notesService: notesService)
    }()
    
    private(set) lazy var addressManager: AddressManager = {
        AddressManager(notesService: notesService, locationService: locationService)
    }()
    
    private(set) lazy var conversationStateManager: ConversationStateManager = {
        ConversationStateManager(notesService: notesService, ttsService: ttsService)
    }()
    
    @MainActor
    private(set) lazy var weatherCoordinator: WeatherCoordinator = {
        WeatherCoordinator(weatherService: weatherService, notesService: notesService, locationService: locationService)
    }()
    
    // MARK: - ViewModel Factory
    
    /// Factory for creating ViewModels with proper dependency injection
    @MainActor
    private(set) lazy var viewModelFactory: ViewModelFactory = {
        ViewModelFactory(serviceContainer: self)
    }()
    
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
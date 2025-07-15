/*
 * CONTEXT & PURPOSE:
 * ViewModelFactory implements the Factory pattern for creating ViewModels with proper dependency
 * injection. This centralizes ViewModel creation logic and removes the responsibility from
 * ServiceContainer, following the Single Responsibility Principle.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation
 *   - Extracted ViewModel creation from ServiceContainer
 *   - Holds reference to ServiceContainer for accessing services
 *   - Factory methods for ContentViewModel and VoiceTranscriptionViewModel
 *   - @MainActor for UI thread safety
 *   - Supports easy testing by allowing mock service injection
 *
 * - 2025-07-15: Updated to use centralized AppState
 *   - Added AppState reference for centralized state management
 *   - ViewModels now receive AppState in addition to services
 *   - Reduces state duplication across ViewModels
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  ViewModelFactory.swift
//  C11SHouse
//
//  Factory for creating ViewModels with dependency injection
//

import Foundation
import SwiftUI

/// Factory class responsible for creating ViewModels with proper dependency injection
@MainActor
class ViewModelFactory: ObservableObject {
    
    // MARK: - Properties
    
    /// Reference to the service container for accessing services
    private let serviceContainer: ServiceContainer
    
    /// Reference to the centralized app state
    private let appState: AppState
    
    // MARK: - Initialization
    
    /// Initialize with a service container and app state
    /// - Parameters:
    ///   - serviceContainer: The service container to use for dependency injection
    ///   - appState: The centralized app state
    init(serviceContainer: ServiceContainer = .shared, appState: AppState = .shared) {
        self.serviceContainer = serviceContainer
        self.appState = appState
    }
    
    // MARK: - Factory Methods
    
    /// Create a new VoiceTranscriptionViewModel with injected dependencies
    /// - Returns: A configured VoiceTranscriptionViewModel instance
    func makeVoiceTranscriptionViewModel() -> VoiceTranscriptionViewModel {
        return VoiceTranscriptionViewModel(
            configuration: serviceContainer.configuration,
            audioRecorder: serviceContainer.audioRecorder,
            transcriptionService: serviceContainer.transcriptionService,
            permissionManager: serviceContainer.permissionManager
        )
    }
    
    /// Create a new ContentViewModel with injected dependencies
    /// - Returns: A configured ContentViewModel instance
    func makeContentViewModel() -> ContentViewModel {
        return ContentViewModel(
            appState: appState,
            locationService: serviceContainer.locationService,
            weatherCoordinator: serviceContainer.weatherCoordinator,
            notesService: serviceContainer.notesService,
            addressManager: serviceContainer.addressManager
        )
    }
    
    /// Create a new ConversationStateManager with injected dependencies
    /// - Returns: A configured ConversationStateManager instance
    func makeConversationStateManager() -> ConversationStateManager {
        return serviceContainer.conversationStateManager
    }
    
    // MARK: - Convenience Static Factory
    
    /// Shared factory instance using the default service container
    static let shared = ViewModelFactory()
}

// MARK: - Environment Key

/// Environment key for injecting ViewModel factory
struct ViewModelFactoryKey: EnvironmentKey {
    static let defaultValue = ViewModelFactory.shared
}

extension EnvironmentValues {
    var viewModelFactory: ViewModelFactory {
        get { self[ViewModelFactoryKey.self] }
        set { self[ViewModelFactoryKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Inject ViewModel factory into environment
    func withViewModelFactory(_ factory: ViewModelFactory = .shared) -> some View {
        self.environment(\.viewModelFactory, factory)
    }
}
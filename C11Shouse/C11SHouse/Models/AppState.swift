/*
 * CONTEXT & PURPOSE:
 * AppState provides centralized state management for the entire application. This consolidates
 * scattered state from multiple ViewModels and coordinators into a single source of truth,
 * making state management more predictable and testable.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Initial implementation
 *   - Centralized state management pattern
 *   - ObservableObject for SwiftUI integration
 *   - Combines user preferences, session state, and feature flags
 *   - Thread-safe with @MainActor
 *   - Persistence through UserDefaults
 *   - Notification of state changes via Combine
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation
import Combine
import CoreLocation

/// Centralized application state management
@MainActor
class AppState: ObservableObject {
    
    // MARK: - User Profile
    
    /// The user's home address
    @Published var homeAddress: Address? {
        didSet {
            saveHomeAddress()
        }
    }
    
    /// The name of the house (e.g., "123 Main Street")
    @Published var houseName: String = "Your House" {
        didSet {
            UserDefaults.standard.set(houseName, forKey: "houseName")
        }
    }
    
    // MARK: - User Preferences
    
    /// User's preferred temperature unit
    @Published var temperatureUnit: TemperatureUnit = .fahrenheit {
        didSet {
            UserDefaults.standard.set(temperatureUnit.rawValue, forKey: "temperatureUnit")
        }
    }
    
    /// Whether to use on-device transcription for privacy
    @Published var useOnDeviceTranscription: Bool = false {
        didSet {
            UserDefaults.standard.set(useOnDeviceTranscription, forKey: "useOnDeviceTranscription")
        }
    }
    
    /// Auto-refresh weather interval in seconds (0 = disabled)
    @Published var weatherRefreshInterval: TimeInterval = 1800 { // 30 minutes default
        didSet {
            UserDefaults.standard.set(weatherRefreshInterval, forKey: "weatherRefreshInterval")
        }
    }
    
    // MARK: - Session State
    
    /// Current weather data
    @Published var currentWeather: Weather?
    
    /// Whether weather is being loaded
    @Published var isLoadingWeather: Bool = false
    
    /// Last weather error (if any)
    @Published var weatherError: Error?
    
    /// Current house thought/emotion
    @Published var currentHouseThought: HouseThought?
    
    /// Whether location permission has been granted
    @Published var hasLocationPermission: Bool = false
    
    /// Whether microphone permission has been granted
    @Published var hasMicrophonePermission: Bool = false
    
    /// Whether all required onboarding questions have been answered
    @Published var hasCompletedOnboarding: Bool = false
    
    /// Current onboarding phase
    @Published var currentOnboardingPhase: OnboardingPhase = .welcome
    
    // MARK: - Feature Flags
    
    /// Whether to show debug information in the UI
    @Published var showDebugInfo: Bool = false {
        didSet {
            UserDefaults.standard.set(showDebugInfo, forKey: "showDebugInfo")
        }
    }
    
    /// Whether to enable experimental features
    @Published var enableExperimentalFeatures: Bool = false {
        didSet {
            UserDefaults.standard.set(enableExperimentalFeatures, forKey: "enableExperimentalFeatures")
        }
    }
    
    // MARK: - Singleton
    
    static let shared = AppState()
    
    // MARK: - Initialization
    
    private init() {
        loadPersistedState()
        setupNotificationObservers()
    }
    
    // MARK: - Persistence
    
    private func loadPersistedState() {
        // Load home address
        if let addressData = UserDefaults.standard.data(forKey: "confirmedHomeAddress"),
           let address = try? JSONDecoder().decode(Address.self, from: addressData) {
            homeAddress = address
        }
        
        // Load house name
        if let savedName = UserDefaults.standard.string(forKey: "houseName") {
            houseName = savedName
        }
        
        // Load preferences
        if let unitRawValue = UserDefaults.standard.string(forKey: "temperatureUnit"),
           let unit = TemperatureUnit(rawValue: unitRawValue) {
            temperatureUnit = unit
        }
        
        useOnDeviceTranscription = UserDefaults.standard.bool(forKey: "useOnDeviceTranscription")
        
        let savedInterval = UserDefaults.standard.double(forKey: "weatherRefreshInterval")
        if savedInterval > 0 {
            weatherRefreshInterval = savedInterval
        }
        
        // Load feature flags
        showDebugInfo = UserDefaults.standard.bool(forKey: "showDebugInfo")
        enableExperimentalFeatures = UserDefaults.standard.bool(forKey: "enableExperimentalFeatures")
        
        // Load onboarding state
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        if let phaseRawValue = UserDefaults.standard.string(forKey: "currentOnboardingPhase"),
           let phase = OnboardingPhase(rawValue: phaseRawValue) {
            currentOnboardingPhase = phase
        }
    }
    
    private func saveHomeAddress() {
        if let address = homeAddress {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(address) {
                UserDefaults.standard.set(encoded, forKey: "confirmedHomeAddress")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "confirmedHomeAddress")
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Listen for onboarding completion
        NotificationCenter.default.publisher(for: Notification.Name("AllQuestionsComplete"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.hasCompletedOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - State Updates
    
    /// Update weather-related state
    func updateWeatherState(weather: Weather? = nil, isLoading: Bool = false, error: Error? = nil) {
        currentWeather = weather
        isLoadingWeather = isLoading
        weatherError = error
    }
    
    /// Update house emotion based on current conditions
    func updateHouseEmotion(_ thought: HouseThought) {
        currentHouseThought = thought
    }
    
    /// Update permission states
    func updatePermissions(location: Bool? = nil, microphone: Bool? = nil) {
        if let location = location {
            hasLocationPermission = location
        }
        if let microphone = microphone {
            hasMicrophonePermission = microphone
        }
    }
    
    /// Update onboarding phase
    func updateOnboardingPhase(_ phase: OnboardingPhase) {
        currentOnboardingPhase = phase
        UserDefaults.standard.set(phase.rawValue, forKey: "currentOnboardingPhase")
    }
    
    /// Mark onboarding as complete
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        currentOnboardingPhase = .complete
    }
    
    // MARK: - Convenience Methods
    
    /// Check if the app has all necessary permissions
    var hasAllPermissions: Bool {
        hasLocationPermission && hasMicrophonePermission
    }
    
    /// Check if the app is ready for full functionality
    var isAppReady: Bool {
        hasCompletedOnboarding && hasAllPermissions && homeAddress != nil
    }
}

// MARK: - Supporting Types

/// Temperature unit preference
enum TemperatureUnit: String, CaseIterable {
    case fahrenheit = "fahrenheit"
    case celsius = "celsius"
    
    var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }
}

/// Onboarding phase tracking
enum OnboardingPhase: String {
    case welcome = "welcome"
    case permissions = "permissions"
    case questions = "questions"
    case tutorial = "tutorial"
    case complete = "complete"
}
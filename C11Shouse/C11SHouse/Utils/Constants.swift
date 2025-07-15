/*
 * CONTEXT & PURPOSE:
 * Constants provides a centralized location for all app-wide constants including
 * animation durations, UI dimensions, feature flags, and static text. This ensures
 * consistency across the app and makes it easy to adjust values globally.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Initial implementation
 *   - Organized constants by category using enums
 *   - Type-safe constant definitions
 *   - No magic numbers in code
 *   - Single source of truth for UI values
 *   - Question texts centralized for easy maintenance
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation
import SwiftUI

// MARK: - Animation Constants

enum AnimationConstants {
    /// Standard animation duration for most UI transitions
    static let standardDuration: Double = 0.3
    
    /// Quick animation for subtle feedback
    static let quickDuration: Double = 0.15
    
    /// Slow animation for emphasis
    static let slowDuration: Double = 0.6
    
    /// Spring animation response
    static let springResponse: Double = 0.5
    
    /// Spring animation damping
    static let springDamping: Double = 0.8
    
    /// Button press scale
    static let buttonPressScale: CGFloat = 0.95
    
    /// View transition animation
    static let viewTransition: Animation = .easeInOut(duration: standardDuration)
    
    /// Button feedback animation
    static let buttonFeedback: Animation = .spring(response: 0.3, dampingFraction: 0.6)
}

// MARK: - UI Constants

enum UIConstants {
    /// Standard corner radius for cards and containers
    static let cornerRadius: CGFloat = 12
    
    /// Large corner radius for prominent elements
    static let largeCornerRadius: CGFloat = 20
    
    /// Small corner radius for subtle rounding
    static let smallCornerRadius: CGFloat = 6
    
    /// Standard padding
    static let standardPadding: CGFloat = 16
    
    /// Small padding
    static let smallPadding: CGFloat = 8
    
    /// Large padding
    static let largePadding: CGFloat = 24
    
    /// Minimum button height
    static let buttonHeight: CGFloat = 44
    
    /// Standard shadow radius
    static let shadowRadius: CGFloat = 4
    
    /// Shadow opacity
    static let shadowOpacity: Double = 0.1
    
    /// Maximum content width for readability
    static let maxContentWidth: CGFloat = 600
    
    /// Voice recording button size
    static let voiceButtonSize: CGFloat = 80
    
    /// House emotion icon size
    static let emotionIconSize: CGFloat = 40
    
    /// Loading indicator size
    static let loadingIndicatorSize: CGFloat = 50
}

// MARK: - Color Constants

enum ColorConstants {
    /// Primary brand color
    static let primary = Color.blue
    
    /// Secondary brand color
    static let secondary = Color.indigo
    
    /// Success color
    static let success = Color.green
    
    /// Warning color
    static let warning = Color.orange
    
    /// Error color
    static let error = Color.red
    
    /// Background color
    static let background = Color(UIColor.systemBackground)
    
    /// Secondary background
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    
    /// Text primary
    static let textPrimary = Color(UIColor.label)
    
    /// Text secondary
    static let textSecondary = Color(UIColor.secondaryLabel)
}

// MARK: - Feature Flags

enum FeatureFlags {
    /// Enable experimental voice features
    static let experimentalVoiceFeatures = false
    
    /// Show debug information in UI
    static let showDebugInfo = false
    
    /// Enable haptic feedback
    static let enableHapticFeedback = true
    
    /// Use mock services for testing
    static let useMockServices = false
    
    /// Enable analytics tracking
    static let enableAnalytics = false
    
    /// Show onboarding on first launch
    static let showOnboarding = true
    
    /// Enable weather animations
    static let enableWeatherAnimations = true
}

// MARK: - App Configuration

enum AppConfiguration {
    /// Weather refresh interval in seconds
    static let weatherRefreshInterval: TimeInterval = 1800 // 30 minutes
    
    /// Location update distance threshold in meters
    static let locationUpdateThreshold: Double = 100
    
    /// Maximum recording duration in seconds
    static let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    
    /// Transcription timeout in seconds
    static let transcriptionTimeout: TimeInterval = 30
    
    /// Cache expiration time in seconds
    static let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    /// Maximum number of saved conversations
    static let maxSavedConversations = 50
    
    /// Auto-save interval for notes
    static let autoSaveInterval: TimeInterval = 10
}

// MARK: - Question Texts

enum QuestionTexts {
    // MARK: - Required Questions
    
    static let homeAddressQuestion = """
    What's your home address? I'll use this to provide personalized weather updates and location-based assistance.
    """
    
    static let homeTypeQuestion = """
    What type of home do you live in? (house, apartment, condo, etc.)
    """
    
    static let householdSizeQuestion = """
    How many people live in your home?
    """
    
    // MARK: - Home Preferences
    
    static let favoriteRoomQuestion = """
    What's your favorite room in the house and why?
    """
    
    static let homeImprovementQuestion = """
    What's one thing you'd like to improve about your home?
    """
    
    static let homeFeelingQuestion = """
    How do you want your home to feel? (cozy, modern, minimalist, etc.)
    """
    
    // MARK: - Daily Routines
    
    static let morningRoutineQuestion = """
    What does your typical morning routine look like?
    """
    
    static let eveningRoutineQuestion = """
    How do you like to unwind in the evening?
    """
    
    static let workFromHomeQuestion = """
    Do you work from home? If so, what's your typical schedule?
    """
    
    // MARK: - Comfort & Environment
    
    static let temperaturePreferenceQuestion = """
    What's your ideal indoor temperature?
    """
    
    static let lightingPreferenceQuestion = """
    Do you prefer bright lights or dim, cozy lighting?
    """
    
    static let noisePreferenceQuestion = """
    Are you sensitive to noise, or do you like some background sounds?
    """
    
    // MARK: - Maintenance & Care
    
    static let maintenanceConcernQuestion = """
    What home maintenance tasks do you often forget or worry about?
    """
    
    static let cleaningScheduleQuestion = """
    How often do you like to clean different areas of your home?
    """
    
    static let organizationChallengeQuestion = """
    What areas of your home are hardest to keep organized?
    """
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when all required questions are completed
    static let allQuestionsComplete = Notification.Name("AllQuestionsComplete")
    
    /// Posted when onboarding is completed
    static let onboardingComplete = Notification.Name("OnboardingComplete")
    
    /// Posted when weather update is available
    static let weatherUpdated = Notification.Name("WeatherUpdated")
    
    /// Posted when location permission changes
    static let locationPermissionChanged = Notification.Name("LocationPermissionChanged")
    
    /// Posted when microphone permission changes
    static let microphonePermissionChanged = Notification.Name("MicrophonePermissionChanged")
    
    /// Posted when address is confirmed
    static let addressConfirmed = Notification.Name("AddressConfirmed")
}

// MARK: - Error Messages

enum ErrorMessages {
    static let genericError = "Something went wrong. Please try again."
    static let networkError = "Unable to connect. Please check your internet connection."
    static let locationPermissionDenied = "Location access is needed for weather updates. Please enable it in Settings."
    static let microphonePermissionDenied = "Microphone access is needed for voice features. Please enable it in Settings."
    static let transcriptionFailed = "Unable to transcribe audio. Please try again."
    static let weatherUnavailable = "Weather information is temporarily unavailable."
    static let addressNotFound = "Unable to find that address. Please check and try again."
}

// MARK: - Accessibility Labels

enum AccessibilityLabels {
    static let voiceRecordingButton = "Start voice recording"
    static let voiceRecordingActiveButton = "Stop voice recording"
    static let weatherIcon = "Current weather condition"
    static let houseEmotionIcon = "House emotion indicator"
    static let settingsButton = "Open settings"
    static let backButton = "Go back"
    static let nextButton = "Continue to next step"
    static let skipButton = "Skip this question"
}
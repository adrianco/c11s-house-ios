# Onboarding Logging Implementation Guide

## Overview
The onboarding flow now has comprehensive logging throughout all phases to track user behavior, timing, errors, and feature usage. All logs use OSLog for better Xcode console integration and are structured to be easily copyable and analyzable.

## Key Features

### 1. OnboardingLogger Class
Located at: `C11SHouse/Services/OnboardingLogger.swift`

- **Singleton Pattern**: `OnboardingLogger.shared` for global access
- **OSLog Integration**: Uses different log categories (phase, action, feature, error, timing)
- **Session Management**: Tracks entire onboarding sessions with unique IDs
- **Structured Logging**: All logs are formatted consistently with timestamps and context

### 2. Logging Categories

#### Phase Transitions
```swift
OnboardingLogger.shared.logPhaseTransition(from: "welcome", to: "permissions")
```
Tracks:
- Previous phase
- New phase
- Timestamp
- Duration of previous phase

#### User Actions
```swift
OnboardingLogger.shared.logUserAction("button_tap", phase: "welcome", details: ["button": "begin_setup"])
```
Tracks:
- Action type
- Current phase
- Additional context

#### Feature Usage
```swift
OnboardingLogger.shared.logFeatureUsage("voice_input", phase: "personalization", details: ["duration": 3.5])
```
Tracks:
- Feature name
- Usage context
- Performance metrics

#### Service Calls
```swift
OnboardingLogger.shared.logServiceCall("address_detection", phase: "permissions", success: true, duration: 1.2)
```
Tracks:
- Service name
- Success/failure
- Response time

#### Errors
```swift
OnboardingLogger.shared.logError(error, phase: "permissions", recovery: "User will enter manually")
```
Tracks:
- Error details
- Recovery path
- User impact

### 3. Integration Points

#### OnboardingCoordinator
- Manages session lifecycle
- Logs phase transitions
- Provides helper methods for views

#### Phase Views
- **WelcomePhaseView**: Logs view appearance and button taps
- **PermissionsPhaseView**: Logs permission requests, grants/denials, and recovery actions
- **PersonalizationPhaseView**: Logs conversation interactions, voice input, and answers
- **Phase4TutorialView**: Logs tutorial progress, note creation, and completion

#### Services
- **AddressSuggestionService**: Logs address detection and suggestions
- **QuestionFlowCoordinator**: Logs question flow and answers
- **PermissionManager**: Integration for permission tracking

### 4. Log Output Formats

#### Console Output
```
🚀 ONBOARDING SESSION STARTED - ID: ABC123-DEF456
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 PHASE TRANSITION: Start → welcome
👆 USER ACTION: view_appeared in welcome
👆 USER ACTION: button_tap in welcome
   Details: button: begin_setup
⏱️ Phase 'welcome' completed in 5.2s
```

#### Summary Report
At the end of each session, a formatted summary is generated:
```
╔════════════════════════════════════════════════════════════════╗
║                    ONBOARDING SESSION SUMMARY                   ║
╠════════════════════════════════════════════════════════════════╣
║ Session ID: ABC123-DEF456
║ Start Time: 2025-07-11 10:30:45
║ Total Duration: 3m 24s
║ Phases Completed: 4
╠════════════════════════════════════════════════════════════════╣
║                         PHASE TIMINGS                           ║
╠════════════════════════════════════════════════════════════════╣
║ welcome              │ 5.2s            ║
║ permissions          │ 45.3s           ║
║ personalization      │ 1m 32s          ║
║ tutorial             │ 1m 12s          ║
╠════════════════════════════════════════════════════════════════╣
```

### 5. Copyable Log Export
```swift
let log = OnboardingLogger.shared.getCopyableLog()
// Returns a formatted string of all actions for easy sharing/analysis
```

## Usage Examples

### Basic Button Tap
```swift
Button(action: {
    OnboardingLogger.shared.logButtonTap("continue", phase: "permissions")
    onContinue()
}) {
    Text("Continue")
}
```

### Voice Input Tracking
```swift
OnboardingLogger.shared.logVoiceInput(
    phase: "personalization",
    duration: recordingDuration,
    transcript: recognizedText
)
```

### Error Handling
```swift
do {
    let address = try await detectAddress()
} catch {
    OnboardingLogger.shared.logError(error, 
        phase: "permissions", 
        recovery: "User will enter address manually"
    )
}
```

### Feature Usage
```swift
if userAcceptedSuggestion {
    OnboardingLogger.shared.logHouseNameSuggestion(
        suggested: "Main House",
        accepted: true
    )
}
```

## Testing

A demo utility is provided at `C11SHouse/Utils/OnboardingLoggerDemo.swift`:
```swift
OnboardingLoggerDemo.runDemo()
```

This simulates a complete onboarding flow and demonstrates all logging features.

## Best Practices

1. **Always log user interactions**: Button taps, text input, voice commands
2. **Track timing**: Service calls, phase durations, response times
3. **Log errors with recovery**: Include what the user should do next
4. **Use structured details**: Pass dictionaries with relevant context
5. **Be consistent**: Use the same action names across similar interactions

## Console Filtering

In Xcode console, you can filter logs by:
- Subsystem: `com.c11s.house.onboarding`
- Categories: `phase`, `action`, `feature`, `error`, `timing`

Example filter: `subsystem:com.c11s.house.onboarding category:action`

## Privacy Considerations

- Logs do not include full personal information
- Voice transcripts are truncated to 50 characters
- Addresses are logged but can be anonymized if needed
- No sensitive data is included in error logs

## Future Enhancements

1. **Analytics Integration**: Send aggregated metrics to analytics service
2. **Performance Monitoring**: Track UI responsiveness and lag
3. **A/B Testing**: Log variant exposure and outcomes
4. **Crash Reporting**: Attach onboarding logs to crash reports
5. **User Feedback**: Correlate logs with user satisfaction scores
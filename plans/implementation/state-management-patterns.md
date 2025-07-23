# State Management Patterns - C11S House iOS

## Overview

This document describes the centralized state management architecture implemented for the C11S House iOS application. The refactoring consolidates scattered state from multiple ViewModels and coordinators into a single source of truth using the `AppState` class.

## Architecture

### Core Components

#### 1. AppState (Models/AppState.swift)
The centralized state container that manages all application-wide state:

- **User Profile**: Home address, house name
- **User Preferences**: Temperature unit, privacy settings, refresh intervals
- **Session State**: Current weather, loading states, errors, house emotions
- **Permissions**: Location and microphone authorization status
- **Feature Flags**: Debug mode, experimental features
- **Onboarding State**: Current phase and completion status

#### 2. Constants (Utils/Constants.swift)
Centralized location for all app constants:

- **Animation Constants**: Durations, spring values, transitions
- **UI Constants**: Sizes, padding, corner radii, colors
- **Feature Flags**: Static feature toggles
- **App Configuration**: Timeouts, intervals, limits
- **Question Texts**: All onboarding question content
- **Error Messages**: User-facing error strings
- **Accessibility Labels**: VoiceOver support

#### 3. ViewModelFactory
Updated to inject AppState into ViewModels alongside services:

```swift
func makeContentViewModel() -> ContentViewModel {
    return ContentViewModel(
        appState: appState,
        locationService: serviceContainer.locationService,
        weatherCoordinator: serviceContainer.weatherCoordinator,
        notesService: serviceContainer.notesService,
        addressManager: serviceContainer.addressManager
    )
}
```

## State Flow

### Before (Scattered State)
```
ContentViewModel
├── @Published houseName
├── @Published houseThought
├── @Published currentAddress
└── @Published hasLocationPermission

WeatherCoordinator
├── @Published currentWeather
├── @Published isLoadingWeather
└── @Published weatherError

Multiple UserDefaults calls scattered throughout
```

### After (Centralized State)
```
AppState (Single Source of Truth)
├── User Profile
│   ├── homeAddress
│   └── houseName
├── User Preferences
│   ├── temperatureUnit
│   ├── useOnDeviceTranscription
│   └── weatherRefreshInterval
├── Session State
│   ├── currentWeather
│   ├── isLoadingWeather
│   ├── weatherError
│   └── currentHouseThought
└── Permissions & Onboarding
    ├── hasLocationPermission
    ├── hasMicrophonePermission
    └── hasCompletedOnboarding
```

## Implementation Guidelines

### 1. Accessing State in ViewModels

ViewModels receive AppState through dependency injection:

```swift
class ContentViewModel: ObservableObject {
    private let appState: AppState
    
    // Read state directly
    var houseName: String { appState.houseName }
    var currentWeather: Weather? { appState.currentWeather }
    
    // Update state through AppState methods
    func updateWeather(_ weather: Weather) {
        appState.updateWeatherState(weather: weather)
    }
}
```

### 2. State Updates

All state changes go through AppState methods:

```swift
// Update weather state
appState.updateWeatherState(weather: newWeather, isLoading: false)

// Update permissions
appState.updatePermissions(location: true)

// Update house emotion
appState.updateHouseEmotion(thought)
```

### 3. Persistence

AppState handles all UserDefaults persistence internally:

```swift
@Published var houseName: String = "Your House" {
    didSet {
        UserDefaults.standard.set(houseName, forKey: "houseName")
    }
}
```

### 4. Using Constants

Replace magic numbers and strings with constants:

```swift
// Before
.animation(.easeInOut(duration: 0.3))
.padding(16)

// After
.animation(AnimationConstants.viewTransition)
.padding(UIConstants.standardPadding)
```

## Migration Checklist

### Completed ✅
- [x] Created AppState model with centralized state
- [x] Created Constants file with app-wide constants
- [x] Updated ViewModelFactory to inject AppState
- [x] Refactored ContentViewModel to use AppState
- [x] Removed local state properties from ContentViewModel
- [x] Updated all state updates to go through AppState

### TODO 
- [ ] Update VoiceTranscriptionViewModel to use AppState for permissions
- [ ] Update WeatherCoordinator to write to AppState instead of local properties
- [ ] Update OnboardingCoordinator to use AppState for onboarding phase
- [ ] Update QuestionFlowCoordinator to check AppState for completion
- [ ] Update all Views to read from AppState through ViewModels
- [ ] Remove redundant UserDefaults calls throughout the app
- [ ] Update tests to mock AppState instead of individual services

## Benefits

1. **Single Source of Truth**: All app state in one place
2. **Easier Testing**: Mock one AppState instead of multiple services
3. **Better Performance**: Reduced redundant state updates
4. **Cleaner Code**: No scattered UserDefaults calls
5. **Type Safety**: Strongly typed state properties
6. **Consistency**: All UI constants in one place

## Best Practices

1. **Never access UserDefaults directly** - Always go through AppState
2. **Use computed properties** in ViewModels to expose AppState data
3. **Keep AppState methods focused** - One method per state update type
4. **Use Constants** for all UI values and strings
5. **Document state changes** in AppState for traceability

## Future Enhancements

1. **State Restoration**: Save/restore full app state for app lifecycle
2. **State Observers**: Add Combine publishers for specific state changes
3. **State Validation**: Add business rules for valid state transitions
4. **Debug Tools**: Add state inspection tools for development
5. **Analytics**: Track state changes for user behavior insights
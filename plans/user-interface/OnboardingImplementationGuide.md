# C11S House iOS - Onboarding Implementation Guide

## Overview - edited by adrianco 10 July 2025 - do not edit

This guide provides comprehensive documentation for the C11S House iOS app onboarding experience, including the UX plan, test strategy, and implementation details.

## 📚 Documentation Structure

### 1. [Onboarding UX Plan](OnboardingUXPlan.md)
The complete user experience design for onboarding, including:
- User personas and journey maps
- Visual design principles
- Progressive disclosure strategy
- Success metrics and KPIs

### 2. Test Implementation
Comprehensive test coverage across multiple test types:

#### Unit Tests
- **Location**: `C11SHouseTests/Onboarding/OnboardingFlowTests.swift`
- **Purpose**: Validates core onboarding logic and state management
- **Coverage**: 
  - Permission flows
  - Data persistence
  - Error handling
  - Accessibility features

#### UI Tests
- **Location**: `C11SHouseUITests/OnboardingUITests.swift`
- **Purpose**: End-to-end testing of user interactions
- **Coverage**:
  - Visual elements and animations
  - User navigation flows
  - System permission handling
  - Performance metrics

#### Test Scenarios
- **Location**: `C11SHouseTests/Onboarding/OnboardingTestScenarios.swift`
- **Purpose**: Defines acceptance criteria for various user journeys
- **Scenarios**:
  - Happy path (all permissions granted)
  - Permission denied recovery
  - Offline mode
  - Accessibility users
  - Returning users

### 3. Integration with Existing Tests
The onboarding tests integrate seamlessly with existing test infrastructure:
- `InitialSetupFlowTests.swift` - Tests the complete setup workflow
- `ConversationFlowIntegrationTests.swift` - Validates conversation initiation
- Test mocks in `TestMocks.swift` support all onboarding scenarios

## 🚀 Running the Tests

### Quick Start
```bash
# Run all onboarding tests
../../tests/scripts/run-onboarding-tests.sh

# Run specific test suites
xcodebuild test -scheme C11SHouse -only-testing:C11SHouseTests/OnboardingFlowTests
xcodebuild test -scheme C11SHouse -only-testing:C11SHouseUITests/OnboardingUITests
```

### Test Categories

1. **Unit Tests**: Fast, isolated tests of individual components
2. **Integration Tests**: Tests of component interactions
3. **UI Tests**: Full user flow validation




## 🧪 Test-Driven Development

### Writing New Tests
1. Start with acceptance criteria in `OnboardingTestScenarios.swift`
2. Write unit tests for new logic in `OnboardingFlowTests.swift`
3. Add UI tests for user-facing features in `OnboardingUITests.swift`

### Test Naming Convention
```swift
func test<Feature><Scenario><ExpectedOutcome>() {
    // Example: testPermissionDenialShowsRecoveryOptions()
}
```

## 🔍 Debugging & Troubleshooting

### Common Issues

1. **Permission Alerts in UI Tests**
   - Use `handleSystemPermissionAlert()` helper
   - Reset simulator permissions between test runs

2. **Timing Issues**
   - Use `waitForExistence()` instead of `sleep()`
   - Adjust timeout values for slower devices

3. **Test Data Cleanup**
   - Always clear data in `setUp()` and `tearDown()`
   - Use `--reset-onboarding` launch argument


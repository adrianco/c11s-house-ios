# C11S House iOS Test Strategy

## Overview
This document outlines an incremental approach to fixing and implementing tests for the C11S House iOS app. We'll start with the most critical services and gradually expand test coverage.

## Current Status
- Many tests have compilation errors due to API changes
- WeatherKit tests fail in simulator due to sandbox restrictions
- Tests need to be updated to match current implementation

## Phase 1: Weather Service Tests (CURRENT)
**Goal**: Fix WeatherIntegrationTests and WeatherKitServiceTests

### Issues to Fix:
1. WeatherKit sandbox restrictions in simulator
2. Namespace conflicts between WeatherKit.Weather and C11SHouse.Weather
3. Mock services need updating

### Approach:
- Use mock weather service for all tests
- Add conditional compilation for device-only tests
- Fix namespace conflicts with explicit module prefixes

## Phase 2: Core Services Tests
**Goal**: Fix essential service tests

### Priority Order:
1. NotesServiceTests - Central persistence layer
2. LocationServiceTests - Required for weather
3. QuestionFlowCoordinatorTests - Core UX flow
4. AddressManagerTests - Address handling

## Phase 3: UI Component Tests
**Goal**: Test view models and coordinators

### Priority Order:
1. ConversationStateManagerTests
2. OnboardingCoordinatorTests
3. OnboardingFlowTests

## Phase 4: Integration Tests
**Goal**: Test complete user flows

### Priority Order:
1. InitialSetupFlowTests
2. ConversationFlowIntegrationTests

## Phase 5: Utility Tests
**Goal**: Test helper classes

### Priority Order:
1. AddressParserTests
2. SpeechErrorTests
3. ThreadingVerificationTests

## Archived Tests
Tests temporarily moved to `/Archived` directory until they can be fixed:
- Tests with extensive compilation errors
- Tests dependent on unimplemented features
- Tests requiring significant refactoring

## Testing Guidelines

### 1. Use Mocks for External Services
- WeatherKit → MockWeatherKitService
- CoreLocation → MockLocationManager
- Speech Recognition → MockSpeechRecognizer

### 2. Namespace Conflicts
- Always use `C11SHouse.Weather` for app types
- Use `WeatherKit.Weather` only when directly interfacing with WeatherKit

### 3. Async Testing
- Use `async`/`await` for all async tests
- Use `XCTestExpectation` sparingly
- Prefer `@MainActor` tests for UI-related code

### 4. Device vs Simulator
- Use conditional compilation for device-only features
- Provide mock implementations for simulator testing

## Success Metrics
- All tests in active directory compile successfully
- Test coverage > 80% for critical paths
- Tests run in < 30 seconds
- No flaky tests

## Next Steps
1. Fix WeatherIntegrationTests compilation
2. Update MockWeatherKitService to match current API
3. Add conditional compilation for device-only tests
4. Move failing tests to archived directory
5. Create GitHub Actions workflow for CI
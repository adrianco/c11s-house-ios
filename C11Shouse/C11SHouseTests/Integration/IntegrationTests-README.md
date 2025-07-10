# Integration Tests

This directory contains integration tests for the C11S House app that validate complete user workflows and feature integrations.

## Test Files

### 1. ConversationFlowIntegrationTests.swift
Tests the complete conversation flow from speech recognition through question display, answer saving, and progression to the next question.

**Key Test Scenarios:**
- Complete conversation flow from start to finish
- Question transitions with existing answers
- Address detection and validation
- Conversation state management
- All question categories handling
- Error recovery during conversation

**Dependencies Mocked:**
- Speech recognition
- Location services (for testing)
- TTS service

### 2. InitialSetupFlowTests.swift
Tests the complete initial app setup flow including location permissions, address detection, house naming, and user name collection.

**Key Test Scenarios:**
- Complete setup flow with permissions granted
- Setup with location permission denied
- Network/geocoding error handling
- Data persistence across setup steps
- Address parsing variations
- House name generation logic

**Dependencies Mocked:**
- Location services
- Permission manager
- Geocoding services

### 3. WeatherIntegrationTests.swift
Tests the weather feature integration from location services through weather data fetching, emotion determination, and UI updates.

**Key Test Scenarios:**
- Complete weather flow from location to emotion
- Weather condition to emotion mapping
- Error handling (location and API failures)
- Weather for specific addresses
- Weather summary persistence to notes
- Loading state transitions

**Dependencies Mocked:**
- WeatherKit API
- Location manager

## Running Integration Tests

### Run All Integration Tests
```bash
xcodebuild test -scheme C11SHouse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:C11SHouseTests/Integration
```

### Run Specific Integration Test Class
```bash
# Conversation Flow Tests
xcodebuild test -scheme C11SHouse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:C11SHouseTests/ConversationFlowIntegrationTests

# Initial Setup Tests
xcodebuild test -scheme C11SHouse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:C11SHouseTests/InitialSetupFlowTests

# Weather Integration Tests
xcodebuild test -scheme C11SHouse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:C11SHouseTests/WeatherIntegrationTests
```

### Run in Xcode
1. Open the C11SHouse project in Xcode
2. Press `Cmd+U` to run all tests, or
3. Navigate to the test file and click the diamond icon next to individual test methods

## Test Design Principles

1. **Real Coordinators**: Tests use actual coordinator and service implementations where possible
2. **Minimal Mocking**: Only external dependencies (APIs, system services) are mocked
3. **End-to-End Validation**: Tests verify data flow through the entire system
4. **Async/Await**: All tests properly handle async operations
5. **State Verification**: Tests check both immediate results and persistent state

## Adding New Integration Tests

When adding new integration tests:

1. Follow the naming convention: `[Feature]IntegrationTests.swift`
2. Use real service implementations where possible
3. Mock only external dependencies
4. Test complete user workflows, not individual methods
5. Verify data persistence and state changes
6. Handle async operations properly with expectations or async/await
7. Include error scenarios and recovery paths

## Common Mock Services

The integration tests include several reusable mock services:

- `MockLocationService`: Simulates location and geocoding
- `MockLocationManager`: Simulates CLLocationManager
- `MockWeatherService`: Simulates WeatherKit API
- `MockTTSService`: Simulates text-to-speech
- `MockPermissionManager`: Simulates system permissions

These mocks can be configured to return specific data or throw errors for testing various scenarios.
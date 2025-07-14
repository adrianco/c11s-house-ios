# Weather Initialization Fix Plan

## Issue Summary
WeatherKit is failing to initialize after address confirmation due to:
1. WeatherKit authorization/sandbox restriction errors
2. Missing weather question in NotesStore when trying to save weather data
3. Need for better error handling and logging

## Root Causes

### 1. WeatherKit Authorization Issue
- Error: "The connection to service named com.apple.weatherkit.authservice was invalidated: failed at lookup with error 159 - Sandbox restriction"
- This indicates WeatherKit configuration issues with:
  - Bundle ID mismatch with provisioning profile
  - WeatherKit capability not properly enabled
  - App ID configuration missing WeatherKit

### 2. Weather Note Storage Issue
- WeatherCoordinator tries to update a "Weather" question that doesn't exist
- Need to ensure the Weather question is added to NotesStore before weather fetches

### 3. Timing Issues
- Weather fetch happens immediately after address confirmation
- Need to ensure proper initialization sequence

## Implementation Steps

### 1. Fix Weather Question Initialization
- Ensure "Weather" question exists in NotesStore before any weather operations
- Add it during app initialization or first weather fetch

### 2. Improve Weather Error Handling
- Better error messages for developers
- Graceful degradation when WeatherKit fails
- Clear logging of configuration issues

### 3. Add Weather Initialization Coordinator
- Ensure proper sequence: Address → Weather Question → Weather Fetch
- Add retry logic for transient failures

### 4. Enhanced Logging
- Add detailed logging for each step of weather initialization
- Log configuration status at startup
- Track weather fetch attempts and results

## Code Changes

### 1. WeatherCoordinator.swift
- Add method to ensure Weather question exists
- Improve error handling with specific WeatherKit configuration checks
- Add initialization status tracking

### 2. QuestionFlowCoordinator.swift
- Ensure Weather question exists before triggering weather fetch
- Add logging for weather initialization sequence

### 3. AddressSuggestionService.swift
- Add pre-flight checks before weather fetch
- Log detailed status at each step

### 4. ServiceContainer.swift
- Initialize weather question during app startup
- Ensure proper coordinator initialization order

## Expected Outcome
After implementing these fixes:
1. Weather question will be created automatically when needed
2. Clear error messages will indicate configuration issues
3. Weather will initialize properly after address confirmation
4. Comprehensive logging will aid debugging
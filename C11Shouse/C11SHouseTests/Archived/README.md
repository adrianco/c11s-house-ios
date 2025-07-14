# Archived Test Files

This folder contains test files that have been archived and are no longer part of the active test suite.

## Why These Tests Were Archived

These tests were moved here because:
1. They reference older APIs or patterns that have been refactored
2. They contain integration tests that may need significant updates
3. They are kept for reference and historical context

## Archived Files

- **ConversationFlowIntegrationTests.swift** - Full conversation flow integration tests
- **ConversationStateManagerTests.swift** - Tests for conversation state management
- **InitialSetupFlowTests.swift** - Tests for initial app setup flow
- **OnboardingCoordinatorTests.swift** - Tests for onboarding coordination (requires concrete PermissionManager)
- **OnboardingFlowTests.swift** - Tests for complete onboarding flow
- **QuestionFlowCoordinatorTests_OLD.swift** - Older version of question flow coordinator tests (renamed to avoid filename conflict)

## Exclusion from Compilation

These files are excluded from test compilation through:
1. The `C11SHouseTests.xcfilelist` file in the parent directory
2. Being placed in the Archived folder which is not included in test targets

## Active Test Files

The current, maintained test files are located in:
- `/C11SHouseTests/Services/` - Service layer tests
- `/C11SHouseTests/Integration/` - Integration tests
- `/C11SHouseTests/Utilities/` - Utility tests
- `/C11SHouseTests/Infrastructure/` - Infrastructure tests
- `/C11SHouseTests/Onboarding/` - Current onboarding tests

## Note for Developers

If you need to reference these tests:
1. They may contain useful test patterns or scenarios
2. They would need significant updates to work with current APIs
3. Consider extracting relevant test cases and updating them for the current codebase

Last archived: 2025-01-14
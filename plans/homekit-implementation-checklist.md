# HomeKit Integration Implementation Checklist

## Overview
This checklist provides a detailed, file-by-file implementation guide for adding HomeKit integration to the C11S House iOS app. Each item includes the specific changes needed and their dependencies.

## 🎯 Implementation Order

### Phase 1: Splash Screen Animation ✨

#### 1.1 Create Splash Screen Components
- [ ] **NEW** `/C11Shouse/C11SHouse/Views/SplashView.swift`
  - Create SwiftUI view with animation states
  - Implement brain+circle flying animation
  - Add completion binding for transition
  - Duration: 1.5-2 seconds total

- [ ] **MODIFY** `/C11Shouse/C11SHouse/CreateAppIcon.swift`
  - Add `createHouseOnly()` method for house without brain
  - Add `createBrainCircle()` method for flying element
  - Ensure transparent backgrounds for animation

#### 1.2 Integrate Splash into App Launch
- [ ] **MODIFY** `/C11Shouse/C11SHouse/C11SHouseApp.swift`
  - Add `@State private var showSplash = true`
  - Wrap ContentView in conditional for splash
  - Pass completion binding to SplashView
  - Ensure smooth transition to main app

### Phase 2: HomeKit Permission Integration 🔐

#### 2.1 Add HomeKit Framework and Permissions
- [ ] **MODIFY** `/C11Shouse/C11SHouse/Info-additions.plist`
  ```xml
  <key>NSHomeKitUsageDescription</key>
  <string>C11S House uses HomeKit to discover your existing rooms and smart devices, making it easier to manage your home.</string>
  ```

- [ ] **MODIFY** Project Settings (Xcode)
  - Add HomeKit capability
  - Enable HomeKit in App ID
  - Update provisioning profiles

#### 2.2 Extend Permission Manager
- [ ] **MODIFY** `/C11Shouse/C11SHouse/Infrastructure/Voice/PermissionManager.swift`
  - Import HomeKit framework
  - Add `homeKitPermissionStatus` published property
  - Add `requestHomeKitPermission()` async method
  - Add `isHomeKitGranted` computed property
  - Update `PermissionType` enum with `.homeKit`
  - Add HomeKit to `allPermissionsGranted` logic (as optional)

#### 2.3 Update Onboarding UI
- [ ] **MODIFY** `/C11Shouse/C11SHouse/Views/Onboarding/OnboardingPermissionsView.swift`
  - Add HomeKit PermissionCard after Location
  - Set as non-required permission
  - Update permission request logic
  - Add HomeKit icon and description

### Phase 3: HomeKit Service Implementation 🏠

#### 3.1 Create Data Models
- [ ] **NEW** `/C11Shouse/C11SHouse/Models/HomeKitModels.swift`
  ```swift
  struct HomeConfiguration
  struct RoomConfiguration  
  struct AccessoryConfiguration
  enum HomeKitError: Error
  ```

#### 3.2 Create HomeKit Service
- [ ] **NEW** `/C11Shouse/C11SHouse/Services/HomeKitService.swift`
  - Define `HomeKitServiceProtocol`
  - Implement `HomeKitService` class
  - Add HMHomeManagerDelegate conformance
  - Implement `discoverHomes()` method
  - Implement `importConfiguration()` method
  - Add note creation helper methods

#### 3.3 Integrate with ServiceContainer
- [ ] **MODIFY** `/C11Shouse/C11SHouse/Services/ServiceContainer.swift`
  - Add `homeKitService` lazy property
  - Initialize with NotesService dependency
  - Make available to ViewModelFactory

### Phase 4: Note Creation Integration 📝

#### 4.1 Extend Notes Service
- [ ] **MODIFY** `/C11Shouse/C11SHouse/Services/Notes/NotesService+Questions.swift`
  - Add HomeKit-specific question IDs
  - Define HomeKit note categories
  - Add HomeKit metadata keys

#### 4.2 Create HomeKit Import ViewModel
- [ ] **NEW** `/C11Shouse/C11SHouse/ViewModels/HomeKitImportViewModel.swift`
  - Manage import state and progress
  - Handle error cases
  - Provide import summary
  - Coordinate with HomeKitService

### Phase 5: UI Flow Integration 🎨

#### 5.1 Create Import Progress View
- [ ] **NEW** `/C11Shouse/C11SHouse/Views/Onboarding/HomeKitImportView.swift`
  - Show discovery progress
  - Display import results
  - Handle skip/error cases
  - Provide continue action

#### 5.2 Update Onboarding Flow
- [ ] **MODIFY** `/C11Shouse/C11SHouse/Views/Onboarding/OnboardingCoordinator.swift`
  - Add `.homeKitImport` phase
  - Insert between permissions and conversation
  - Handle HomeKit permission check
  - Skip if permission denied
  - Background import during conversation

- [ ] **MODIFY** `/C11Shouse/C11SHouse/Views/Onboarding/OnboardingContainerView.swift`
  - Add case for HomeKitImportView
  - Update phase transitions
  - Ensure smooth flow

#### 5.3 Update ViewModelFactory
- [ ] **MODIFY** `/C11Shouse/C11SHouse/ViewModels/ViewModelFactory.swift`
  - Add `makeHomeKitImportViewModel()` method
  - Inject HomeKitService dependency

### Phase 6: Testing Implementation 🧪

#### 6.1 Create Unit Tests
- [ ] **NEW** `/C11Shouse/C11SHouseTests/Services/HomeKitServiceTests.swift`
  - Test discovery logic
  - Test note creation
  - Test error handling
  - Mock HMHomeManager

- [ ] **NEW** `/C11Shouse/C11SHouseTests/Infrastructure/PermissionManagerHomeKitTests.swift`
  - Test HomeKit permission flow
  - Test status updates
  - Test combined permissions

#### 6.2 Create UI Tests
- [ ] **MODIFY** `/C11Shouse/C11SHouseUITests/OnboardingUITests.swift`
  - Add HomeKit permission test
  - Test skip flow
  - Test import progress

- [ ] **NEW** `/C11Shouse/C11SHouseUITests/HomeKitIntegrationUITests.swift`
  - End-to-end import test
  - Test note creation
  - Test error recovery

#### 6.3 Create Test Mocks
- [ ] **MODIFY** `/C11Shouse/C11SHouseTests/Mocks/TestMocks.swift`
  - Add MockHomeKitService
  - Add MockHMHomeManager
  - Add test home configurations

### Phase 7: Polish and Edge Cases 🎁

#### 7.1 Error Handling
- [ ] **MODIFY** `/C11Shouse/C11SHouse/Utils/ErrorHandling/UserFriendlyError.swift`
  - Add HomeKit error cases
  - Provide recovery suggestions

#### 7.2 Analytics and Logging
- [ ] **MODIFY** `/C11Shouse/C11SHouse/Services/OnboardingLogger.swift`
  - Add HomeKit permission events
  - Track import success/failure
  - Log discovered configuration size

#### 7.3 Conversation Integration
- [ ] **MODIFY** `/C11Shouse/C11SHouse/ViewModels/ConversationViewModel.swift`
  - Add prompts about discovered rooms
  - Reference imported devices
  - Update suggested responses

## 📊 Progress Tracking

### Summary
- **New Files**: 6
- **Modified Files**: 15
- **Test Files**: 4
- **Total Changes**: 25

### Time Estimates
- Phase 1 (Splash): 2-3 hours
- Phase 2 (Permissions): 4-6 hours  
- Phase 3 (Service): 8-10 hours
- Phase 4 (Notes): 3-4 hours
- Phase 5 (UI): 4-5 hours
- Phase 6 (Testing): 6-8 hours
- Phase 7 (Polish): 3-4 hours
- **Total**: 30-40 hours

## 🚀 Getting Started

1. Start with Phase 1 (Splash Screen) as it's independent
2. Phase 2-3 can be developed in parallel
3. Phase 4-5 depend on Phase 3 completion
4. Testing can begin after each phase
5. Polish throughout development

## ⚠️ Critical Dependencies

1. **Xcode Project**: HomeKit capability must be added
2. **Apple Developer**: HomeKit must be enabled in App ID
3. **Provisioning**: New profiles needed after capability
4. **iOS Version**: Requires iOS 13.0+ for HomeKit
5. **Testing**: HomeKit requires device or good mocks

## 📱 Device Testing Requirements

1. Physical device recommended for HomeKit
2. Test home with multiple rooms/devices
3. Test without any HomeKit setup
4. Test with denied permissions
5. Test with restricted HomeKit access

## 🎯 Definition of Done

Each item is complete when:
- [ ] Code implemented and compiles
- [ ] Unit tests pass
- [ ] UI tests pass  
- [ ] No regression in existing features
- [ ] Code reviewed and documented
- [ ] Edge cases handled
- [ ] Errors have recovery paths
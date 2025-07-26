# HomeKit Integration System Design

## Executive Summary

This document provides a comprehensive system architecture and implementation approach for integrating HomeKit functionality into the C11S House iOS app. The design focuses on three new elements:

1. **Splash Screen Animation**: Brain+circle flying into house icon
2. **HomeKit Permission Integration**: Seamless permission request during onboarding
3. **HomeKit Configuration Discovery**: Automated import of rooms and devices into the Notes system

## System Architecture Overview

### High-Level Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
├─────────────────────────────────────────────────────────────┤
│ SplashView │ OnboardingPermissionsView │ ConversationView  │
└────────────┴──────────────┬────────────┴───────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                    ViewModel Layer                           │
├─────────────────────────────────────────────────────────────┤
│ SplashViewModel │ HomeKitImportViewModel │ ContentViewModel │
└─────────────────┴───────────┬───────────┴──────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│                    Service Layer                             │
├─────────────────────────────────────────────────────────────┤
│ HomeKitService │ NotesService │ PermissionManager │         │
└────────────────┴─────────────┴──────────┬──────────────────┘
                                          │
┌─────────────────────────────────────────▼───────────────────┐
│                 Infrastructure Layer                         │
├─────────────────────────────────────────────────────────────┤
│           HomeKit Framework │ Core Data │ UserDefaults      │
└─────────────────────────────────────────────────────────────┘
```

## Detailed Component Design

### 1. Splash Screen Animation System

#### Component: SplashView.swift
**Location**: `/C11Shouse/C11SHouse/Views/SplashView.swift`

```swift
struct SplashView: View {
    @State private var animationPhase = AnimationPhase.initial
    @Binding var isComplete: Bool
    
    enum AnimationPhase {
        case initial
        case flying
        case landing
        case complete
    }
    
    // Animation properties
    @State private var brainPosition: CGPoint = .zero
    @State private var brainScale: CGFloat = 1.0
    @State private var houseOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(/*...*/)
            
            // House icon (destination)
            Image(uiImage: AppIconCreatorLegacy.createHouseOnly())
                .opacity(houseOpacity)
                .position(housePosition)
            
            // Brain+Circle (flying element)
            Image(uiImage: AppIconCreatorLegacy.createBrainCircle())
                .scaleEffect(brainScale)
                .position(brainPosition)
                .animation(.easeInOut(duration: 1.5))
        }
        .onAppear { startAnimation() }
    }
}
```

#### Integration Point: C11SHouseApp.swift
```swift
@main
struct C11SHouseApp: App {
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView(isComplete: $showSplash)
            } else {
                ContentView()
                    .environmentObject(serviceContainer)
                    .withOnboarding(serviceContainer: serviceContainer)
            }
        }
    }
}
```

### 2. HomeKit Permission System

#### Enhanced PermissionManager
**Location**: `/C11Shouse/C11SHouse/Infrastructure/Voice/PermissionManager.swift`

```swift
import HomeKit

extension PermissionManager {
    // New property
    @Published public private(set) var homeKitPermissionStatus: HMHomeManagerAuthorizationStatus = .notDetermined
    
    // New method
    public func requestHomeKitPermission() async {
        // Create home manager to trigger permission
        let homeManager = HMHomeManager()
        
        // Wait for initial data load
        await withCheckedContinuation { continuation in
            // HMHomeManager will trigger permission dialog on first access
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.homeKitPermissionStatus = homeManager.authorizationStatus
                self.updateAllPermissionsStatus()
                continuation.resume()
            }
        }
    }
    
    public var isHomeKitGranted: Bool {
        homeKitPermissionStatus == .authorized
    }
}
```

#### Updated OnboardingPermissionsView
**Location**: `/C11Shouse/C11SHouse/Views/Onboarding/OnboardingPermissionsView.swift`

Add HomeKit permission card:
```swift
PermissionCard(
    icon: "homekit",
    title: "HomeKit",
    description: "To find existing named rooms and devices",
    status: permissionManager.isHomeKitGranted ? .granted : 
            (permissionManager.homeKitPermissionStatus == .restricted ? .denied : .notDetermined),
    isRequired: false
)
```

### 3. HomeKit Service Architecture

#### Protocol Definition
**Location**: `/C11Shouse/C11SHouse/Services/HomeKitService.swift`

```swift
import HomeKit

// MARK: - Data Models

struct HomeConfiguration {
    let id: UUID
    let name: String
    let isPrimary: Bool
    let rooms: [RoomConfiguration]
    let accessories: [AccessoryConfiguration]
    let createdAt: Date
}

struct RoomConfiguration {
    let id: UUID
    let name: String
    let accessories: [AccessoryConfiguration]
}

struct AccessoryConfiguration {
    let id: UUID
    let name: String
    let category: String // HMAccessoryCategoryType as string
    let manufacturer: String?
    let model: String?
    let roomName: String?
    let services: [String] // Service types
}

// MARK: - Service Protocol

protocol HomeKitServiceProtocol {
    /// Discover all homes accessible to the app
    func discoverHomes() async throws -> [HomeConfiguration]
    
    /// Import HomeKit configuration into Notes
    func importConfiguration(_ config: HomeConfiguration) async throws
    
    /// Check if HomeKit is available
    var isHomeKitAvailable: Bool { get }
}

// MARK: - Service Implementation

@MainActor
class HomeKitService: NSObject, HomeKitServiceProtocol {
    private let homeManager = HMHomeManager()
    private let notesService: NotesServiceProtocol
    
    init(notesService: NotesServiceProtocol) {
        self.notesService = notesService
        super.init()
        homeManager.delegate = self
    }
    
    var isHomeKitAvailable: Bool {
        homeManager.authorizationStatus == .authorized
    }
    
    func discoverHomes() async throws -> [HomeConfiguration] {
        // Implementation
    }
    
    func importConfiguration(_ config: HomeConfiguration) async throws {
        // Create summary note
        let summaryNote = createSummaryNote(from: config)
        try await notesService.saveNote(summaryNote)
        
        // Create room notes
        for room in config.rooms {
            let roomNote = createRoomNote(from: room)
            try await notesService.saveNote(roomNote)
        }
        
        // Create device notes
        for accessory in config.accessories {
            let deviceNote = createDeviceNote(from: accessory)
            try await notesService.saveNote(deviceNote)
        }
    }
}
```

### 4. Note Creation Strategy

#### HomeKit Note Types

1. **Summary Note**
   - Category: "homekit_summary"
   - Title: "HomeKit Configuration"
   - Content: Overview of all homes, rooms, and devices

2. **Room Notes**
   - Category: "room"
   - Title: Room name (e.g., "Living Room")
   - Content: List of devices in the room
   - Metadata: HomeKit room ID, home ID

3. **Device Notes**
   - Category: "device"
   - Title: Device name (e.g., "Kitchen Light")
   - Content: Device details, capabilities, room location
   - Metadata: HomeKit accessory ID, room ID, category

#### Note Creation Implementation

```swift
extension HomeKitService {
    private func createSummaryNote(from config: HomeConfiguration) -> Note {
        let content = """
        Home: \(config.name)
        Rooms: \(config.rooms.count)
        Devices: \(config.accessories.count)
        
        Room Summary:
        \(config.rooms.map { "- \($0.name): \($0.accessories.count) devices" }.joined(separator: "\n"))
        
        Device Categories:
        \(groupAccessoriesByCategory(config.accessories))
        """
        
        return Note(
            questionId: UUID(), // Special HomeKit question ID
            answer: content,
            metadata: [
                "type": "homekit_summary",
                "home_id": config.id.uuidString,
                "imported_at": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }
    
    private func createRoomNote(from room: RoomConfiguration) -> Note {
        let devices = room.accessories.map { "- \($0.name) (\($0.category))" }.joined(separator: "\n")
        
        let content = """
        Room: \(room.name)
        Devices: \(room.accessories.count)
        
        \(devices.isEmpty ? "No devices in this room" : devices)
        """
        
        return Note(
            questionId: UUID(),
            answer: content,
            metadata: [
                "type": "room",
                "room_id": room.id.uuidString,
                "device_count": "\(room.accessories.count)"
            ]
        )
    }
}
```

### 5. Integration Points

#### ServiceContainer Update
```swift
// Add to ServiceContainer.swift
private(set) lazy var homeKitService: HomeKitServiceProtocol = {
    HomeKitService(notesService: notesService)
}()
```

#### OnboardingCoordinator Integration
```swift
// In OnboardingCoordinator after permissions granted
if permissionManager.isHomeKitGranted {
    Task {
        do {
            let homes = try await serviceContainer.homeKitService.discoverHomes()
            if let primaryHome = homes.first(where: { $0.isPrimary }) ?? homes.first {
                try await serviceContainer.homeKitService.importConfiguration(primaryHome)
            }
        } catch {
            // Log error but don't block onboarding
            print("HomeKit import failed: \(error)")
        }
    }
}
```

### 6. UI Flow Integration

#### Updated Onboarding Flow

1. **Splash Screen** → 2. **Permissions** → 3. **HomeKit Import** → 4. **Conversation**

```swift
enum OnboardingPhase {
    case splash
    case permissions
    case homeKitImport  // New phase
    case conversation
    case complete
}
```

#### HomeKit Import Progress View
```swift
struct HomeKitImportView: View {
    @StateObject var viewModel: HomeKitImportViewModel
    
    var body: some View {
        VStack {
            if viewModel.isImporting {
                ProgressView()
                Text("Discovering your smart home...")
            } else if let summary = viewModel.importSummary {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Found \(summary.roomCount) rooms")
                    Text("Imported \(summary.deviceCount) devices")
                }
            }
        }
    }
}
```

## File Structure

### New Files to Create
```
C11Shouse/C11SHouse/
├── Views/
│   └── SplashView.swift
├── Services/
│   └── HomeKitService.swift
├── Models/
│   └── HomeKitModels.swift
├── ViewModels/
│   └── HomeKitImportViewModel.swift
└── Views/Onboarding/
    └── HomeKitImportView.swift
```

### Files to Modify
```
C11Shouse/C11SHouse/
├── C11SHouseApp.swift (add splash screen)
├── Infrastructure/Voice/
│   └── PermissionManager.swift (add HomeKit)
├── Views/Onboarding/
│   ├── OnboardingPermissionsView.swift (add HomeKit card)
│   └── OnboardingCoordinator.swift (add HomeKit phase)
├── Services/
│   └── ServiceContainer.swift (add HomeKitService)
└── Info-additions.plist (add HomeKit usage description)
```

## Implementation Phases

### Phase 1: Splash Screen (2-3 hours)
1. Create SplashView with animation
2. Create AppIconCreatorLegacy helper methods
3. Integrate into C11SHouseApp
4. Test animation timing and transitions

### Phase 2: HomeKit Permission (4-6 hours)
1. Update Info.plist with HomeKit usage
2. Extend PermissionManager
3. Add HomeKit permission card
4. Update permission flow logic
5. Test permission scenarios

### Phase 3: HomeKit Service (8-10 hours)
1. Create HomeKitModels
2. Implement HomeKitService
3. Integrate with NotesService
4. Add to ServiceContainer
5. Unit test service logic

### Phase 4: UI Integration (4-5 hours)
1. Create HomeKitImportView
2. Update OnboardingCoordinator
3. Add progress indicators
4. Test end-to-end flow

### Phase 5: Testing (6-8 hours)
1. Unit tests for HomeKitService
2. UI tests for permission flow
3. Integration tests
4. Mock HomeKit for testing

## Testing Strategy

### Unit Tests
```swift
class HomeKitServiceTests: XCTestCase {
    func testDiscoverHomes() async throws {
        // Test with mock HMHomeManager
    }
    
    func testImportConfiguration() async throws {
        // Test note creation logic
    }
}
```

### UI Tests
```swift
class HomeKitOnboardingUITests: XCTestCase {
    func testHomeKitPermissionFlow() {
        // Test permission request and handling
    }
}
```

### Mock Strategy
```swift
protocol HomeManagerProtocol {
    var homes: [HMHome] { get }
    var authorizationStatus: HMHomeManagerAuthorizationStatus { get }
}

// Use protocol for testing instead of concrete HMHomeManager
```

## Security & Privacy Considerations

1. **Data Storage**: Only configuration data, no credentials
2. **Permission Clarity**: Clear explanation why HomeKit is needed
3. **Graceful Degradation**: App works without HomeKit
4. **No Cloud Sync**: HomeKit data stays local
5. **User Control**: Can skip or disable HomeKit features

## Performance Considerations

1. **Async Operations**: All HomeKit calls are async
2. **Background Import**: Import during onboarding
3. **Progress Feedback**: Show import progress
4. **Batch Operations**: Create notes in batches
5. **Error Recovery**: Continue on partial failure

## Future Enhancements

1. **Multi-Home Support**: Handle multiple homes
2. **Update Detection**: Detect HomeKit changes
3. **Scene Integration**: Import HomeKit scenes
4. **Automation Awareness**: Understand automations
5. **Device Control**: Future control capabilities

## Success Criteria

1. ✅ Splash animation completes in < 2 seconds
2. ✅ HomeKit permission integrates seamlessly
3. ✅ Import completes in < 5 seconds for typical home
4. ✅ All rooms and devices create notes
5. ✅ No regression in existing functionality
6. ✅ 90%+ test coverage for new code

## Risk Mitigation

1. **No HomeKit**: Skip gracefully, manual entry
2. **Large Configs**: Progress indication, pagination
3. **Permission Denied**: Clear re-request instructions
4. **Import Errors**: Partial import, error recovery
5. **iOS Version**: Conditional compilation for iOS 13+
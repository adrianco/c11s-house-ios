# C11S House iOS - Code Refactoring Plan
*Generated: 2025-01-09*
*Hive Mind Analysis by Queen Coordinator*

## 🧹 Executive Summary

The codebase is functional but has significant architectural issues. The main problem is **ConversationView.swift (622 lines!)** doing too much, combined with scattered business logic and tight coupling. This plan addresses these issues while keeping NotesService as the unified persistent memory system.

---

## 🚨 Critical Issues Identified

### 1. **Massive ConversationView (622 lines)**
- **Problem**: Handles UI, business logic, question management, address parsing, and more
- **Impact**: Hard to maintain, test, and reason about

### 2. **Code Duplication**
- **Problem**: House name generation and address parsing duplicated across files
- **Impact**: Risk of inconsistent behavior

### 3. **Threading Complexity**
- **Problem**: ConversationRecognizer uses complex threading with magic error codes
- **Impact**: Potential race conditions and unclear error handling

### 4. **ServiceContainer Overreach**
- **Problem**: Creating ViewModels instead of just managing services
- **Impact**: Violates dependency injection principles

---

## 🛠️ Detailed Refactoring Plan

### **Phase 1: Extract Business Logic from Views**

#### 1.1 Create `QuestionFlowCoordinator`
```swift
// New file: Services/QuestionFlowCoordinator.swift
class QuestionFlowCoordinator: ObservableObject {
    private let notesService: NotesServiceProtocol
    
    // Move question flow logic from ConversationView
    // Handle question progression and validation
    // Coordinate with NotesService for persistence
}
```

#### 1.2 Create `AddressManager`
```swift
// New file: Services/AddressManager.swift
class AddressManager {
    // Consolidate address parsing and validation
    // Handle address detection
    // Generate house names from addresses
    // Still saves to NotesService for persistence
}
```

#### 1.3 Create `ConversationStateManager`
```swift
// New file: ViewModels/ConversationStateManager.swift
class ConversationStateManager: ObservableObject {
    // Extract complex state logic from ConversationView
    // Handle transcript management
    // Coordinate TTS playback
    // Manage recording state
}
```

### **Phase 2: Enhance NotesService as Central Memory**

#### 2.1 Keep NotesService as-is but add clear documentation
```swift
/*
 * NotesService is the central persistent memory system for the app.
 * It stores all types of notes including Q&A, weather summaries, 
 * house preferences, and will expand to include more note types.
 * Future: Will sync with backend and provide context to AI.
 */
```

#### 2.2 Create helper managers that use NotesService
```swift
// These coordinators handle business logic but persist via NotesService
QuestionFlowCoordinator -> NotesService (persistence)
AddressManager -> NotesService (persistence)
WeatherCoordinator -> NotesService (persistence)
```

### **Phase 3: Clean Up ConversationView**

#### 3.1 Extract methods to appropriate coordinators
- Move `loadCurrentQuestion()` → QuestionFlowCoordinator
- Move `detectAndPreloadAddress()` → AddressManager
- Move `handleAddressSaved()` → AddressManager
- Move `generateHouseNameSuggestion()` → AddressManager
- Move `saveAnswer()` → QuestionFlowCoordinator

#### 3.2 Simplify ConversationView to ~200 lines
```swift
struct ConversationView: View {
    @StateObject private var stateManager: ConversationStateManager
    @StateObject private var questionFlow: QuestionFlowCoordinator
    @StateObject private var recognizer = ConversationRecognizer()
    
    // Just UI and coordination, no business logic
}
```

### **Phase 4: Infrastructure Improvements**

#### 4.1 Fix ConversationRecognizer error handling
```swift
enum SpeechError {
    case noSpeechDetected
    case recordingError(NSError)
    case cancelled
    
    init(nsError: NSError) {
        switch nsError.code {
        case 1110: self = .noSpeechDetected
        case 1101: self = .recordingError(nsError)
        case 203, 216, 301: self = .cancelled
        default: self = .recordingError(nsError)
        }
    }
}
```

#### 4.2 Create ViewModelFactory
```swift
// Move ViewModel creation out of ServiceContainer
class ViewModelFactory {
    private let serviceContainer: ServiceContainer
    
    func makeContentViewModel() -> ContentViewModel
    func makeConversationViewModel() -> ConversationStateManager
}
```

### **Phase 5: Shared Utilities**

#### 5.1 AddressParser utility
```swift
// Utilities/AddressParser.swift
struct AddressParser {
    static func parse(_ text: String) -> Address?
    static func generateHouseName(from street: String) -> String
}
```

#### 5.2 Create extension for common patterns
```swift
extension NotesServiceProtocol {
    // Convenience methods that multiple coordinators use
    func getCurrentQuestion() async -> Question?
    func getNextUnansweredQuestion() async -> Question?
}
```

---

## 📝 Implementation Order

### **Sprint 1: Core Coordinators (Week 1)**
1. Create QuestionFlowCoordinator
2. Create AddressManager
3. Create ConversationStateManager
4. Wire up coordinators in ConversationView

### **Sprint 2: Extract Logic from Views (Week 2)**
1. Move all business logic from ConversationView to coordinators
2. Create AddressParser utility
3. Update ContentViewModel to use AddressManager
4. Test that NotesService still works as central memory

### **Sprint 3: Infrastructure (Week 3)**
1. Fix error handling in ConversationRecognizer
2. Create ViewModelFactory
3. Update ServiceContainer
4. Standardize async/await patterns

### **Sprint 4: Polish (Week 4)**
1. Add comprehensive documentation
2. Remove code duplication
3. Add unit tests for coordinators
4. Verify NotesService is ready for backend sync

---

## ✅ Benefits of This Approach

1. **Views remain unchanged** - All refactoring is behind the scenes
2. **Single source of truth** - NotesService remains central memory
3. **Backend ready** - Easy to add sync when needed
4. **AI context ready** - All notes available for AI conversation context
5. **Testability** - Business logic extracted to testable units
6. **Maintainability** - Clear separation of concerns
7. **Performance** - Reduced view complexity = faster SwiftUI updates

---

## 🎯 Key Architecture

```
Views (UI only)
    ↓
Coordinators (Business Logic)
    ↓
NotesService (Persistent Memory)
    ↓
Future: Backend Sync & AI Context
```

---

## 📊 Success Metrics

- ConversationView reduced from 622 to ~200 lines
- Zero code duplication
- All business logic in testable services
- Consistent error handling throughout
- Clear separation between UI and logic
- NotesService ready for backend integration

---

## 🔍 Files to be Modified

### High Priority (Most Impact)
1. `ConversationView.swift` - Extract 400+ lines of business logic
2. `ContentViewModel.swift` - Use new AddressManager
3. `ServiceContainer.swift` - Remove ViewModel creation

### New Files to Create
1. `Services/QuestionFlowCoordinator.swift`
2. `Services/AddressManager.swift`
3. `ViewModels/ConversationStateManager.swift`
4. `ViewModels/ViewModelFactory.swift`
5. `Utilities/AddressParser.swift`

### Infrastructure Updates
1. `ConversationRecognizer.swift` - Proper error types
2. `AudioSessionManager.swift` - Simplify threading
3. `TranscriptionServiceImpl.swift` - Remove objc_sync patterns

---

## 📝 Notes

- This plan preserves NotesService as the central persistent memory system
- All views remain unchanged - refactoring is purely architectural
- The app will continue to function normally throughout the refactoring
- Each sprint can be deployed independently
- Unit tests should be added for each new coordinator/manager
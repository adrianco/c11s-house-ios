# NotesService Tests - Central Memory System Validation

## Overview

NotesServiceTests provides comprehensive validation for the **CENTRAL PERSISTENT MEMORY SYSTEM** of the C11S House app. Since NotesService is the foundation for AI context and future backend synchronization, these tests are **CRITICAL** for ensuring data integrity and reliability.

## Test Coverage

### 1. Initialization Tests
- ✅ Default questions creation on first launch
- ✅ Loading existing data from UserDefaults
- ✅ Proper version handling

### 2. CRUD Operations
- ✅ **Create**: `saveNote()` with validation
- ✅ **Read**: `getNote()` and `loadNotesStore()`
- ✅ **Update**: `updateNote()` with timestamp updates
- ✅ **Delete**: `deleteNote()` for individual notes
- ✅ **Convenience**: `saveOrUpdateNote()` for simplified operations

### 3. Question Management
- ✅ Adding custom questions
- ✅ Deleting questions and their associated notes
- ✅ Resetting to default questions while preserving answers
- ✅ Clearing all data

### 4. Thread Safety
- ✅ Concurrent save operations
- ✅ Concurrent read/write operations
- ✅ Publisher updates on MainActor
- ✅ No race conditions or data corruption

### 5. Persistence Testing
- ✅ Data survives across service instances
- ✅ Proper JSON encoding/decoding
- ✅ Corrupt data handling
- ✅ UserDefaults isolation in tests

### 6. Special Features
- ✅ **House Name**: Save/retrieve house name functionality
- ✅ **Weather Summary**: Automatic weather data persistence
- ✅ **Migration**: Handles old data format updates
- ✅ **Publishers**: Reactive updates for UI

### 7. Error Handling
- ✅ Question not found errors
- ✅ Note not found errors
- ✅ Duplicate question prevention
- ✅ Encoding/decoding failures
- ✅ Migration failures

## Key Test Patterns

### Async/Await Testing
```swift
func testSaveNote() async throws {
    // Given: Setup
    let store = try await sut.loadNotesStore()
    
    // When: Action
    try await sut.saveNote(note)
    
    // Then: Verify
    let updated = try await sut.loadNotesStore()
    XCTAssertNotNil(updated.notes[questionId])
}
```

### Thread Safety Testing
```swift
func testConcurrentOperations() async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for item in items {
            group.addTask {
                try await self.sut.performOperation(item)
            }
        }
        try await group.waitForAll()
    }
}
```

### Mock UserDefaults
```swift
override func setUp() {
    // Isolated UserDefaults for each test
    mockUserDefaults = UserDefaults(suiteName: "com.test.\(UUID())")
    sut = NotesServiceImpl(userDefaults: mockUserDefaults)
}
```

## Running the Tests

### Xcode
1. Open `C11SHouse.xcodeproj`
2. Press `Cmd+U` or select Product → Test
3. View results in the Test Navigator

### Command Line
```bash
# Run NotesService tests only
./run-notes-service-tests.sh

# Run all tests
xcodebuild test -project C11SHouse.xcodeproj -scheme C11SHouse
```

## Test Isolation

Each test:
- Uses isolated UserDefaults instance
- Cleans up after execution
- Doesn't affect other tests
- Runs independently

## Critical Test Scenarios

### 1. Data Integrity
Tests ensure no data loss during:
- Concurrent operations
- Service restarts
- Migration processes
- Error conditions

### 2. Thread Safety
Validates proper handling of:
- Multiple simultaneous saves
- Read during write operations
- Publisher updates on MainActor

### 3. Persistence
Confirms data survives:
- App restarts
- Service re-initialization
- UserDefaults synchronization

## Maintenance

When modifying NotesService:
1. Run all tests before committing
2. Add tests for new functionality
3. Ensure thread safety for new operations
4. Update migration tests if data format changes

## Performance Considerations

Tests are designed to:
- Run quickly (< 1 second per test)
- Use minimal memory
- Avoid network/disk I/O (mock UserDefaults)
- Test edge cases efficiently

## Future Enhancements

- [ ] Backend synchronization tests (when implemented)
- [ ] Encryption tests (for sensitive data)
- [ ] Performance tests for large datasets
- [ ] Memory leak detection tests
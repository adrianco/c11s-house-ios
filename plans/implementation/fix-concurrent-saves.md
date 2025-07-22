# Fix: Concurrent Save Operations in NotesService

## Issue Summary
Concurrent save operations in NotesService are experiencing race conditions where multiple threads load the same initial state, modify it, and save - causing the last save to overwrite all previous changes.

## Root Cause Analysis

The current implementation has a classic read-modify-write race condition:

```swift
// Current problematic pattern:
func saveNote(_ note: Note) async throws {
    var store = try await loadFromUserDefaults()  // Thread A loads state
    // Thread B also loads same state here
    store.notes[note.questionId] = note           // Thread A modifies
    // Thread B also modifies its copy
    try await save(store)                         // Thread A saves
    // Thread B saves, overwriting Thread A's changes
}
```

## Solution: Actor-Based State Management

### Implementation Plan

1. **Add in-memory cache to NotesService**
```swift
@NotesStoreActor
private var cachedStore: NotesStoreData?
@NotesStoreActor
private var lastLoadTime: Date?
private let cacheTimeout: TimeInterval = 5.0 // 5 seconds

@NotesStoreActor
private func getStore() async throws -> NotesStoreData {
    // Check if we have a valid cached store
    if let cached = cachedStore,
       let loadTime = lastLoadTime,
       Date().timeIntervalSince(loadTime) < cacheTimeout {
        return cached
    }
    
    // Load fresh from UserDefaults
    let store = try await loadFromUserDefaults()
    cachedStore = store
    lastLoadTime = Date()
    return store
}

@NotesStoreActor
private func updateStore(_ store: NotesStoreData) async throws {
    // Update cache
    cachedStore = store
    lastLoadTime = Date()
    
    // Persist to UserDefaults
    try await save(store)
}
```

2. **Refactor saveNote to use cached store**
```swift
@NotesStoreActor
func saveNote(_ note: Note) async throws {
    // Get current store (from cache if valid)
    var store = try await getStore()
    
    // Ensure the question exists
    guard store.questions.contains(where: { $0.id == note.questionId }) else {
        throw NotesError.questionNotFound(note.questionId)
    }
    
    // Update the note
    store.notes[note.questionId] = note
    
    // Save and update cache atomically
    try await updateStore(store)
}
```

3. **Add batch save operation for efficiency**
```swift
@NotesStoreActor
func saveNotes(_ notes: [Note]) async throws {
    // Single load
    var store = try await getStore()
    
    // Validate all questions exist
    for note in notes {
        guard store.questions.contains(where: { $0.id == note.questionId }) else {
            throw NotesError.questionNotFound(note.questionId)
        }
    }
    
    // Update all notes
    for note in notes {
        store.notes[note.questionId] = note
    }
    
    // Single save
    try await updateStore(store)
}
```

4. **Add synchronization for critical sections**
```swift
actor NotesServiceImpl: NotesService {
    // Existing code...
    
    // Serial queue for operations that must be atomic
    private let operationQueue = AsyncSerialQueue()
    
    func saveNote(_ note: Note) async throws {
        try await operationQueue.enqueue {
            try await self._saveNote(note)
        }
    }
    
    @NotesStoreActor
    private func _saveNote(_ note: Note) async throws {
        // Implementation as above
    }
}

// Helper: Async serial queue
actor AsyncSerialQueue {
    private var currentTask: Task<Void, Error>?
    
    func enqueue<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        // Wait for previous task
        _ = try? await currentTask?.value
        
        // Create new task
        let task = Task {
            try await operation()
        }
        currentTask = task
        
        return try await task.value
    }
}
```

5. **Alternative: Use NSLock for synchronization**
```swift
final class NotesServiceImpl: NotesService {
    private let lock = NSLock()
    private var store: NotesStoreData?
    
    func saveNote(_ note: Note) async throws {
        lock.lock()
        defer { lock.unlock() }
        
        // Load if needed
        if store == nil {
            store = try await loadFromUserDefaults()
        }
        
        // Modify
        guard var currentStore = store else {
            throw NotesError.storeNotLoaded
        }
        
        guard currentStore.questions.contains(where: { $0.id == note.questionId }) else {
            throw NotesError.questionNotFound(note.questionId)
        }
        
        currentStore.notes[note.questionId] = note
        store = currentStore
        
        // Save
        try await save(currentStore)
    }
}
```

## Recommended Solution

Use the **Actor-based approach with caching** (options 1-3) because:
- It's more Swift-idiomatic
- Actor isolation provides compile-time safety
- Caching improves performance
- No manual lock management

## Testing the Fix

Update the concurrent save test to verify the fix:

```swift
func testConcurrentSaveOperations() async throws {
    // Given: Multiple questions
    let questions = (0..<10).map { i in
        Question(text: "Concurrent Q\(i)", category: .general, order: i)
    }
    
    // Add all questions first
    for question in questions {
        try await sut.addQuestion(question)
    }
    
    // When: Saving notes concurrently
    try await withThrowingTaskGroup(of: Void.self) { group in
        for (index, question) in questions.enumerated() {
            group.addTask {
                let note = Note(
                    questionId: question.id,
                    answer: "Concurrent answer \(index)"
                )
                try await self.sut.saveNote(note)
            }
        }
        try await group.waitForAll()
    }
    
    // Then: All notes should be saved
    let finalStore = try await sut.loadNotesStore()
    for (index, question) in questions.enumerated() {
        XCTAssertNotNil(finalStore.notes[question.id])
        XCTAssertEqual(
            finalStore.notes[question.id]?.answer,
            "Concurrent answer \(index)"
        )
    }
}
```

## Migration Notes

1. This change is backward compatible
2. Existing data will be preserved
3. Performance should improve due to caching
4. Memory usage slightly increases (cached store)
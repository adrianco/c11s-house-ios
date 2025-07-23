# Fix: Threading Violations in UI Tests

## Issue Summary
UI operations are being performed on background threads in `ThreadingSafetyUITests.swift`, causing test crashes with "Must be called on the main thread" errors.

## Implementation Plan

### 1. Fix testConcurrentUIOperations() 

**Current problematic code (lines 223-264):**
```swift
func testConcurrentUIOperations() throws {
    // ... navigation code ...
    
    let group = DispatchGroup()
    let queue = DispatchQueue.global(qos: .userInteractive)
    
    // Operation 1: Toggle edit mode
    group.enter()
    queue.async {
        for _ in 0..<5 {
            let editButton = self.app.navigationBars.buttons.matching(identifier: "Edit").firstMatch
            if editButton.exists {
                editButton.tap() // ❌ UI operation on background thread!
            }
            // ... more UI operations ...
        }
        group.leave()
    }
```

**Fixed implementation:**
```swift
func testConcurrentUIOperations() throws {
    // Navigate to notes via settings menu
    let settingsButton = app.buttons["gearshape.fill"]
    settingsButton.tap()
    let notesMenuItem = app.buttons["Manage Notes"]
    notesMenuItem.tap()
    
    // Create multiple concurrent operations
    let group = DispatchGroup()
    
    // Operation 1: Toggle edit mode on main thread
    group.enter()
    Task { @MainActor in
        for _ in 0..<5 {
            let editButton = app.navigationBars.buttons.matching(identifier: "Edit").firstMatch
            if editButton.exists {
                editButton.tap()
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            let doneButton = app.navigationBars.buttons.matching(identifier: "Done").firstMatch
            if doneButton.exists {
                doneButton.tap()
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        group.leave()
    }
    
    // Operation 2: Scroll content on main thread
    group.enter()
    Task { @MainActor in
        for _ in 0..<5 {
            app.swipeUp()
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            app.swipeDown()
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        group.leave()
    }
    
    // Wait for completion
    let result = group.wait(timeout: .now() + 10)
    XCTAssertEqual(result, .success)
    
    // Verify app stability
    XCTAssertTrue(app.state == .runningForeground)
}
```

### 2. Alternative Approach: Simulate Concurrency Without Background Threads

Since UI tests should simulate user interactions (which are inherently sequential), we can test threading safety by:

```swift
func testConcurrentUIOperations() throws {
    // Navigate to notes
    navigateToNotesView()
    
    // Simulate rapid user interactions that might trigger concurrency issues
    // These all happen on main thread but stress the app's internal threading
    
    // Rapidly toggle edit mode
    for _ in 0..<10 {
        if let editButton = app.navigationBars.buttons["Edit"].firstMatch, editButton.exists {
            editButton.tap()
            // Don't wait - immediate next action
            if let doneButton = app.navigationBars.buttons["Done"].firstMatch, doneButton.exists {
                doneButton.tap()
            }
        }
    }
    
    // Rapidly scroll while editing
    let editButton = app.navigationBars.buttons["Edit"]
    if editButton.exists {
        editButton.tap()
        
        // Rapid scrolling
        for _ in 0..<5 {
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
        
        let doneButton = app.navigationBars.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
        }
    }
    
    // Verify app survived the stress test
    XCTAssertTrue(app.state == .runningForeground)
}
```

### 3. Add Helper Methods for Thread-Safe UI Testing

```swift
extension ThreadingSafetyUITests {
    /// Performs multiple UI actions concurrently while ensuring they execute on the main thread
    func performConcurrentUIActions(
        actions: [() async -> Void],
        timeout: TimeInterval = 10
    ) async throws {
        await withTaskGroup(of: Void.self) { group in
            for action in actions {
                group.addTask { @MainActor in
                    await action()
                }
            }
        }
    }
    
    /// Stresses the UI with rapid interactions to test internal threading
    func stressTestUI(
        interactions: Int = 20,
        action: () -> Void
    ) {
        for _ in 0..<interactions {
            autoreleasepool {
                action()
            }
        }
        
        // Give the app a moment to process
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
}
```

### 4. Update All Threading Tests

Apply similar fixes to:
- `testRecordingFlowThreadSafety()`
- `testNotesViewRapidEditingThreadSafety()`
- `testBackgroundTransitionWhileRecording()`
- `testRapidViewSwitchingThreadSafety()`
- `testThreadingUnderMemoryPressure()`

## Key Principles

1. **UI operations must always run on main thread** - Use `@MainActor` or `DispatchQueue.main`
2. **Test user behavior, not implementation** - Users can't tap buttons from multiple threads
3. **Stress test through rapid sequential actions** - This better simulates real concurrency issues
4. **Use proper async/await** - Replace Thread.sleep with Task.sleep

## Testing the Fix

After implementing:
1. Run the test suite to ensure no more "main thread" crashes
2. Verify the tests still catch threading issues in the app
3. Check that test execution time remains reasonable
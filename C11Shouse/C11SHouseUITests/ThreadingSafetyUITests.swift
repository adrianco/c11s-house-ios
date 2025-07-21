/*
 * CONTEXT & PURPOSE:
 * ThreadingSafetyUITests performs UI-level testing to verify thread safety during real user
 * interactions. It tests rapid UI actions, permission flows, and concurrent operations to
 * ensure the app remains stable and responsive under various threading conditions.
 *
 * DECISION HISTORY:
 * - 2025-07-04: Initial implementation
 *   - UI tests for threading issues during user interactions
 *   - Core Data concurrency debug flags enabled for thread violation detection
 *   - Tests for rapid button tapping to catch race conditions
 *   - Permission flow tests to verify main thread UI updates
 *   - Navigation stress tests for thread safety
 *   - Background/foreground transition tests
 *   - XCUIApplication launch arguments for enhanced debugging
 *   - Tests simulate real user behavior patterns
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import XCTest

final class ThreadingSafetyUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Enable thread sanitizer in test and skip onboarding
        app.launchArguments = [
            "-com.apple.CoreData.ConcurrencyDebug", "1",
            "-com.apple.CoreData.ThreadingDebug", "1",
            "UI_TESTING",
            "--skip-onboarding"
        ]
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Recording Flow Tests
    
    func testRecordingFlowThreadSafety() throws {
        // Navigate to conversation view using the Start Conversation button
        let conversationButton = app.buttons["StartConversation"]
        if !conversationButton.waitForExistence(timeout: 5) {
            // Fallback to text-based button
            let textButton = app.buttons["Start Conversation"]
            XCTAssertTrue(textButton.waitForExistence(timeout: 5))
            textButton.tap()
        } else {
            conversationButton.tap()
        }
        
        // Wait for conversation view to load
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5))
        
        // Find microphone button for recording
        let recordButton = app.buttons["mic.circle.fill"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        
        // Rapid start/stop to test threading
        for _ in 0..<5 {
            recordButton.tap()
            
            // Wait for recording to start (button changes to stop icon)
            let stopButton = app.buttons["stop.circle.fill"]
            XCTAssertTrue(stopButton.waitForExistence(timeout: 2))
            
            // Quick stop
            Thread.sleep(forTimeInterval: 0.5)
            stopButton.tap()
            
            // Wait for ready state
            XCTAssertTrue(recordButton.waitForExistence(timeout: 2))
        }
        
        // Verify app didn't crash
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Notes View Tests
    
    func testNotesViewRapidEditingThreadSafety() throws {
        // Navigate to notes view via settings menu
        let settingsButton = app.buttons["gearshape.fill"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        
        // Find and tap Manage Notes in menu
        let notesMenuItem = app.buttons["Manage Notes"]
        XCTAssertTrue(notesMenuItem.waitForExistence(timeout: 2))
        notesMenuItem.tap()
        
        // Enter edit mode
        let editButton = app.navigationBars.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        
        // Find first note row
        let firstNote = app.cells.firstMatch
        if firstNote.waitForExistence(timeout: 5) {
            // Rapid tap multiple notes
            for i in 0..<3 {
                let note = app.cells.element(boundBy: i)
                if note.exists {
                    note.tap()
                    
                    // Type rapidly
                    let textEditor = app.textViews.firstMatch
                    if textEditor.waitForExistence(timeout: 2) {
                        textEditor.tap()
                        textEditor.typeText("Test \(i)")
                        
                        // Quick save
                        let saveButton = app.buttons["Save"]
                        if saveButton.exists {
                            saveButton.tap()
                        }
                    }
                }
            }
        }
        
        // Exit edit mode
        let doneButton = app.navigationBars.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
        }
        
        // Verify app stability
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Background/Foreground Tests
    
    func testBackgroundTransitionWhileRecording() throws {
        // Navigate to conversation view
        let conversationButton = app.buttons["StartConversation"]
        if !conversationButton.waitForExistence(timeout: 5) {
            let textButton = app.buttons["Start Conversation"]
            XCTAssertTrue(textButton.waitForExistence(timeout: 5))
            textButton.tap()
        } else {
            conversationButton.tap()
        }
        
        // Wait for conversation view
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5))
        
        // Start recording
        let recordButton = app.buttons["mic.circle.fill"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.tap()
        
        // Wait for recording to start
        let stopButton = app.buttons["stop.circle.fill"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2))
        
        // Simulate background
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
        
        // Return to app
        app.activate()
        Thread.sleep(forTimeInterval: 0.5)
        
        // Stop recording
        if stopButton.exists {
            stopButton.tap()
        }
        
        // Verify app is still responsive
        XCTAssertTrue(app.state == .runningForeground)
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
    }
    
    // MARK: - View Switching Tests
    
    func testRapidViewSwitchingThreadSafety() throws {
        // Since app uses NavigationLinks, not tabs, test navigation between views
        
        // Rapid navigation between conversation and back
        for _ in 0..<5 {
            // Go to conversation
            let conversationButton = app.buttons["StartConversation"]
            if conversationButton.waitForExistence(timeout: 1) {
                conversationButton.tap()
            }
            
            // Go back
            let backButton = app.buttons["Back"]
            if backButton.waitForExistence(timeout: 1) {
                backButton.tap()
            }
        }
        
        // Test settings menu rapid open/close
        for _ in 0..<5 {
            let settingsButton = app.buttons["gearshape.fill"]
            if settingsButton.exists {
                settingsButton.tap()
                // Tap outside to dismiss
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
            }
        }
        
        // Verify final state
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Stress Tests
    
    func testConcurrentUIOperations() throws {
        // Navigate to notes via settings menu
        let settingsButton = app.buttons["gearshape.fill"]
        settingsButton.tap()
        let notesMenuItem = app.buttons["Manage Notes"]
        notesMenuItem.tap()
        
        // Create multiple concurrent operations
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInteractive)
        
        // Operation 1: Toggle edit mode
        group.enter()
        queue.async {
            for _ in 0..<5 {
                let editButton = self.app.navigationBars.buttons.matching(identifier: "Edit").firstMatch
                if editButton.exists {
                    editButton.tap()
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                let doneButton = self.app.navigationBars.buttons.matching(identifier: "Done").firstMatch
                if doneButton.exists {
                    doneButton.tap()
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
            group.leave()
        }
        
        // Operation 2: Scroll content
        group.enter()
        queue.async {
            for _ in 0..<5 {
                self.app.swipeUp()
                Thread.sleep(forTimeInterval: 0.1)
                self.app.swipeDown()
                Thread.sleep(forTimeInterval: 0.1)
            }
            group.leave()
        }
        
        // Wait for completion
        let result = group.wait(timeout: .now() + 10)
        XCTAssertEqual(result, .success)
        
        // Verify app stability
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Memory Pressure Tests
    
    func testThreadingUnderMemoryPressure() throws {
        // Navigate to conversation and start recording
        let conversationButton = app.buttons["StartConversation"]
        if !conversationButton.waitForExistence(timeout: 5) {
            let textButton = app.buttons["Start Conversation"]
            textButton.tap()
        } else {
            conversationButton.tap()
        }
        
        let recordButton = app.buttons["mic.circle.fill"]
        recordButton.tap()
        
        // Simulate memory pressure by rapidly navigating
        for _ in 0..<10 {
            // Go back
            app.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.1)
            
            // Go to conversation again
            app.buttons["StartConversation"].tap()
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Stop recording if still active
        let stopButton = app.buttons["stop.circle.fill"]
        if stopButton.exists {
            stopButton.tap()
        }
        
        // Verify app survived
        XCTAssertTrue(app.state == .runningForeground)
    }
}

// MARK: - Test Helpers

extension XCUIElement {
    func clearAndType(_ text: String) {
        guard self.exists else { return }
        
        self.tap()
        
        // Clear existing text
        if let currentValue = self.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            self.typeText(deleteString)
        }
        
        self.typeText(text)
    }
}
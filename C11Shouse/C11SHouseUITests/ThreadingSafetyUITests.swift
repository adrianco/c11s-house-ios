//
//  ThreadingSafetyUITests.swift
//  C11SHouseUITests
//
//  UI tests to verify threading safety during user interactions
//

import XCTest

final class ThreadingSafetyUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Enable thread sanitizer in test
        app.launchArguments = [
            "-com.apple.CoreData.ConcurrencyDebug", "1",
            "-com.apple.CoreData.ThreadingDebug", "1"
        ]
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Recording Flow Tests
    
    func testRecordingFlowThreadSafety() throws {
        // Navigate to conversation view
        let conversationTab = app.tabBars.buttons["Conversation"]
        XCTAssertTrue(conversationTab.waitForExistence(timeout: 5))
        conversationTab.tap()
        
        // Find record button
        let recordButton = app.buttons["Start Recording"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        
        // Rapid start/stop to test threading
        for _ in 0..<5 {
            recordButton.tap()
            
            // Wait for recording to start
            let stopButton = app.buttons["Stop Recording"]
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
        // Navigate to notes view
        let notesTab = app.tabBars.buttons["Notes"]
        XCTAssertTrue(notesTab.waitForExistence(timeout: 5))
        notesTab.tap()
        
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
        // Start recording
        let conversationTab = app.tabBars.buttons["Conversation"]
        conversationTab.tap()
        
        let recordButton = app.buttons["Start Recording"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.tap()
        
        // Wait for recording to start
        let stopButton = app.buttons["Stop Recording"]
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
        let tabs = ["Dashboard", "Conversation", "Notes", "Settings"]
        
        // Rapid tab switching
        for _ in 0..<10 {
            for tabName in tabs {
                let tab = app.tabBars.buttons[tabName]
                if tab.exists {
                    tab.tap()
                    // Don't wait - immediate switch
                }
            }
        }
        
        // Verify final state
        XCTAssertTrue(app.state == .runningForeground)
        
        // Verify we can still interact
        let firstTab = app.tabBars.buttons.firstMatch
        XCTAssertTrue(firstTab.exists)
        firstTab.tap()
    }
    
    // MARK: - Stress Tests
    
    func testConcurrentUIOperations() throws {
        // Navigate to notes
        let notesTab = app.tabBars.buttons["Notes"]
        notesTab.tap()
        
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
        // Start recording
        let conversationTab = app.tabBars.buttons["Conversation"]
        conversationTab.tap()
        
        let recordButton = app.buttons["Start Recording"]
        recordButton.tap()
        
        // Simulate memory pressure by rapidly creating/destroying UI elements
        for _ in 0..<20 {
            // Switch tabs rapidly
            app.tabBars.buttons["Notes"].tap()
            app.tabBars.buttons["Dashboard"].tap()
            app.tabBars.buttons["Conversation"].tap()
        }
        
        // Stop recording if still active
        let stopButton = app.buttons["Stop Recording"]
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
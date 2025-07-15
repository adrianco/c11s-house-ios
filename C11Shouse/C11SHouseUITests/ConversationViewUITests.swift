/*
 * CONTEXT & PURPOSE:
 * UI tests for the refactored ConversationView to ensure proper user interaction,
 * message display, voice/text input handling, and error scenarios.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Initial UI test implementation
 *   - Test message bubble display and scrolling
 *   - Test mute/unmute functionality
 *   - Test text and voice input modes
 *   - Test error display scenarios
 *   - Test address suggestion interactions
 *
 * FUTURE UPDATES:
 * - Add performance tests for large message lists
 * - Test VoiceOver accessibility
 * - Add tests for landscape orientation
 */

import XCTest

class ConversationViewUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
        
        // Navigate to ConversationView
        navigateToConversationView()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testBackButtonNavigation() {
        // Given
        let backButton = app.buttons["Back"]
        
        // Then
        XCTAssertTrue(backButton.exists, "Back button should be visible")
        
        // When
        backButton.tap()
        
        // Then - should navigate back
        XCTAssertFalse(app.staticTexts["House Chat"].exists, "Should have navigated away from conversation view")
    }
    
    // MARK: - Message Display Tests
    
    func testInitialWelcomeMessage() {
        // Then
        let welcomeMessage = app.staticTexts["Hello! I'm your house consciousness. How can I help you today?"]
        XCTAssertTrue(welcomeMessage.waitForExistence(timeout: 5), "Welcome message should be displayed")
    }
    
    func testMessageBubbleDisplay() {
        // Given
        sendTextMessage("Hello house")
        
        // Then
        let userMessage = app.staticTexts["Hello house"]
        XCTAssertTrue(userMessage.exists, "User message should be displayed")
        
        // Wait for house response
        let houseResponse = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Let me think")).firstMatch
        XCTAssertTrue(houseResponse.waitForExistence(timeout: 10), "House response should appear")
    }
    
    func testMessageTimestamps() {
        // Given
        sendTextMessage("Test message")
        
        // Then - check for timestamp format (e.g., "2:30 PM")
        let timestampPredicate = NSPredicate(format: "label MATCHES %@", "\\d{1,2}:\\d{2} [AP]M")
        let timestamps = app.staticTexts.matching(timestampPredicate)
        XCTAssertGreaterThan(timestamps.count, 0, "Timestamps should be displayed for messages")
    }
    
    // MARK: - Mute Toggle Tests
    
    func testMuteToggle() {
        // Given
        let muteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "speaker")).firstMatch
        XCTAssertTrue(muteButton.exists, "Mute button should exist")
        
        // Initially should show unmuted state
        XCTAssertTrue(app.buttons["speaker.wave.2.fill"].exists || muteButton.label.contains("wave"), "Should start unmuted")
        
        // When - tap to mute
        muteButton.tap()
        
        // Then - should show muted state and text input
        XCTAssertTrue(app.buttons["speaker.slash.fill"].exists || muteButton.label.contains("slash"), "Should show muted state")
        XCTAssertTrue(app.textFields["Type a message..."].exists, "Text input should appear when muted")
        
        // When - tap to unmute
        muteButton.tap()
        
        // Then - should show unmuted state and voice input
        XCTAssertTrue(app.buttons["speaker.wave.2.fill"].exists || muteButton.label.contains("wave"), "Should show unmuted state")
        XCTAssertTrue(app.buttons["mic.circle.fill"].exists, "Voice input button should appear when unmuted")
    }
    
    // MARK: - Text Input Tests
    
    func testTextMessageSending() {
        // Given - mute to enable text input
        muteConversation()
        
        let textField = app.textFields["Type a message..."]
        let sendButton = app.buttons["arrow.up.circle.fill"]
        
        // Initially send button should be disabled
        XCTAssertFalse(sendButton.isEnabled, "Send button should be disabled when text field is empty")
        
        // When
        textField.tap()
        textField.typeText("Hello from UI test")
        
        // Then
        XCTAssertTrue(sendButton.isEnabled, "Send button should be enabled when text is entered")
        
        // When
        sendButton.tap()
        
        // Then
        XCTAssertTrue(app.staticTexts["Hello from UI test"].exists, "Sent message should appear in chat")
        XCTAssertEqual(textField.value as? String, "", "Text field should be cleared after sending")
    }
    
    func testTextMessageKeyboardSubmit() {
        // Given
        muteConversation()
        let textField = app.textFields["Type a message..."]
        
        // When
        textField.tap()
        textField.typeText("Keyboard submit test\n")
        
        // Then
        XCTAssertTrue(app.staticTexts["Keyboard submit test"].exists, "Message should be sent via keyboard")
    }
    
    // MARK: - Voice Input Tests
    
    func testVoiceInputButton() {
        // Given - ensure unmuted
        unmuteConversation()
        
        // Then
        let micButton = app.buttons["mic.circle.fill"]
        XCTAssertTrue(micButton.exists, "Microphone button should be visible when unmuted")
        XCTAssertTrue(app.staticTexts["Tap to speak"].exists, "Voice prompt should be visible")
        
        // When
        micButton.tap()
        
        // Then
        XCTAssertTrue(app.buttons["stop.circle.fill"].exists, "Stop button should appear when recording")
        XCTAssertTrue(app.staticTexts["Recording..."].exists, "Recording indicator should be visible")
    }
    
    func testVoiceTranscriptDisplay() {
        // This test would require mocking voice input
        // For now, we'll test the UI elements exist
        unmuteConversation()
        
        let micButton = app.buttons["mic.circle.fill"]
        XCTAssertTrue(micButton.exists, "Microphone button should exist")
        
        // The live transcript area should be ready
        // This would show the live transcript during recording
    }
    
    // MARK: - Question and Answer Tests
    
    func testAddressQuestionDisplay() {
        // Simulate address question appearing
        // In real app, this would come from QuestionFlowCoordinator
        
        // Check for address question format
        let addressQuestions = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Is this the right address?"))
        if addressQuestions.count > 0 {
            // Should have address display below question
            let addressText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "123")).firstMatch
            XCTAssertTrue(addressText.exists, "Address should be displayed with question")
        }
    }
    
    // MARK: - Error Display Tests
    
    func testErrorOverlayDisplay() {
        // Trigger an error condition (would need to be simulated in test mode)
        // For now, we'll verify the UI can handle error display
        
        // Check if error overlay container exists in view hierarchy
        let errorOverlay = app.otherElements["error-overlay"]
        // This would appear when an error occurs
        
        // Verify dismiss button would work
        if errorOverlay.exists {
            let dismissButton = errorOverlay.buttons["xmark.circle.fill"]
            XCTAssertTrue(dismissButton.exists, "Error should have dismiss button")
        }
    }
    
    // MARK: - Scrolling Tests
    
    func testMessageListScrolling() {
        // Send multiple messages to create scrollable content
        muteConversation()
        
        for i in 1...10 {
            sendTextMessage("Test message \(i)")
        }
        
        // Verify we can scroll
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists, "Message list should be scrollable")
        
        // Swipe up to scroll
        scrollView.swipeUp()
        
        // Should still see latest message (auto-scroll to bottom)
        XCTAssertTrue(app.staticTexts["Test message 10"].exists, "Should auto-scroll to show latest message")
    }
    
    // MARK: - Room Note Tests
    
    func testRoomNoteCreation() {
        // Given
        muteConversation()
        sendTextMessage("new room note")
        
        // Then - should see room note prompt
        let roomPrompt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "What room would you like to add")).firstMatch
        XCTAssertTrue(roomPrompt.waitForExistence(timeout: 5), "Room note prompt should appear")
        
        // When - provide room name
        sendTextMessage("Living Room")
        
        // Then - should ask for details
        let detailsPrompt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "What would you like me to remember")).firstMatch
        XCTAssertTrue(detailsPrompt.waitForExistence(timeout: 5), "Should ask for room details")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToConversationView() {
        // Navigate from main screen to conversation view
        // This depends on your app's navigation structure
        let conversationButton = app.buttons["Start Conversation"].firstMatch
        if conversationButton.waitForExistence(timeout: 5) {
            conversationButton.tap()
        } else {
            // Alternative navigation path
            let houseButton = app.buttons["House"].firstMatch
            if houseButton.exists {
                houseButton.tap()
            }
        }
        
        // Wait for conversation view to load
        XCTAssertTrue(app.staticTexts["House Chat"].waitForExistence(timeout: 5), "Conversation view should load")
    }
    
    private func muteConversation() {
        let muteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "speaker")).firstMatch
        if muteButton.exists && (app.buttons["speaker.wave.2.fill"].exists || muteButton.label.contains("wave")) {
            muteButton.tap()
        }
        // Wait for text input to appear
        _ = app.textFields["Type a message..."].waitForExistence(timeout: 2)
    }
    
    private func unmuteConversation() {
        let muteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "speaker")).firstMatch
        if muteButton.exists && (app.buttons["speaker.slash.fill"].exists || muteButton.label.contains("slash")) {
            muteButton.tap()
        }
        // Wait for voice input to appear
        _ = app.buttons["mic.circle.fill"].waitForExistence(timeout: 2)
    }
    
    private func sendTextMessage(_ text: String) {
        muteConversation()
        let textField = app.textFields["Type a message..."]
        textField.tap()
        textField.typeText(text)
        app.buttons["arrow.up.circle.fill"].tap()
        
        // Wait for message to appear
        _ = app.staticTexts[text].waitForExistence(timeout: 2)
    }
}

// MARK: - Performance Tests

extension ConversationViewUITests {
    func testScrollingPerformance() {
        // Given - create many messages
        muteConversation()
        
        measure {
            // Send 20 messages
            for i in 1...20 {
                sendTextMessage("Performance test message \(i)")
            }
            
            // Scroll up and down
            let scrollView = app.scrollViews.firstMatch
            scrollView.swipeUp()
            scrollView.swipeUp()
            scrollView.swipeDown()
            scrollView.swipeDown()
        }
    }
    
    func testMessageInputPerformance() {
        muteConversation()
        
        measure {
            let textField = app.textFields["Type a message..."]
            
            // Type and send 10 messages
            for i in 1...10 {
                textField.tap()
                textField.typeText("Perf test \(i)")
                app.buttons["arrow.up.circle.fill"].tap()
                
                // Small delay to let UI update
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
}
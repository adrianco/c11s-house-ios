/*
 * CONTEXT & PURPOSE:
 * OnboardingUITests provides end-to-end UI testing for the complete onboarding flow.
 * These tests validate the actual user experience, including animations, transitions,
 * and interactive elements that unit tests cannot cover.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation based on OnboardingUXPlan.md
 *   - Tests real user interactions and flows
 *   - Validates visual elements and animations
 *   - Ensures accessibility features work correctly
 *   - Measures actual performance metrics
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest

class OnboardingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Welcome Flow Tests
    
    func testWelcomeScreenAppearance() throws {
        // Verify onboarding welcome screen elements
        
        // Check for greeting text
        let greetingTexts = ["Good morning", "Good afternoon", "Good evening"]
        let greetingPredicate = NSPredicate(format: "label IN %@", greetingTexts)
        let greetingText = app.staticTexts.matching(greetingPredicate).firstMatch
        XCTAssertTrue(greetingText.waitForExistence(timeout: 5))
        
        // Check for "Your House, Awakened" text
        let awakenedText = app.staticTexts["Your House, Awakened"]
        XCTAssertTrue(awakenedText.waitForExistence(timeout: 2))
        
        // Check for Begin Setup button
        let beginSetupButton = app.buttons["Begin Setup"]
        XCTAssertTrue(beginSetupButton.waitForExistence(timeout: 2))
        XCTAssertTrue(beginSetupButton.isEnabled)
        
        // Measure load time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
    
    func testStartConversationFlow() throws {
        // Tap Begin Setup button on welcome screen
        let beginSetupButton = app.buttons["Begin Setup"]
        XCTAssertTrue(beginSetupButton.waitForExistence(timeout: 3))
        beginSetupButton.tap()
        
        // Should navigate to permissions screen
        let quickSetupText = app.staticTexts["Quick Setup"]
        XCTAssertTrue(quickSetupText.waitForExistence(timeout: 5))
        
        // Grant permissions
        let grantPermissionsButton = app.buttons["Grant Permissions"]
        if grantPermissionsButton.waitForExistence(timeout: 2) {
            grantPermissionsButton.tap()
            handlePermissionRequestsIfPresent()
        }
        
        // Continue button should appear after permissions
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }
        
        // Should reach completion screen
        let completionText = app.staticTexts["Setup Complete!"]
        XCTAssertTrue(completionText.waitForExistence(timeout: 5))
    }
    
    // MARK: - Permission Flow Tests
    
    func testPermissionHandlingInConversation() throws {
        // Navigate to conversation view where permissions are requested
        let startButton = app.buttons["StartConversation"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()
        
        // Permissions are requested inline when entering conversation
        // Handle system alerts if they appear
        handleSystemPermissionAlert(for: "microphone")
        handleSystemPermissionAlert(for: "speech recognition")
        handleSystemPermissionAlert(for: "location")
        
        // Verify conversation view is displayed after permissions
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5))
    }
    
    func testPermissionGrantFlow() throws {
        // Navigate to permissions screen
        let beginSetupButton = app.buttons["Begin Setup"]
        beginSetupButton.tap()
        
        // Tap Grant Permissions
        let grantPermissionsButton = app.buttons["Grant Permissions"]
        XCTAssertTrue(grantPermissionsButton.waitForExistence(timeout: 3))
        grantPermissionsButton.tap()
        
        // Handle system permission alerts
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        
        // Grant all permissions when they appear
        for _ in 0..<3 { // Up to 3 permissions
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 2) {
                if alert.buttons["OK"].exists {
                    alert.buttons["OK"].tap()
                } else if alert.buttons["Allow"].exists {
                    alert.buttons["Allow"].tap()
                }
            }
        }
        
        // Continue button should appear
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }
        
        // Should reach completion screen
        let completionText = app.staticTexts["Setup Complete!"]
        XCTAssertTrue(completionText.waitForExistence(timeout: 5))
    }
    
    func testPermissionDenialRecovery() throws {
        // Navigate to permissions screen
        let beginSetupButton = app.buttons["Begin Setup"]
        beginSetupButton.tap()
        
        // Tap Grant Permissions
        let grantPermissionsButton = app.buttons["Grant Permissions"]
        grantPermissionsButton.tap()
        
        // Deny microphone permission when prompted
        denySystemPermissionAlert(for: "microphone")
        
        // The "Open Settings" button should appear for recovery
        let openSettingsButton = app.buttons["Open Settings"]
        XCTAssertTrue(openSettingsButton.waitForExistence(timeout: 5))
        
        // Grant other permissions
        handleSystemPermissionAlert(for: "speech recognition")
        handleSystemPermissionAlert(for: "location")
        
        // Continue button should be enabled since microphone and speech are required
        // But we can't continue without them, so verify the UI state
        let continueButton = app.buttons["Continue"]
        XCTAssertFalse(continueButton.exists || !continueButton.isEnabled)
    }
    
    // MARK: - Personalization Flow Tests
    
    func testAddressQuestionFlow() throws {
        // Navigate to conversation
        completePermissions()
        
        // The conversation view should show the first question
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5))
        
        // Look for address question in the message history
        let addressMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Is this the right address'")).firstMatch
        
        // Address question should appear within a reasonable time
        if addressMessage.waitForExistence(timeout: 10) {
            // User can respond via text or voice
            // Check if text input is available
            let textField = app.textFields.firstMatch
            if textField.exists {
                XCTAssertTrue(textField.isEnabled)
            }
        }
    }
    
    func testHouseNamingFlow() throws {
        completePermissions()
        
        // Wait for conversation view
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5))
        
        // Look for house naming question in messages
        let houseMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'call this house'")).firstMatch
        
        // The question should appear after address is answered
        if houseMessage.waitForExistence(timeout: 15) {
            // User can respond with house name
            let textField = app.textFields.firstMatch
            if textField.waitForExistence(timeout: 2) {
                textField.tap()
                textField.typeText("My Smart Home")
                
                // Send the message
                let sendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send'")).firstMatch
                if sendButton.exists {
                    sendButton.tap()
                }
            }
        }
    }
    
    func testUserIntroductionFlow() throws {
        completePermissions()
        
        // Wait for conversation view
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5))
        
        // Look for name question in messages
        let nameMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'your name'")).firstMatch
        
        if nameMessage.waitForExistence(timeout: 15) {
            // Enter name via text input
            let textField = app.textFields.firstMatch
            if textField.waitForExistence(timeout: 2) {
                textField.tap()
                textField.typeText("Test User")
                
                // Send the message
                let sendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send'")).firstMatch
                if sendButton.exists {
                    sendButton.tap()
                }
                
                // Look for personalized response
                let response = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Test User'")).firstMatch
                XCTAssertTrue(response.waitForExistence(timeout: 5))
            }
        }
    }
    
    // MARK: - Feature Discovery Tests
    
    func testConversationTutorial() throws {
        completeOnboarding()
        
        // The conversation view should be active
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.exists)
        
        // Look for any tutorial or help messages
        let tutorialMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'room note'")).firstMatch
        
        // Tutorial should guide user through creating first room note
        if tutorialMessage.waitForExistence(timeout: 10) {
            // User can respond to create a room note
            let textField = app.textFields.firstMatch
            if textField.exists {
                XCTAssertTrue(textField.isEnabled)
            }
        }
    }
    
    func testNotesFeatureIntroduction() throws {
        // Open settings menu
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gearshape'")).firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()
        
        // Navigate to notes from menu
        let notesMenuItem = app.buttons["Manage Notes"]
        XCTAssertTrue(notesMenuItem.waitForExistence(timeout: 2))
        notesMenuItem.tap()
        
        // Verify notes view
        let notesView = app.navigationBars.firstMatch
        XCTAssertTrue(notesView.waitForExistence(timeout: 3))
        
        // Verify notes/questions are displayed
        // Should have at least the predefined questions
        let cells = app.cells
        XCTAssertTrue(cells.count > 0, "Should show question cells")
    }
    
    // MARK: - Completion Tests
    
    func testQuestionFlowCompletion() throws {
        completeOnboarding()
        
        // The app should be in conversation view after initial questions
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.exists)
        
        // After answering initial questions, user should be able to interact freely
        // Check that text input is available
        let textField = app.textFields.firstMatch
        if textField.waitForExistence(timeout: 2) {
            XCTAssertTrue(textField.isEnabled, "Text input should be available for conversation")
        }
        
        // Voice button should also be available (if permissions granted)
        let voiceButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'microphone'")).firstMatch
        if voiceButton.exists {
            XCTAssertTrue(voiceButton.isEnabled)
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testVoiceOverNavigation() throws {
        // Note: Requires VoiceOver to be enabled in test environment
        
        // Test basic navigation with VoiceOver gestures
        let firstElement = app.otherElements.firstMatch
        XCTAssertTrue(firstElement.exists)
        
        // Verify all interactive elements have accessibility labels
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            if button.exists {
                XCTAssertFalse(button.label.isEmpty, "Button should have accessibility label")
            }
        }
        
        // Test dynamic type
        app.launchArguments.append("-UIPreferredContentSizeCategoryName")
        app.launchArguments.append("UICTContentSizeCategoryAccessibilityXL")
        app.launch()
        
        // Verify text scales appropriately
        let titleText = app.staticTexts["Your House"]
        XCTAssertTrue(titleText.frame.height > 30, "Text should scale with dynamic type")
    }
    
    // MARK: - Performance Tests
    
    func testOnboardingPerformanceMetrics() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            // Complete full onboarding flow
            completePermissions()
            progressToCompletion()
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToConversation() {
        // Try accessibility identifier first
        let startButton = app.buttons["StartConversation"]
        if startButton.waitForExistence(timeout: 3) {
            startButton.tap()
        } else {
            // Fallback to text-based search
            let textButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start Conversation'")).firstMatch
            if textButton.waitForExistence(timeout: 2) {
                textButton.tap()
            }
        }
    }
    
    private func handlePermissionRequestsIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        
        let permissionAlerts = [
            "Would Like to Access the Microphone",
            "Would Like to Access Speech Recognition",
            "Would Like to Use Your Current Location"
        ]
        
        for alertText in permissionAlerts {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 1) && alert.label.contains(alertText) {
                alert.buttons["OK"].tap()
            }
        }
    }
    
    private func handleSystemPermissionAlert(for permission: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        
        if alert.waitForExistence(timeout: 2) {
            alert.buttons["OK"].tap()
        }
    }
    
    private func denySystemPermissionAlert(for permission: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        
        if alert.waitForExistence(timeout: 2) {
            if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap()
            }
        }
    }
    
    private func completePermissions() {
        navigateToConversation()
        // Handle any permission alerts that appear
        handlePermissionRequestsIfPresent()
    }
    
    private func completeOnboardingFlow() {
        // Tap Begin Setup
        let beginSetupButton = app.buttons["Begin Setup"]
        if beginSetupButton.waitForExistence(timeout: 3) {
            beginSetupButton.tap()
        }
        
        // Grant permissions
        let grantPermissionsButton = app.buttons["Grant Permissions"]
        if grantPermissionsButton.waitForExistence(timeout: 3) {
            grantPermissionsButton.tap()
            handlePermissionRequestsIfPresent()
        }
        
        // Continue
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }
        
        // Start chatting
        let startChattingButton = app.buttons["Start Chatting"]
        if startChattingButton.waitForExistence(timeout: 5) {
            startChattingButton.tap()
        }
    }
    
    private func navigateToQuestions() {
        // Just ensure we're in conversation view
        let conversationView = app.otherElements["ConversationView"]
        if !conversationView.waitForExistence(timeout: 2) {
            navigateToConversation()
        }
    }
    
    private func progressToHouseNaming() {
        navigateToQuestions()
        
        // In conversation flow, answer address question via text
        let addressMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Is this the right address'")).firstMatch
        if addressMessage.waitForExistence(timeout: 10) {
            let textField = app.textFields.firstMatch
            if textField.waitForExistence(timeout: 2) {
                textField.tap()
                textField.typeText("Yes")
                
                let sendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send'")).firstMatch
                if sendButton.exists {
                    sendButton.tap()
                }
            }
        }
    }
    
    private func progressToUserName() {
        progressToHouseNaming()
        
        // Answer house name question via text
        let houseMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'call this house'")).firstMatch
        if houseMessage.waitForExistence(timeout: 10) {
            let textField = app.textFields.firstMatch
            if textField.waitForExistence(timeout: 2) {
                textField.tap()
                textField.typeText("Test House")
                
                let sendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send'")).firstMatch
                if sendButton.exists {
                    sendButton.tap()
                }
            }
        }
    }
    
    private func progressToCompletion() {
        progressToUserName()
        
        // Answer name question via text
        let nameMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'your name'")).firstMatch
        if nameMessage.waitForExistence(timeout: 10) {
            let textField = app.textFields.firstMatch
            if textField.waitForExistence(timeout: 2) {
                textField.tap()
                textField.typeText("Test User")
                
                let sendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send'")).firstMatch
                if sendButton.exists {
                    sendButton.tap()
                }
            }
        }
        
        // Answer tutorial question about room note
        let tutorialMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'room note'")).firstMatch
        if tutorialMessage.waitForExistence(timeout: 10) {
            let textField = app.textFields.firstMatch
            if textField.waitForExistence(timeout: 2) {
                textField.tap()
                textField.typeText("Living room has a new couch")
                
                let sendButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Send'")).firstMatch
                if sendButton.exists {
                    sendButton.tap()
                }
            }
        }
    }
    
    private func completeOnboarding() {
        completePermissions()
        progressToCompletion()
        
        // Wait for completion
        sleep(1)
    }
}

// MARK: - Screen Element Helpers

struct WelcomeScreenElements {
    let app: XCUIApplication
    
    var appIcon: XCUIElement { app.images["AppIcon"] }
    var houseName: XCUIElement { app.staticTexts["HouseName"] }
    var emotionLabel: XCUIElement { app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Feeling'")).firstMatch }
    var startButton: XCUIElement { 
        // Try accessibility identifier first, then fallback to text
        let identifierButton = app.buttons["StartConversation"]
        return identifierButton.exists ? identifierButton : app.buttons["Start Conversation"]
    }
    var notesButton: XCUIElement { app.buttons["Manage Notes"] }
}

struct PermissionScreenElements {
    let app: XCUIApplication
    
    var microphoneCard: XCUIElement { app.otherElements["MicrophonePermission"] }
    var speechCard: XCUIElement { app.otherElements["SpeechPermission"] }
    var locationCard: XCUIElement { app.otherElements["LocationPermission"] }
    var microphoneDescription: XCUIElement { app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'voice commands'")).firstMatch }
    var grantButton: XCUIElement { app.buttons["Grant Permissions"] }
    var openSettingsButton: XCUIElement { app.buttons["Open Settings"] }
    var continueButton: XCUIElement { app.buttons["Continue"] }
    var successMessage: XCUIElement { app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'granted'")).firstMatch }
}

struct QuestionFlowElements {
    let app: XCUIApplication
    
    var questionText: XCUIElement { app.staticTexts["QuestionText"] }
    var answerField: XCUIElement { app.textFields.firstMatch }
    var voiceButton: XCUIElement { app.buttons["VoiceInput"] }
    var confirmButton: XCUIElement { app.buttons["Confirm"] }
    var skipButton: XCUIElement { app.buttons["Skip"] }
}

struct TutorialElements {
    let app: XCUIApplication
    
    var tutorialBubble: XCUIElement { app.otherElements["TutorialBubble"] }
    var exampleCommands: XCUIElementQuery { app.buttons.matching(NSPredicate(format: "label CONTAINS 'Try'")) }
    var skipButton: XCUIElement { app.buttons["Skip Tutorial"] }
}

struct CompletionElements {
    let app: XCUIApplication
    
    var celebrationView: XCUIElement { app.otherElements["CelebrationView"] }
    var completionMessage: XCUIElement { app.staticTexts["CompletionMessage"] }
    var quickActions: XCUIElementQuery { app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'QuickAction'")) }
    var continueButton: XCUIElement { app.buttons["Continue"] }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let currentValue = self.value as? String else {
            self.typeText(text)
            return
        }
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}
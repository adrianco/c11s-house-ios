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
        // Verify welcome screen elements
        let welcomeElements = WelcomeScreenElements(app: app)
        
        // Check app icon
        XCTAssertTrue(welcomeElements.appIcon.exists)
        XCTAssertTrue(welcomeElements.appIcon.isHittable)
        
        // Check house name
        XCTAssertTrue(welcomeElements.houseName.exists)
        XCTAssertEqual(welcomeElements.houseName.label, "Your House")
        
        // Check emotional state
        XCTAssertTrue(welcomeElements.emotionLabel.exists)
        XCTAssertTrue(welcomeElements.emotionLabel.label.contains("curious"))
        
        // Check call to action
        XCTAssertTrue(welcomeElements.startButton.exists)
        XCTAssertTrue(welcomeElements.startButton.isEnabled)
        
        // Measure load time
        measureMetrics([XCTApplicationLaunchMetric()], automaticallyStartMeasuring: false) {
            app.launch()
        }
    }
    
    func testStartConversationFlow() throws {
        let welcomeElements = WelcomeScreenElements(app: app)
        
        // Tap start conversation
        welcomeElements.startButton.tap()
        
        // Verify navigation to conversation view
        let conversationView = app.otherElements["ConversationView"]
        expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: conversationView)
        waitForExpectations(timeout: 2)
        
        // Check for permission request if needed
        handlePermissionRequestsIfPresent()
    }
    
    // MARK: - Permission Flow Tests
    
    func testPermissionEducationFlow() throws {
        navigateToPermissions()
        
        let permissionElements = PermissionScreenElements(app: app)
        
        // Verify education content
        XCTAssertTrue(permissionElements.microphoneCard.exists)
        XCTAssertTrue(permissionElements.speechCard.exists)
        XCTAssertTrue(permissionElements.locationCard.exists)
        
        // Check permission descriptions
        XCTAssertTrue(permissionElements.microphoneDescription.exists)
        XCTAssertTrue(permissionElements.microphoneDescription.label.contains("voice commands"))
        
        // Grant permissions button should be visible
        XCTAssertTrue(permissionElements.grantButton.exists)
        XCTAssertTrue(permissionElements.grantButton.isEnabled)
    }
    
    func testPermissionGrantFlow() throws {
        navigateToPermissions()
        
        let permissionElements = PermissionScreenElements(app: app)
        
        // Tap grant permissions
        permissionElements.grantButton.tap()
        
        // Handle system alerts
        handleSystemPermissionAlert(for: "microphone")
        handleSystemPermissionAlert(for: "speech recognition")
        handleSystemPermissionAlert(for: "location")
        
        // Verify success state
        expectation(for: NSPredicate(format: "label CONTAINS 'All permissions granted'"), 
                   evaluatedWith: permissionElements.successMessage)
        waitForExpectations(timeout: 5)
    }
    
    func testPermissionDenialRecovery() throws {
        navigateToPermissions()
        
        let permissionElements = PermissionScreenElements(app: app)
        permissionElements.grantButton.tap()
        
        // Deny microphone permission
        denySystemPermissionAlert(for: "microphone")
        
        // Verify error state and recovery option
        XCTAssertTrue(permissionElements.openSettingsButton.waitForExistence(timeout: 2))
        XCTAssertTrue(permissionElements.openSettingsButton.isEnabled)
        
        // Verify we can continue with limited functionality
        if permissionElements.continueButton.exists {
            XCTAssertTrue(permissionElements.continueButton.isEnabled)
        }
    }
    
    // MARK: - Personalization Flow Tests
    
    func testAddressDetectionFlow() throws {
        completePermissions()
        navigateToQuestions()
        
        let questionElements = QuestionFlowElements(app: app)
        
        // Wait for address detection
        expectation(for: NSPredicate(format: "label CONTAINS 'Is this the right address'"), 
                   evaluatedWith: questionElements.questionText)
        waitForExpectations(timeout: 5)
        
        // Verify pre-populated address
        XCTAssertTrue(questionElements.answerField.exists)
        XCTAssertFalse(questionElements.answerField.value as? String == "")
        
        // Confirm address
        questionElements.confirmButton.tap()
        
        // Verify progression
        expectation(for: NSPredicate(format: "label CONTAINS 'house'"), 
                   evaluatedWith: questionElements.questionText)
        waitForExpectations(timeout: 2)
    }
    
    func testHouseNamingFlow() throws {
        completePermissions()
        progressToHouseNaming()
        
        let questionElements = QuestionFlowElements(app: app)
        
        // Verify house naming question
        XCTAssertTrue(questionElements.questionText.label.contains("call this house"))
        
        // Check for suggested name
        let suggestedName = questionElements.answerField.value as? String ?? ""
        XCTAssertFalse(suggestedName.isEmpty, "Should have suggested name")
        
        // Enter custom name
        questionElements.answerField.tap()
        questionElements.answerField.clearAndTypeText("My Smart Home")
        
        // Save name
        questionElements.confirmButton.tap()
        
        // Verify name appears in UI
        let houseName = app.staticTexts["HouseName"]
        expectation(for: NSPredicate(format: "label == 'My Smart Home'"), 
                   evaluatedWith: houseName)
        waitForExpectations(timeout: 2)
    }
    
    func testUserIntroductionFlow() throws {
        completePermissions()
        progressToUserName()
        
        let questionElements = QuestionFlowElements(app: app)
        
        // Verify name question
        XCTAssertTrue(questionElements.questionText.label.contains("your name"))
        
        // Enter name
        questionElements.answerField.tap()
        questionElements.answerField.typeText("Test User")
        
        // Use voice input alternative
        if questionElements.voiceButton.exists {
            // Test voice input UI
            questionElements.voiceButton.tap()
            XCTAssertTrue(app.otherElements["RecordingIndicator"].exists)
            questionElements.voiceButton.tap() // Stop
        }
        
        // Save name
        questionElements.confirmButton.tap()
        
        // Verify personalized response
        expectation(for: NSPredicate(format: "label CONTAINS 'Test User'"), 
                   evaluatedWith: app.staticTexts.firstMatch)
        waitForExpectations(timeout: 2)
    }
    
    // MARK: - Feature Discovery Tests
    
    func testConversationTutorial() throws {
        completeOnboarding()
        
        // Look for tutorial elements
        let tutorialElements = TutorialElements(app: app)
        
        // Verify tutorial prompt
        XCTAssertTrue(tutorialElements.tutorialBubble.exists)
        XCTAssertTrue(tutorialElements.tutorialBubble.label.contains("Try saying"))
        
        // Test example command
        let exampleButton = tutorialElements.exampleCommands.firstMatch
        if exampleButton.exists {
            exampleButton.tap()
            
            // Verify command is populated
            let transcriptField = app.textViews["TranscriptField"]
            XCTAssertFalse(transcriptField.value as? String == "")
        }
        
        // Complete tutorial
        if tutorialElements.skipButton.exists {
            tutorialElements.skipButton.tap()
        }
    }
    
    func testNotesFeatureIntroduction() throws {
        completeOnboarding()
        
        // Navigate to notes
        let notesButton = app.buttons["Manage Notes"]
        XCTAssertTrue(notesButton.exists)
        notesButton.tap()
        
        // Verify notes view
        let notesView = app.navigationBars["Notes & Questions"]
        XCTAssertTrue(notesView.waitForExistence(timeout: 2))
        
        // Check for tutorial overlay
        let tutorialOverlay = app.otherElements["NotesTutorial"]
        if tutorialOverlay.exists {
            // Verify tutorial content
            XCTAssertTrue(app.staticTexts["Your notes stay private"].exists)
            
            // Dismiss tutorial
            app.buttons["Got it"].tap()
        }
        
        // Verify notes are displayed
        XCTAssertTrue(app.cells.count > 0, "Should show question cells")
    }
    
    // MARK: - Completion Tests
    
    func testOnboardingCompletionCelebration() throws {
        completeOnboarding()
        
        // Look for completion elements
        let completionElements = CompletionElements(app: app)
        
        // Verify celebration appears
        XCTAssertTrue(completionElements.celebrationView.waitForExistence(timeout: 2))
        
        // Check personalized message
        XCTAssertTrue(completionElements.completionMessage.exists)
        XCTAssertTrue(completionElements.completionMessage.label.contains("ready"))
        
        // Verify quick action suggestions
        XCTAssertTrue(completionElements.quickActions.count > 0)
        
        // Test dismissal
        if completionElements.continueButton.exists {
            completionElements.continueButton.tap()
            XCTAssertFalse(completionElements.celebrationView.exists)
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
    
    private func navigateToPermissions() {
        let startButton = app.buttons["Start Conversation"]
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
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
        navigateToPermissions()
        
        let grantButton = app.buttons["Grant Permissions"]
        if grantButton.waitForExistence(timeout: 2) {
            grantButton.tap()
            handlePermissionRequestsIfPresent()
        }
    }
    
    private func navigateToQuestions() {
        // Assumes permissions are granted
        let conversationView = app.otherElements["ConversationView"]
        if !conversationView.exists {
            app.buttons["Start Conversation"].tap()
        }
    }
    
    private func progressToHouseNaming() {
        navigateToQuestions()
        
        // Answer address question first
        let confirmButton = app.buttons["Confirm"]
        if confirmButton.waitForExistence(timeout: 3) {
            confirmButton.tap()
        }
    }
    
    private func progressToUserName() {
        progressToHouseNaming()
        
        // Answer house name question
        let confirmButton = app.buttons["Confirm"]
        if confirmButton.waitForExistence(timeout: 2) {
            confirmButton.tap()
        }
    }
    
    private func progressToCompletion() {
        progressToUserName()
        
        // Answer name question
        let answerField = app.textFields.firstMatch
        if answerField.waitForExistence(timeout: 2) {
            answerField.tap()
            answerField.typeText("Test User")
        }
        
        let confirmButton = app.buttons["Confirm"]
        if confirmButton.exists {
            confirmButton.tap()
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
    var startButton: XCUIElement { app.buttons["Start Conversation"] }
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
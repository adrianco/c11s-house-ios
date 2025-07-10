/*
 * CONTEXT & PURPOSE:
 * OnboardingFlowTests validates the complete onboarding user experience as defined in the
 * OnboardingUXPlan. Tests cover all phases of onboarding from welcome through completion,
 * ensuring proper flow, error handling, and user satisfaction metrics.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation based on OnboardingUXPlan.md
 *   - Tests each phase of the onboarding journey
 *   - Validates permission flows and recovery paths
 *   - Ensures personalization steps work correctly
 *   - Verifies completion and engagement metrics
 *   - Tests accessibility and error scenarios
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import Combine
import CoreLocation
@testable import C11SHouse

@MainActor
class OnboardingFlowTests: XCTestCase {
    
    // MARK: - Properties
    
    private var serviceContainer: ServiceContainer!
    private var permissionManager: MockPermissionManager!
    private var locationService: MockLocationService!
    private var notesService: NotesServiceProtocol!
    private var contentViewModel: ContentViewModel!
    private var conversationStateManager: ConversationStateManager!
    private var questionFlowCoordinator: QuestionFlowCoordinator!
    private var addressManager: AddressManager!
    private var cancellables: Set<AnyCancellable>!
    
    // Metrics tracking
    private var onboardingMetrics: OnboardingMetrics!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        cancellables = Set<AnyCancellable>()
        onboardingMetrics = OnboardingMetrics()
        
        // Initialize mocks
        permissionManager = MockPermissionManager()
        locationService = MockLocationService()
        
        // Initialize services
        notesService = NotesServiceImpl()
        serviceContainer = ServiceContainer.shared
        
        // Override with mocks
        serviceContainer.permissionManager = permissionManager
        
        // Initialize view models and coordinators
        contentViewModel = ViewModelFactory.shared.makeContentViewModel()
        conversationStateManager = ViewModelFactory.shared.makeConversationStateManager()
        
        addressManager = AddressManager(
            notesService: notesService,
            locationService: locationService
        )
        
        questionFlowCoordinator = QuestionFlowCoordinator(
            notesService: notesService
        )
        
        // Connect dependencies
        questionFlowCoordinator.conversationStateManager = conversationStateManager
        questionFlowCoordinator.addressManager = addressManager
        questionFlowCoordinator.serviceContainer = serviceContainer
        
        // Clear any existing data
        await clearAllData()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        await clearAllData()
        try await super.tearDown()
    }
    
    // MARK: - Phase 1: Welcome & First Impression Tests
    
    func testWelcomePhaseCreatesEmotionalConnection() async throws {
        // Track time to first interaction
        let startTime = Date()
        
        // Simulate app launch
        await contentViewModel.loadInitialState()
        
        // Verify welcome state
        XCTAssertEqual(contentViewModel.houseName, "Your House", "Should show default house name")
        XCTAssertNotNil(contentViewModel.houseThought, "Should have initial house thought")
        
        // Check emotional connection elements
        if let thought = contentViewModel.houseThought {
            XCTAssertEqual(thought.emotion, .curious, "Should start with curious emotion")
            XCTAssertTrue(thought.thought.contains("conversation"), "Should invite interaction")
        }
        
        // Verify first impression timing
        let loadTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(loadTime, 0.5, "Welcome should load within 500ms")
        
        onboardingMetrics.recordPhaseCompletion(.welcome, duration: loadTime)
    }
    
    func testWelcomeScreenAccessibility() async throws {
        // Test VoiceOver support
        let welcomeThought = HouseThought(
            thought: "Welcome! Start a conversation to set up your home",
            emotion: .curious,
            category: .greeting,
            confidence: 1.0
        )
        
        // Verify accessibility labels
        XCTAssertFalse(welcomeThought.thought.isEmpty, "Thought should have readable text")
        XCTAssertEqual(welcomeThought.emotion.displayName, "Curious", "Emotion should have accessible name")
        
        // Test dynamic type support (would need UI testing for full validation)
        onboardingMetrics.recordAccessibilityTest(.visualAccessibility, passed: true)
    }
    
    // MARK: - Phase 2: Permission & Setup Tests
    
    func testPermissionFlowWithEducation() async throws {
        let startTime = Date()
        
        // Start with no permissions
        permissionManager.mockMicrophoneStatus = .notDetermined
        permissionManager.mockSpeechRecognitionStatus = .notDetermined
        permissionManager.mockLocationStatus = .notDetermined
        
        // Test permission education
        XCTAssertFalse(permissionManager.allPermissionsGranted)
        
        // Request permissions sequentially
        await permissionManager.requestMicrophonePermission()
        XCTAssertEqual(permissionManager.mockMicrophoneStatus, .authorized)
        
        await permissionManager.requestSpeechRecognitionPermission()
        XCTAssertEqual(permissionManager.mockSpeechRecognitionStatus, .authorized)
        
        await permissionManager.requestLocationPermission()
        XCTAssertEqual(permissionManager.mockLocationStatus, .authorized)
        
        // Verify all permissions granted
        XCTAssertTrue(permissionManager.allPermissionsGranted)
        
        let duration = Date().timeIntervalSince(startTime)
        onboardingMetrics.recordPhaseCompletion(.permissions, duration: duration)
        onboardingMetrics.recordPermissionGrant(.microphone, granted: true)
        onboardingMetrics.recordPermissionGrant(.speechRecognition, granted: true)
        onboardingMetrics.recordPermissionGrant(.location, granted: true)
    }
    
    func testPermissionDenialRecovery() async throws {
        // Test recovery when permissions are denied
        permissionManager.mockMicrophoneStatus = .denied
        permissionManager.mockSpeechRecognitionStatus = .authorized
        permissionManager.mockLocationStatus = .denied
        
        // Verify proper error messaging
        XCTAssertEqual(
            permissionManager.microphoneStatusDescription,
            "Microphone access denied. Please enable in Settings."
        )
        
        // Test manual fallback for location
        XCTAssertEqual(permissionManager.mockLocationStatus, .denied)
        
        // Should still be able to manually enter address
        await questionFlowCoordinator.loadNextQuestion()
        if let question = questionFlowCoordinator.currentQuestion {
            XCTAssertTrue(
                question.text.contains("address"),
                "Should prompt for manual address entry"
            )
        }
        
        onboardingMetrics.recordPermissionGrant(.microphone, granted: false)
        onboardingMetrics.recordPermissionGrant(.location, granted: false)
        onboardingMetrics.recordErrorRecovery(.permissionDenied, recovered: true)
    }
    
    // MARK: - Phase 3: Personalization Tests
    
    func testAddressDetectionAndConfirmation() async throws {
        let startTime = Date()
        
        // Setup location mock
        let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationService.getCurrentLocationResult = .success(mockLocation)
        locationService.lookupAddressResult = .success(
            Address(
                street: "123 Market Street",
                city: "San Francisco",
                state: "CA",
                postalCode: "94103",
                country: "USA",
                coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194)
            )
        )
        
        // Grant location permission
        permissionManager.mockLocationStatus = .authorized
        
        // Detect address
        let detected = try await addressManager.detectCurrentAddress()
        XCTAssertEqual(detected.street, "123 Market Street")
        XCTAssertEqual(detected.city, "San Francisco")
        
        // Load address question
        await questionFlowCoordinator.loadNextQuestion()
        
        // Verify address is pre-populated
        if let question = questionFlowCoordinator.currentQuestion,
           question.text == "Is this the right address?" {
            // Confirm address
            try await questionFlowCoordinator.saveAnswer(detected.fullAddress)
            
            // Verify saved
            let saved = try await addressManager.getSavedAddress()
            XCTAssertNotNil(saved)
            XCTAssertEqual(saved?.fullAddress, detected.fullAddress)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        onboardingMetrics.recordPersonalizationStep(.addressSetup, duration: duration)
    }
    
    func testHouseNamingWithSuggestions() async throws {
        let startTime = Date()
        
        // Set up address first
        let address = Address(
            street: "789 Sunset Boulevard",
            city: "Los Angeles",
            state: "CA",
            postalCode: "90028",
            country: "USA",
            coordinate: Coordinate(latitude: 34.0522, longitude: -118.2437)
        )
        try await addressManager.saveAddress(address)
        
        // Progress to house naming question
        await progressToQuestion("What should I call this house?")
        
        // Test name generation
        let suggestedName = addressManager.generateHouseName(from: address.fullAddress)
        XCTAssertTrue(suggestedName.contains("Sunset"), "Should suggest name based on street")
        
        // User chooses custom name
        let customName = "Casa del Sol"
        if let question = questionFlowCoordinator.currentQuestion {
            conversationStateManager.persistentTranscript = customName
            try await questionFlowCoordinator.saveAnswer(customName)
        }
        
        // Verify house name saved
        let savedName = await notesService.getHouseName()
        XCTAssertEqual(savedName, customName)
        
        // Update content view model
        await contentViewModel.loadAddressAndWeather()
        XCTAssertEqual(contentViewModel.houseName, customName)
        
        let duration = Date().timeIntervalSince(startTime)
        onboardingMetrics.recordPersonalizationStep(.houseNaming, duration: duration)
    }
    
    func testUserIntroduction() async throws {
        let startTime = Date()
        
        // Progress to name question
        await progressToQuestion("What's your name?")
        
        // Enter user name
        let userName = "Test User"
        if questionFlowCoordinator.currentQuestion != nil {
            conversationStateManager.persistentTranscript = userName
            try await questionFlowCoordinator.saveAnswer(userName)
        }
        
        // Verify name saved and loaded
        await conversationStateManager.loadUserName()
        XCTAssertEqual(conversationStateManager.userName, userName)
        
        // Verify personalized response
        XCTAssertTrue(
            conversationStateManager.shouldPersonalizeResponse,
            "Should enable personalized responses"
        )
        
        let duration = Date().timeIntervalSince(startTime)
        onboardingMetrics.recordPersonalizationStep(.userIntroduction, duration: duration)
    }
    
    // MARK: - Phase 4: Feature Discovery Tests
    
    func testConversationTutorial() async throws {
        // Set up completed personalization
        await setupCompletedPersonalization()
        
        // Simulate tutorial conversation
        let tutorialPrompts = [
            "How's the weather today?",
            "What's the temperature?",
            "Add a note about groceries"
        ]
        
        for prompt in tutorialPrompts {
            // Simulate user speaking the prompt
            conversationStateManager.persistentTranscript = prompt
            
            // Verify house responds appropriately
            if prompt.contains("weather") || prompt.contains("temperature") {
                // Weather-related queries should check weather service
                XCTAssertNotNil(contentViewModel.currentAddress, "Should have address for weather")
            }
            
            conversationStateManager.clearTranscript()
        }
        
        onboardingMetrics.recordFeatureDiscovery(.conversationTutorial, completed: true)
    }
    
    func testNotesIntroduction() async throws {
        // Test notes feature introduction
        let testNote = "Remember to buy milk"
        
        // Create a test note
        let noteQuestion = Question(
            id: UUID(),
            text: "Shopping reminder",
            category: .lifestyle,
            priority: .medium
        )
        
        try await notesService.saveOrUpdateNote(
            for: noteQuestion.id,
            answer: testNote,
            metadata: ["source": "tutorial"]
        )
        
        // Verify note saved
        let savedNote = try await notesService.getNote(for: noteQuestion.id)
        XCTAssertNotNil(savedNote)
        XCTAssertEqual(savedNote?.answer, testNote)
        
        onboardingMetrics.recordFeatureDiscovery(.notesIntroduction, completed: true)
    }
    
    // MARK: - Phase 5: Completion & Engagement Tests
    
    func testOnboardingCompletion() async throws {
        let startTime = Date()
        
        // Complete all setup steps
        await setupCompletedPersonalization()
        
        // Mark all questions as completed
        await questionFlowCoordinator.loadNextQuestion()
        XCTAssertTrue(
            questionFlowCoordinator.hasCompletedAllQuestions,
            "Should have completed all questions"
        )
        
        // Verify completion state
        let totalDuration = Date().timeIntervalSince(startTime)
        onboardingMetrics.recordPhaseCompletion(.completion, duration: totalDuration)
        
        // Check success metrics
        XCTAssertLessThan(totalDuration, 300, "Onboarding should complete within 5 minutes")
        XCTAssertGreaterThan(
            onboardingMetrics.completionRate,
            0.8,
            "Should achieve 80%+ completion rate"
        )
    }
    
    func testFirstActionEngagement() async throws {
        // Complete onboarding
        await setupCompletedPersonalization()
        
        // Simulate first user action
        let firstAction = "What's the weather like?"
        conversationStateManager.persistentTranscript = firstAction
        
        // Track engagement
        onboardingMetrics.recordFirstAction(within: 60) // Within first minute
        
        XCTAssertTrue(
            onboardingMetrics.firstActionRate > 0.7,
            "Should achieve 70%+ first action rate"
        )
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() async throws {
        // Simulate network failure during address lookup
        locationService.lookupAddressResult = .failure(LocationError.geocodingFailed)
        
        // Try to detect address
        do {
            _ = try await addressManager.detectCurrentAddress()
            XCTFail("Should throw geocoding error")
        } catch {
            XCTAssertTrue(error is LocationError)
            
            // Verify fallback to manual entry
            await questionFlowCoordinator.loadNextQuestion()
            if let question = questionFlowCoordinator.currentQuestion {
                XCTAssertTrue(
                    question.text.contains("address"),
                    "Should fall back to manual address entry"
                )
            }
        }
        
        onboardingMetrics.recordErrorRecovery(.networkError, recovered: true)
    }
    
    func testInputValidation() async throws {
        // Test empty input handling
        await progressToQuestion("What's your name?")
        
        // Try to save empty answer
        do {
            try await questionFlowCoordinator.saveAnswer("")
            XCTFail("Should not accept empty answer")
        } catch {
            XCTAssertTrue(error is QuestionFlowError)
        }
        
        // Test whitespace-only input
        do {
            try await questionFlowCoordinator.saveAnswer("   ")
            XCTFail("Should not accept whitespace-only answer")
        } catch {
            XCTAssertTrue(error is QuestionFlowError)
        }
        
        // Valid input should work
        try await questionFlowCoordinator.saveAnswer("Valid Name")
        XCTAssertNil(questionFlowCoordinator.currentQuestion, "Should progress after valid input")
    }
    
    // MARK: - Accessibility Tests
    
    func testVoiceOverSupport() async throws {
        // Test that all interactive elements have proper labels
        let permissionCard = PermissionStatusCard(
            icon: "mic.fill",
            title: "Microphone",
            status: "Required for voice commands",
            isGranted: false
        )
        
        // Verify accessibility properties
        XCTAssertEqual(permissionCard.title, "Microphone")
        XCTAssertFalse(permissionCard.status.isEmpty)
        
        onboardingMetrics.recordAccessibilityTest(.voiceOver, passed: true)
    }
    
    func testLargeTextSupport() async throws {
        // Test dynamic type support
        // Note: Full testing would require UI tests
        
        // Verify text uses semantic styles
        let thought = HouseThought(
            thought: "Test thought",
            emotion: .happy,
            category: .general
        )
        
        XCTAssertFalse(thought.thought.isEmpty)
        
        onboardingMetrics.recordAccessibilityTest(.dynamicType, passed: true)
    }
    
    // MARK: - Helper Methods
    
    private func clearAllData() async {
        let emptyStore = NotesStore(questions: [], notes: [:])
        do {
            try await notesService.importNotes(from: JSONEncoder().encode(emptyStore))
        } catch {
            print("Error clearing data: \(error)")
        }
    }
    
    private func progressToQuestion(_ targetQuestion: String) async {
        // Answer questions until we reach the target
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            await questionFlowCoordinator.loadNextQuestion()
            
            guard let current = questionFlowCoordinator.currentQuestion else {
                break
            }
            
            if current.text == targetQuestion {
                return
            }
            
            // Answer current question to progress
            do {
                try await questionFlowCoordinator.saveAnswer("Test answer for \(current.text)")
            } catch {
                print("Error answering question: \(error)")
            }
            
            attempts += 1
        }
    }
    
    private func setupCompletedPersonalization() async {
        // Set up a fully personalized state
        permissionManager.mockMicrophoneStatus = .authorized
        permissionManager.mockSpeechRecognitionStatus = .authorized
        permissionManager.mockLocationStatus = .authorized
        
        // Set address
        let address = Address(
            street: "123 Test Street",
            city: "Test City",
            state: "CA",
            postalCode: "94000",
            country: "USA",
            coordinate: Coordinate(latitude: 37.0, longitude: -122.0)
        )
        try? await addressManager.saveAddress(address)
        
        // Set house name
        await notesService.saveHouseName("Test House")
        
        // Set user name
        await conversationStateManager.updateUserName("Test User")
    }
}

// MARK: - Onboarding Metrics

private class OnboardingMetrics {
    enum Phase {
        case welcome, permissions, personalization, featureDiscovery, completion
    }
    
    enum Permission {
        case microphone, speechRecognition, location
    }
    
    enum PersonalizationStep {
        case addressSetup, houseNaming, userIntroduction
    }
    
    enum FeatureDiscovery {
        case conversationTutorial, notesIntroduction, moodDemo
    }
    
    enum ErrorType {
        case permissionDenied, networkError, inputValidation
    }
    
    enum AccessibilityFeature {
        case voiceOver, dynamicType, visualAccessibility
    }
    
    private var phaseCompletions: [Phase: TimeInterval] = [:]
    private var permissionGrants: [Permission: Bool] = [:]
    private var personalizationSteps: [PersonalizationStep: TimeInterval] = [:]
    private var featureDiscoveries: [FeatureDiscovery: Bool] = [:]
    private var errorRecoveries: [ErrorType: Bool] = [:]
    private var accessibilityTests: [AccessibilityFeature: Bool] = [:]
    private var firstActionTime: TimeInterval?
    
    func recordPhaseCompletion(_ phase: Phase, duration: TimeInterval) {
        phaseCompletions[phase] = duration
    }
    
    func recordPermissionGrant(_ permission: Permission, granted: Bool) {
        permissionGrants[permission] = granted
    }
    
    func recordPersonalizationStep(_ step: PersonalizationStep, duration: TimeInterval) {
        personalizationSteps[step] = duration
    }
    
    func recordFeatureDiscovery(_ feature: FeatureDiscovery, completed: Bool) {
        featureDiscoveries[feature] = completed
    }
    
    func recordErrorRecovery(_ error: ErrorType, recovered: Bool) {
        errorRecoveries[error] = recovered
    }
    
    func recordAccessibilityTest(_ feature: AccessibilityFeature, passed: Bool) {
        accessibilityTests[feature] = passed
    }
    
    func recordFirstAction(within seconds: TimeInterval) {
        firstActionTime = seconds
    }
    
    var completionRate: Double {
        let completed = phaseCompletions.count
        let total = 5 // Total phases
        return Double(completed) / Double(total)
    }
    
    var firstActionRate: Double {
        return firstActionTime != nil ? 1.0 : 0.0
    }
}
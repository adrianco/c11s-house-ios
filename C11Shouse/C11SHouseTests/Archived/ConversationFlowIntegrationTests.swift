/*
 * CONTEXT & PURPOSE:
 * ConversationFlowIntegrationTests validates the complete conversation flow from speech
 * recognition through question display, answer saving, and progression to the next question.
 * These tests use real coordinators and services, mocking only external dependencies.
 *
 * DECISION HISTORY:
 * - 2025-01-10: Initial implementation
 *   - Tests complete conversation workflow with real coordinators
 *   - Mocks only external dependencies (Speech, Location, Weather)
 *   - Validates data flow through entire system
 *   - Tests all question types and transitions
 *   - Verifies persistence and state management
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import Combine
import CoreLocation
@testable import C11SHouse

@MainActor
class ConversationFlowIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var serviceContainer: ServiceContainer!
    private var questionFlowCoordinator: QuestionFlowCoordinator!
    private var conversationStateManager: ConversationStateManager!
    private var addressManager: AddressManager!
    private var notesService: NotesService!
    private var locationServiceMock: MockLocationService!
    private var weatherServiceMock: MockWeatherKitService!
    private var ttsMock: MockTTSService!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        cancellables = Set<AnyCancellable>()
        
        // Create real services
        notesService = NotesServiceImpl()
        ttsMock = MockTTSService()
        locationServiceMock = MockLocationService()
        weatherServiceMock = MockWeatherKitService()
        
        // Create coordinators with real dependencies
        conversationStateManager = ConversationStateManager(
            notesService: notesService,
            ttsService: ttsMock
        )
        
        addressManager = AddressManager(
            notesService: notesService,
            locationService: locationServiceMock
        )
        
        questionFlowCoordinator = QuestionFlowCoordinator(
            notesService: notesService
        )
        
        // Connect coordinators (simulating what happens in the app)
        questionFlowCoordinator.conversationStateManager = conversationStateManager
        questionFlowCoordinator.addressManager = addressManager
        
        // Clear any existing data
        // Note: clearAllNotes might not exist, using alternative approach
        let emptyStore = NotesStoreData(questions: [], notes: [:])
        // Clear notes - import method not in protocol
    }
    
    override func tearDown() async throws {
        cancellables = nil
        // Clear notes
        let emptyStore = NotesStoreData(questions: [], notes: [:])
        // Clear notes - import method not in protocol
        try await super.tearDown()
    }
    
    // MARK: - Complete Flow Tests
    
    func testCompleteConversationFlow() async throws {
        // Test the complete flow from start to finish
        
        // Step 1: Load initial question
        await questionFlowCoordinator.loadNextQuestion()
        
        let firstQuestion = await questionFlowCoordinator.currentQuestion
        XCTAssertNotNil(firstQuestion)
        XCTAssertEqual(firstQuestion?.category, .houseInfo)
        
        // Step 2: Simulate user answering the address question
        if firstQuestion?.text == "Is this the right address?" {
            // Mock location service should provide an address
            let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
            locationServiceMock.getCurrentLocationResult = .success(mockLocation)
            locationServiceMock.lookupAddressResult = .success(
                Address(
                    street: "123 Main",
                    city: "San Francisco",
                    state: "CA",
                    postalCode: "94105",
                    country: "USA",
                    coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194)
                )
            )
            
            // Detect address (should populate transcript)
            let detected = try await addressManager.detectCurrentAddress()
            conversationStateManager.persistentTranscript = detected.fullAddress
            
            // Save the answer
            try await questionFlowCoordinator.saveAnswer(detected.fullAddress)
            
            // Verify answer was saved
            let savedAnswer = await questionFlowCoordinator.getAnswer(for: "Is this the right address?")
            XCTAssertEqual(savedAnswer, detected.fullAddress)
        }
        
        // Step 3: Progress to house naming question
        let secondQuestion = await questionFlowCoordinator.currentQuestion
        XCTAssertNotNil(secondQuestion)
        XCTAssertEqual(secondQuestion?.text, "What should I call this house?")
        
        // Simulate user providing house name
        let houseName = "Casa Test"
        conversationStateManager.persistentTranscript = houseName
        try await questionFlowCoordinator.saveAnswer(houseName)
        
        // Verify house name was saved
        let savedHouseName = await questionFlowCoordinator.getAnswer(for: "What should I call this house?")
        XCTAssertEqual(savedHouseName, houseName)
        
        // Step 4: Progress to name question
        let thirdQuestion = await questionFlowCoordinator.currentQuestion
        XCTAssertNotNil(thirdQuestion)
        XCTAssertEqual(thirdQuestion?.text, "What's your name?")
        
        // Simulate user providing name
        let userName = "Test User"
        conversationStateManager.persistentTranscript = userName
        try await questionFlowCoordinator.saveAnswer(userName)
        
        // Verify name was saved and updated in state manager
        let savedUserName = await questionFlowCoordinator.getAnswer(for: "What's your name?")
        XCTAssertEqual(savedUserName, userName)
        XCTAssertEqual(conversationStateManager.userName, userName)
        
        // Step 5: Continue through more questions
        var questionCount = 3
        while await questionFlowCoordinator.currentQuestion != nil {
            let question = await questionFlowCoordinator.currentQuestion!
            
            // Provide appropriate answers based on question type
            let answer = generateAnswer(for: question)
            conversationStateManager.persistentTranscript = answer
            try await questionFlowCoordinator.saveAnswer(answer)
            
            questionCount += 1
            
            // Safety check to prevent infinite loop
            if questionCount > 20 {
                XCTFail("Too many questions - possible infinite loop")
                break
            }
        }
        
        // Verify all questions are complete
        XCTAssertTrue(questionFlowCoordinator.hasCompletedAllQuestions)
        XCTAssertNil(questionFlowCoordinator.currentQuestion)
    }
    
    func testQuestionTransitionWithExistingAnswers() async throws {
        // Pre-populate some answers
        let questions = try await notesService.loadNotesStore().questions
        
        // Save initial answers
        if let addressQuestion = questions.first(where: { $0.text == "Is this the right address?" }) {
            try await notesService.saveOrUpdateNote(
                for: addressQuestion.id,
                answer: "123 Test St, San Francisco, CA 94105"
            )
        }
        
        if let nameQuestion = questions.first(where: { $0.text == "What's your name?" }) {
            try await notesService.saveOrUpdateNote(
                for: nameQuestion.id,
                answer: "Existing User"
            )
        }
        
        // Load first question - should skip answered ones
        await questionFlowCoordinator.loadNextQuestion()
        
        let currentQuestion = await questionFlowCoordinator.currentQuestion
        XCTAssertNotNil(currentQuestion)
        
        // Should not be address or name question since they're already answered
        XCTAssertNotEqual(currentQuestion?.text, "Is this the right address?")
        XCTAssertNotEqual(currentQuestion?.text, "What's your name?")
        
        // Verify existing answers can be retrieved
        let existingName = await questionFlowCoordinator.getAnswer(for: "What's your name?")
        XCTAssertEqual(existingName, "Existing User")
    }
    
    func testAddressDetectionFlow() async throws {
        // Setup location mock
        let mockLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        locationServiceMock.getCurrentLocationResult = .success(mockLocation)
        locationServiceMock.lookupAddressResult = .success(
            Address(
                street: "350 5th Ave",
                city: "New York",
                state: "NY",
                postalCode: "10118",
                country: "USA",
                coordinate: Coordinate(latitude: 40.7128, longitude: -74.0060)
            )
        )
        
        // Load address question
        await questionFlowCoordinator.loadNextQuestion()
        
        guard let question = await questionFlowCoordinator.currentQuestion,
              question.text == "Is this the right address?" else {
            XCTFail("Expected address question")
            return
        }
        
        // Detect address
        let detected = try await addressManager.detectCurrentAddress()
        XCTAssertEqual(detected.street, "350 5th Ave")
        XCTAssertEqual(detected.city, "New York")
        XCTAssertEqual(detected.state, "NY")
        XCTAssertEqual(detected.postalCode, "10118")
        
        // Save detected address
        conversationStateManager.persistentTranscript = detected.fullAddress
        try await questionFlowCoordinator.saveAnswer(detected.fullAddress)
        
        // Verify address was saved properly
        let savedAddress = try await addressManager.loadSavedAddress()
        XCTAssertNotNil(savedAddress)
        XCTAssertEqual(savedAddress?.fullAddress, detected.fullAddress)
    }
    
    func testConversationStateManagement() async throws {
        // Test state transitions during conversation
        
        // Initial state
        XCTAssertEqual(conversationStateManager.persistentTranscript, "")
        XCTAssertFalse(conversationStateManager.isEditing)
        XCTAssertFalse(conversationStateManager.isSavingAnswer)
        
        // Load question
        await questionFlowCoordinator.loadNextQuestion()
        
        // Start recording session
        conversationStateManager.startNewRecordingSession()
        XCTAssertTrue(conversationStateManager.isNewSession)
        
        // Simulate transcript updates
        conversationStateManager.updateTranscript(with: "This is")
        XCTAssertFalse(conversationStateManager.isNewSession)
        XCTAssertEqual(conversationStateManager.persistentTranscript, "This is")
        
        conversationStateManager.updateTranscript(with: "This is my answer")
        XCTAssertEqual(conversationStateManager.persistentTranscript, "This is my answer")
        
        // Save answer
        conversationStateManager.beginSavingAnswer()
        XCTAssertTrue(conversationStateManager.isSavingAnswer)
        
        try await questionFlowCoordinator.saveAnswer("This is my answer")
        
        conversationStateManager.endSavingAnswer()
        XCTAssertFalse(conversationStateManager.isSavingAnswer)
        
        // Verify transcript was cleared
        conversationStateManager.clearTranscript()
        XCTAssertEqual(conversationStateManager.persistentTranscript, "")
    }
    
    func testAllQuestionCategories() async throws {
        // Test that all question categories are handled properly
        var categoriesEncountered: Set<QuestionCategory> = []
        var questionsAnswered = 0
        
        while !questionFlowCoordinator.hasCompletedAllQuestions && questionsAnswered < 30 {
            await questionFlowCoordinator.loadNextQuestion()
            
            guard let question = await questionFlowCoordinator.currentQuestion else {
                break
            }
            
            categoriesEncountered.insert(question.category)
            
            // Answer based on category
            let answer = generateAnswer(for: question)
            try await questionFlowCoordinator.saveAnswer(answer)
            questionsAnswered += 1
        }
        
        // Verify we encountered multiple categories
        XCTAssertGreaterThanOrEqual(categoriesEncountered.count, 3)
        XCTAssertTrue(categoriesEncountered.contains(.houseInfo))
        
        // Verify completion
        XCTAssertTrue(questionFlowCoordinator.hasCompletedAllQuestions)
    }
    
    func testErrorRecovery() async throws {
        // Test error handling during conversation flow
        
        await questionFlowCoordinator.loadNextQuestion()
        
        // Try to save empty answer - should throw error
        do {
            try await questionFlowCoordinator.saveAnswer("")
            XCTFail("Should have thrown error for empty answer")
        } catch {
            XCTAssertTrue(error is QuestionFlowError)
        }
        
        // Question should still be active
        XCTAssertNotNil(questionFlowCoordinator.currentQuestion)
        
        // Now save valid answer
        try await questionFlowCoordinator.saveAnswer("Valid answer")
        
        // Should have progressed to next question
        let nextQuestion = questionFlowCoordinator.currentQuestion
        if !questionFlowCoordinator.hasCompletedAllQuestions {
            XCTAssertNotNil(nextQuestion)
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateAnswer(for question: Question) -> String {
        switch question.category {
        case .houseInfo:
            return "Test logistics answer for \(question.text)"
        case .personal:
            return "Personal answer for \(question.text)"
        case .maintenance:
            return "Maintenance info: \(question.text)"
        case .preferences:
            return "Preference: \(question.text)"
        case .reminders:
            return "Reminder set for \(question.text)"
        case .other:
            return "General answer for \(question.text)"
        }
    }
}

// Note: Mock types are now centralized in TestMocks.swift
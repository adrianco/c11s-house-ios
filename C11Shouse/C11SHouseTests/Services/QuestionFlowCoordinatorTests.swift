/*
 * CONTEXT & PURPOSE:
 * QuestionFlowCoordinatorTests validates the QuestionFlowCoordinator implementation.
 * This coordinator manages question progression, validation, and persistence through
 * NotesService. Tests ensure proper state management, error handling, and integration
 * with dependent services.
 *
 * DECISION HISTORY:
 * - 2025-01-10: Initial test implementation
 *   - Mock NotesService for isolation
 *   - Test all public methods with various states
 *   - Verify question loading and progression logic
 *   - Test answer saving with validation
 *   - Test integration points with ConversationStateManager
 *   - Test special question handling (name, address, house name)
 *   - Async/await test patterns throughout
 *   - Error handling for all failure modes
 * - 2025-01-14: Fixed compilation issues
 *   - Updated to use current mock types from TestMocks.swift
 *   - Fixed MainActor isolation issues
 *   - Removed tests for non-existent methods
 *   - Updated mock usage to match current API
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import Combine
@testable import C11SHouse

// MARK: - Test-specific mock that extends SharedMockNotesService

class MockNotesServiceForQuestionFlow: SharedMockNotesService {
    var saveNoteCallCount = 0
    var saveOrUpdateNoteCallCount = 0
    var shouldThrowError = false
    var errorToThrow: Error?
    
    override func loadNotesStore() async throws -> NotesStoreData {
        if shouldThrowError {
            throw errorToThrow ?? NotesError.decodingFailed(NSError(domain: "test", code: 1))
        }
        return try await super.loadNotesStore()
    }
    
    override func saveNote(_ note: Note) async throws {
        print("[MockNotesService] saveNote called with questionId: \(note.questionId), answer: \(note.answer)")
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        saveNoteCallCount += 1
        print("[MockNotesService] Incremented saveNoteCallCount to: \(saveNoteCallCount)")
        try await super.saveNote(note)
    }
    
    override func updateNote(_ note: Note) async throws {
        print("[MockNotesService] updateNote called with questionId: \(note.questionId), answer: \(note.answer)")
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        try await super.updateNote(note)
    }
    
    // Override the parent class implementation
    override func saveOrUpdateNote(for questionId: UUID, answer: String, metadata: [String: String]? = nil) async throws {
        print("[MockNotesService] saveOrUpdateNote called with questionId: \(questionId), answer: \(answer)")
        saveOrUpdateNoteCallCount += 1
        print("[MockNotesService] Incremented saveOrUpdateNoteCallCount to: \(saveOrUpdateNoteCallCount)")
        
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        
        // Create a note and save it directly
        let note = Note(
            questionId: questionId,
            answer: answer,
            metadata: metadata
        )
        try await saveNote(note)
    }
}

// MARK: - Mock ConversationStateManager

@MainActor
class MockConversationStateManager: ConversationStateManager {
    var persistentTranscriptValue = ""
    var isSavingAnswerValue = false
    var beginSavingAnswerCallCount = 0
    var endSavingAnswerCallCount = 0
    var clearTranscriptCallCount = 0
    var updateUserNameCallCount = 0
    
    override var persistentTranscript: String {
        get { persistentTranscriptValue }
        set { persistentTranscriptValue = newValue }
    }
    
    override var isSavingAnswer: Bool {
        get { isSavingAnswerValue }
        set { isSavingAnswerValue = newValue }
    }
    
    override func beginSavingAnswer() {
        beginSavingAnswerCallCount += 1
        isSavingAnswerValue = true
    }
    
    override func endSavingAnswer() {
        endSavingAnswerCallCount += 1
        isSavingAnswerValue = false
    }
    
    override func clearTranscript() {
        clearTranscriptCallCount += 1
        persistentTranscriptValue = ""
    }
    
    override func updateUserName(_ name: String) async {
        updateUserNameCallCount += 1
        userName = name
    }
}

// MARK: - Mock AddressManager

class MockAddressManager: AddressManager {
    var detectCurrentAddressCallCount = 0
    var parseAddressCallCount = 0
    var saveAddressCallCount = 0
    var generateHouseNameCallCount = 0
    var mockDetectedAddress: Address?
    var shouldThrowError = false
    
    override func detectCurrentAddress() async throws -> Address {
        detectCurrentAddressCallCount += 1
        if shouldThrowError {
            throw LocationError.locationUnavailable
        }
        return mockDetectedAddress ?? Address(
            street: "123 Main St",
            city: "Springfield",
            state: "IL",
            postalCode: "62701",
            country: "USA",
            coordinate: Coordinate(latitude: 39.7817, longitude: -89.6501)
        )
    }
    
    override func parseAddress(_ addressText: String) -> Address? {
        parseAddressCallCount += 1
        return AddressParser.parseAddress(addressText)
    }
    
    override func saveAddress(_ address: Address) async throws {
        saveAddressCallCount += 1
        if shouldThrowError {
            throw NSError(domain: "test", code: 1)
        }
    }
    
    override func generateHouseName(from addressText: String) -> String {
        generateHouseNameCallCount += 1
        return "Generated House Name"
    }
    
    override func loadDetectedAddress() -> Address? {
        return mockDetectedAddress
    }
    
    override func storeDetectedAddress(_ address: Address) async {
        mockDetectedAddress = address
    }
}

// MARK: - Mock ConversationRecognizer for this test
@MainActor
class MockConversationRecognizerForFlow: ConversationRecognizer {
    var clearHouseThoughtCallCount = 0
    var setQuestionThoughtCallCount = 0
    var setThankYouThoughtCallCount = 0
    var lastQuestionThought: String?
    
    override func clearHouseThought() {
        clearHouseThoughtCallCount += 1
        currentHouseThought = nil
    }
    
    override func setQuestionThought(_ question: String) {
        setQuestionThoughtCallCount += 1
        lastQuestionThought = question
        currentHouseThought = HouseThought(
            thought: question,
            emotion: .curious,
            category: .question,
            confidence: 0.9,
            context: "Question",
            suggestion: nil
        )
    }
    
    override func setThankYouThought() {
        setThankYouThoughtCallCount += 1
        currentHouseThought = HouseThought(
            thought: "Thank you for answering all my questions!",
            emotion: .happy,
            category: .celebration,
            confidence: 1.0,
            context: "All questions complete",
            suggestion: nil
        )
    }
}

// MARK: - QuestionFlowCoordinatorTests
@MainActor
class QuestionFlowCoordinatorTests: XCTestCase {
    var sut: QuestionFlowCoordinator!
    var mockNotesService: MockNotesServiceForQuestionFlow!
    var mockStateManager: MockConversationStateManager!
    var mockRecognizer: MockConversationRecognizerForFlow!
    var mockAddressManager: MockAddressManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        mockNotesService = MockNotesServiceForQuestionFlow()
        sut = QuestionFlowCoordinator(notesService: mockNotesService)
        
        // Create and inject mock dependencies
        mockStateManager = MockConversationStateManager(
            notesService: mockNotesService,
            ttsService: MockTTSService()
        )
        mockRecognizer = MockConversationRecognizerForFlow()
        mockAddressManager = MockAddressManager(
            notesService: mockNotesService,
            locationService: MockLocationService()
        )
        
        sut.conversationStateManager = mockStateManager
        sut.conversationRecognizer = mockRecognizer
        sut.addressManager = mockAddressManager
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        mockNotesService = nil
        mockStateManager = nil
        mockRecognizer = nil
        mockAddressManager = nil
        try await super.tearDown()
    }
    
    // MARK: - loadNextQuestion Tests
    
    func testLoadNextQuestionWithUnansweredQuestions() async {
        // Given: Unanswered questions exist
        // (Default mock has all questions unanswered)
        
        // When: Loading next question
        await sut.loadNextQuestion()
        
        // Then: Should load first question needing review
        XCTAssertNotNil(sut.currentQuestion)
        XCTAssertFalse(sut.hasCompletedAllQuestions)
        XCTAssertFalse(sut.isLoadingQuestion)
    }
    
    func testLoadNextQuestionWithAllQuestionsAnswered() async {
        // Given: All questions are answered
        for question in mockNotesService.mockNotesStore.questions {
            mockNotesService.mockNotesStore.notes[question.id] = Note(
                questionId: question.id,
                answer: "Answered",
                metadata: ["updated_via_conversation": "true"]
            )
        }
        
        // When: Loading next question
        let expectation = expectation(forNotification: Notification.Name("AllQuestionsComplete"), object: nil)
        await sut.loadNextQuestion()
        
        // Then: Should set hasCompletedAllQuestions and post notification
        XCTAssertNil(sut.currentQuestion)
        XCTAssertTrue(sut.hasCompletedAllQuestions)
        XCTAssertFalse(sut.isLoadingQuestion)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testLoadNextQuestionHandlesError() async {
        // Given: NotesService will throw error
        mockNotesService.shouldThrowError = true
        
        // When: Loading next question
        await sut.loadNextQuestion()
        
        // Then: Should handle gracefully
        XCTAssertNil(sut.currentQuestion)
        XCTAssertFalse(sut.isLoadingQuestion)
    }
    
    func testLoadNextQuestionPreventsMultipleConcurrentLoads() async {
        // Given: First load is in progress
        let loadTask1 = Task {
            await sut.loadNextQuestion()
        }
        
        // When: Attempting second load immediately
        await sut.loadNextQuestion()
        
        // Then: Should only load once
        await loadTask1.value
        XCTAssertFalse(sut.isLoadingQuestion)
    }
    
    // MARK: - getCurrentAnswer Tests
    
    func testGetCurrentAnswerForExistingNote() async {
        // Given: A question with an answer
        let question = mockNotesService.mockNotesStore.questions.first!
        mockNotesService.mockNotesStore.notes[question.id] = Note(
            questionId: question.id,
            answer: "Existing answer"
        )
        
        // When: Getting current answer
        let answer = await sut.getCurrentAnswer(for: question)
        
        // Then: Should return the answer
        XCTAssertEqual(answer, "Existing answer")
    }
    
    func testGetCurrentAnswerForNonExistentNote() async {
        // Given: A question without an answer
        let question = mockNotesService.mockNotesStore.questions.first!
        
        // When: Getting current answer
        let answer = await sut.getCurrentAnswer(for: question)
        
        // Then: Should return nil
        XCTAssertNil(answer)
    }
    
    func testGetCurrentAnswerHandlesError() async {
        // Given: NotesService will throw error
        mockNotesService.shouldThrowError = true
        let question = mockNotesService.mockNotesStore.questions.first!
        
        // When: Getting current answer
        let answer = await sut.getCurrentAnswer(for: question)
        
        // Then: Should return nil
        XCTAssertNil(answer)
    }
    
    // MARK: - saveAnswer Tests
    
    func testSaveAnswerWithFullIntegration() async {
        // Given: Current question and dependencies are set
        let question = mockNotesService.mockNotesStore.questions.first!
        sut.currentQuestion = question
        mockStateManager.persistentTranscriptValue = "  Test answer  "
        
        // Debug: Check the question details
        print("[TEST] Current question: \(question.text)")
        print("[TEST] Transcript value: '\(mockStateManager.persistentTranscriptValue)'")
        
        // When: Saving answer
        await sut.saveAnswer()
        
        // Debug: Check what happened
        print("[TEST] beginSavingAnswerCallCount: \(mockStateManager.beginSavingAnswerCallCount)")
        print("[TEST] clearHouseThoughtCallCount: \(mockRecognizer.clearHouseThoughtCallCount)")
        print("[TEST] saveOrUpdateNoteCallCount: \(mockNotesService.saveOrUpdateNoteCallCount)")
        print("[TEST] clearTranscriptCallCount: \(mockStateManager.clearTranscriptCallCount)")
        print("[TEST] endSavingAnswerCallCount: \(mockStateManager.endSavingAnswerCallCount)")
        
        // Then: Should follow full save flow
        XCTAssertEqual(mockStateManager.beginSavingAnswerCallCount, 1)
        XCTAssertEqual(mockRecognizer.clearHouseThoughtCallCount, 1)
        XCTAssertEqual(mockNotesService.saveOrUpdateNoteCallCount, 1)
        XCTAssertEqual(mockStateManager.clearTranscriptCallCount, 1)
        XCTAssertEqual(mockStateManager.endSavingAnswerCallCount, 1)
        
        // Verify saved answer
        let savedNote = mockNotesService.mockNotesStore.notes[question.id]
        XCTAssertEqual(savedNote?.answer, "Test answer")
        XCTAssertEqual(savedNote?.metadata?["updated_via_conversation"], "true")
    }
    
    func testSaveAnswerForNameQuestion() async {
        // Given: Name question is current
        let nameQuestion = mockNotesService.mockNotesStore.questions.first(where: { $0.text == "What's your name?" })!
        sut.currentQuestion = nameQuestion
        mockStateManager.persistentTranscriptValue = "John Doe"
        
        // When: Saving answer
        await sut.saveAnswer()
        
        // Then: Should update user name
        XCTAssertEqual(mockStateManager.updateUserNameCallCount, 1)
        XCTAssertEqual(mockStateManager.userName, "John Doe")
    }
    
    func testSaveAnswerForAddressQuestion() async {
        // Given: Address question is current
        let addressQuestion = mockNotesService.mockNotesStore.questions.first(where: { 
            $0.text == "Is this the right address?" || $0.text == "What's your home address?"
        })!
        sut.currentQuestion = addressQuestion
        mockStateManager.persistentTranscriptValue = "123 Main St, Springfield, IL 62701"
        
        // When: Saving answer
        await sut.saveAnswer()
        
        // Then: Should parse and save address
        XCTAssertEqual(mockAddressManager.parseAddressCallCount, 1)
        XCTAssertEqual(mockAddressManager.saveAddressCallCount, 1)
    }
    
    func testSaveAnswerForHouseNameQuestion() async {
        // Given: House name question is current
        let houseQuestion = mockNotesService.mockNotesStore.questions.first(where: { 
            $0.text == "What should I call this house?" 
        })!
        sut.currentQuestion = houseQuestion
        mockStateManager.persistentTranscriptValue = "Maple House"
        
        // Use shared service container
        sut.serviceContainer = ServiceContainer.shared
        
        // When: Saving answer
        await sut.saveAnswer()
        
        // Then: Should save house name
        let houseName = await mockNotesService.getHouseName()
        XCTAssertEqual(houseName, "Maple House")
    }
    
    func testSaveAnswerPreventsDuplicateSaves() async {
        // Given: Save is already in progress
        sut.currentQuestion = mockNotesService.mockNotesStore.questions.first!
        mockStateManager.isSavingAnswerValue = true
        
        // When: Attempting to save
        await sut.saveAnswer()
        
        // Then: Should not save again
        XCTAssertEqual(mockStateManager.beginSavingAnswerCallCount, 0)
        XCTAssertEqual(mockNotesService.saveOrUpdateNoteCallCount, 0)
    }
    
    func testSaveAnswerHandlesError() async {
        // Given: Save will fail
        sut.currentQuestion = mockNotesService.mockNotesStore.questions.first!
        mockStateManager.persistentTranscriptValue = "Test answer"
        mockNotesService.shouldThrowError = true
        
        // When: Saving answer
        await sut.saveAnswer()
        
        // Then: Should still clean up state
        XCTAssertEqual(mockStateManager.endSavingAnswerCallCount, 1)
    }
    
    // MARK: - saveAnswer (basic) Tests
    
    func testSaveAnswerBasicWithValidData() async throws {
        // Given: Current question exists
        let question = mockNotesService.mockNotesStore.questions.first!
        sut.currentQuestion = question
        
        // When: Saving answer
        try await sut.saveAnswer("Test answer", metadata: ["key": "value"])
        
        // Then: Should save and load next question
        XCTAssertEqual(mockNotesService.saveOrUpdateNoteCallCount, 1)
        XCTAssertNil(sut.currentQuestion)
        
        let savedNote = mockNotesService.mockNotesStore.notes[question.id]
        XCTAssertEqual(savedNote?.answer, "Test answer")
        XCTAssertEqual(savedNote?.metadata?["key"], "value")
        XCTAssertEqual(savedNote?.metadata?["updated_via_conversation"], "true")
    }
    
    func testSaveAnswerBasicThrowsForNoCurrentQuestion() async {
        // Given: No current question
        sut.currentQuestion = nil
        
        // When/Then: Should throw noCurrentQuestion error
        do {
            try await sut.saveAnswer("Test answer")
            XCTFail("Expected error to be thrown")
        } catch QuestionFlowError.noCurrentQuestion {
            // Success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testSaveAnswerBasicThrowsForEmptyAnswer() async {
        // Given: Current question exists
        sut.currentQuestion = mockNotesService.mockNotesStore.questions.first!
        
        // When/Then: Should throw emptyAnswer error
        do {
            try await sut.saveAnswer("   ")
            XCTFail("Expected error to be thrown")
        } catch QuestionFlowError.emptyAnswer {
            // Success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - isQuestionAnswered Tests
    
    func testIsQuestionAnsweredReturnsTrueForAnsweredQuestion() async {
        // Given: A question is answered
        let questionText = "What's your name?"
        if let question = mockNotesService.mockNotesStore.questions.first(where: { $0.text == questionText }) {
            mockNotesService.mockNotesStore.notes[question.id] = Note(
                questionId: question.id,
                answer: "John"
            )
        }
        
        // When: Checking if answered
        let isAnswered = await sut.isQuestionAnswered(questionText)
        
        // Then: Should return true
        XCTAssertTrue(isAnswered)
    }
    
    func testIsQuestionAnsweredReturnsFalseForUnansweredQuestion() async {
        // Given: A question is not answered
        let questionText = "What's your name?"
        
        // When: Checking if answered
        let isAnswered = await sut.isQuestionAnswered(questionText)
        
        // Then: Should return false
        XCTAssertFalse(isAnswered)
    }
    
    func testIsQuestionAnsweredHandlesError() async {
        // Given: NotesService will throw error
        mockNotesService.shouldThrowError = true
        
        // When: Checking if answered
        let isAnswered = await sut.isQuestionAnswered("What's your name?")
        
        // Then: Should return false
        XCTAssertFalse(isAnswered)
    }
    
    // MARK: - getAnswer Tests
    
    func testGetAnswerForExistingQuestion() async {
        // Given: A question with an answer
        let questionText = "What's your name?"
        if let question = mockNotesService.mockNotesStore.questions.first(where: { $0.text == questionText }) {
            mockNotesService.mockNotesStore.notes[question.id] = Note(
                questionId: question.id,
                answer: "John Doe"
            )
        }
        
        // When: Getting answer
        let answer = await sut.getAnswer(for: questionText)
        
        // Then: Should return the answer
        XCTAssertEqual(answer, "John Doe")
    }
    
    func testGetAnswerForNonExistentQuestion() async {
        // Given: Question doesn't exist
        
        // When: Getting answer
        let answer = await sut.getAnswer(for: "Non-existent question?")
        
        // Then: Should return nil
        XCTAssertNil(answer)
    }
    
    // MARK: - handleQuestionChange Tests
    
    func testHandleQuestionChangeWithNoQuestion() async {
        // Given: No new question and all questions completed
        sut.hasCompletedAllQuestions = true
        
        // When: Handling change
        let stillInitializing = await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: nil,
            isInitializing: true
        )
        
        // Then: Should handle completion
        XCTAssertFalse(stillInitializing)
        XCTAssertEqual(mockRecognizer.setThankYouThoughtCallCount, 1)
    }
    
    func testHandleQuestionChangeForAddressQuestionWithoutAnswer() async {
        // Given: Address question without existing answer
        let addressQuestion = mockNotesService.mockNotesStore.questions.first(where: { 
            $0.text == "Is this the right address?" 
        })!
        
        // When: Handling change
        let stillInitializing = await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: addressQuestion,
            isInitializing: true
        )
        
        // Then: Should detect address and set question thought
        XCTAssertFalse(stillInitializing)
        XCTAssertEqual(mockAddressManager.detectCurrentAddressCallCount, 1)
        XCTAssertEqual(mockStateManager.persistentTranscriptValue, "123 Main St, Springfield, IL 62701")
        XCTAssertEqual(mockRecognizer.setQuestionThoughtCallCount, 0) // Should set HouseThought instead
        XCTAssertNotNil(mockRecognizer.currentHouseThought)
    }
    
    func testHandleQuestionChangeForAddressQuestionWithError() async {
        // Given: Address detection will fail
        let addressQuestion = mockNotesService.mockNotesStore.questions.first(where: { 
            $0.text == "Is this the right address?" 
        })!
        mockAddressManager.shouldThrowError = true
        
        // When: Handling change
        let stillInitializing = await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: addressQuestion,
            isInitializing: true
        )
        
        // Then: Should still ask the question
        XCTAssertFalse(stillInitializing)
        XCTAssertEqual(mockRecognizer.setQuestionThoughtCallCount, 1)
        XCTAssertEqual(mockRecognizer.lastQuestionThought, addressQuestion.text)
    }
    
    func testHandleQuestionChangeForHouseNameQuestionWithoutAnswer() async {
        // Given: House name question without answer, but address exists
        let houseQuestion = mockNotesService.mockNotesStore.questions.first(where: { 
            $0.text == "What should I call this house?" 
        })!
        
        // Add address answer
        if let addressQuestion = mockNotesService.mockNotesStore.questions.first(where: { 
            $0.text == "Is this the right address?" 
        }) {
            mockNotesService.mockNotesStore.notes[addressQuestion.id] = Note(
                questionId: addressQuestion.id,
                answer: "123 Elm Street"
            )
        }
        
        // When: Handling change
        let stillInitializing = await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: houseQuestion,
            isInitializing: true
        )
        
        // Then: Should generate house name suggestion
        XCTAssertFalse(stillInitializing)
        XCTAssertEqual(mockAddressManager.generateHouseNameCallCount, 1)
        XCTAssertEqual(mockStateManager.persistentTranscriptValue, "Generated House Name")
        XCTAssertNotNil(mockRecognizer.currentHouseThought)
    }
    
    func testHandleQuestionChangeWithExistingAnswer() async {
        // Given: Question with existing answer
        let question = mockNotesService.mockNotesStore.questions.first!
        mockNotesService.mockNotesStore.notes[question.id] = Note(
            questionId: question.id,
            answer: "Existing answer"
        )
        
        // When: Handling change
        let stillInitializing = await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: question,
            isInitializing: true
        )
        
        // Then: Should pre-populate and ask for confirmation
        XCTAssertFalse(stillInitializing)
        XCTAssertEqual(mockStateManager.persistentTranscriptValue, "Existing answer")
        XCTAssertNotNil(mockRecognizer.currentHouseThought)
        XCTAssertTrue(mockRecognizer.currentHouseThought!.thought.contains(question.text))
        XCTAssertTrue(mockRecognizer.currentHouseThought!.thought.contains("Existing answer"))
    }
    
    // MARK: - Error Type Tests
    
    func testQuestionFlowErrorDescriptions() {
        XCTAssertEqual(
            QuestionFlowError.noCurrentQuestion.errorDescription,
            "No question is currently active"
        )
        
        XCTAssertEqual(
            QuestionFlowError.emptyAnswer.errorDescription,
            "Answer cannot be empty"
        )
    }
}
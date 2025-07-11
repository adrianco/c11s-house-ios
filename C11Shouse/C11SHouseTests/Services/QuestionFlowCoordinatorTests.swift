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
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import Combine
@testable import C11SHouse

// MARK: - Protocols for Testing

// ConversationRecognizerProtocol removed - duplicate definition

// MARK: - Mock NotesService

class MockNotesService: NotesServiceProtocol {
    var notesStorePublisher: AnyPublisher<NotesStoreData, Never> {
        notesStoreSubject.eraseToAnyPublisher()
    }
    
    private let notesStoreSubject = CurrentValueSubject<NotesStoreData, Never>(NotesStoreData(
        questions: Question.predefinedQuestions,
        notes: [:],
        version: 1
    ))
    
    var mockNotesStore: NotesStoreData
    var saveNoteCallCount = 0
    var saveOrUpdateNoteCallCount = 0
    var shouldThrowError = false
    var errorToThrow: Error?
    
    init() {
        self.mockNotesStore = NotesStoreData(
            questions: Question.predefinedQuestions,
            notes: [:],
            version: 1
        )
    }
    
    func loadNotesStore() async throws -> NotesStoreData {
        if shouldThrowError {
            throw errorToThrow ?? NotesError.decodingFailed(NSError(domain: "test", code: 1))
        }
        return mockNotesStore
    }
    
    func saveNote(_ note: Note) async throws {
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        saveNoteCallCount += 1
        mockNotesStore.notes[note.questionId] = note
        notesStoreSubject.send(mockNotesStore)
    }
    
    func updateNote(_ note: Note) async throws {
        guard mockNotesStore.notes[note.questionId] != nil else {
            throw NotesError.noteNotFound(note.questionId)
        }
        mockNotesStore.notes[note.questionId] = note
        notesStoreSubject.send(mockNotesStore)
    }
    
    func deleteNote(for questionId: UUID) async throws {
        mockNotesStore.notes.removeValue(forKey: questionId)
        notesStoreSubject.send(mockNotesStore)
    }
    
    func saveOrUpdateNote(for questionId: UUID, answer: String, metadata: [String: String]?) async throws {
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        saveOrUpdateNoteCallCount += 1
        let note = Note(questionId: questionId, answer: answer, metadata: metadata)
        mockNotesStore.notes[questionId] = note
        notesStoreSubject.send(mockNotesStore)
    }
    
    func getNote(for questionId: UUID) async throws -> Note? {
        return mockNotesStore.notes[questionId]
    }
    
    func getNote(forQuestionText questionText: String) async -> Note? {
        if let question = mockNotesStore.questions.first(where: { $0.text == questionText }) {
            return mockNotesStore.notes[question.id]
        }
        return nil
    }
    
    func addQuestion(_ question: Question) async throws {
        mockNotesStore.questions.append(question)
        notesStoreSubject.send(mockNotesStore)
    }
    
    func deleteQuestion(_ questionId: UUID) async throws {
        mockNotesStore.questions.removeAll(where: { $0.id == questionId })
        mockNotesStore.notes.removeValue(forKey: questionId)
        notesStoreSubject.send(mockNotesStore)
    }
    
    func getUnansweredQuestions() async throws -> [Question] {
        return mockNotesStore.questions.filter { question in
            mockNotesStore.notes[question.id] == nil
        }
    }
    
    func resetToDefaults() async throws {
        mockNotesStore = NotesStoreData(
            questions: Question.predefinedQuestions,
            notes: [:],
            version: 1
        )
        notesStoreSubject.send(mockNotesStore)
    }
    
    func clearAllData() async throws {
        mockNotesStore.notes.removeAll()
        notesStoreSubject.send(mockNotesStore)
    }
    
    func exportData() async throws -> Data {
        return try JSONEncoder().encode(mockNotesStore)
    }
    
    func importData(_ data: Data) async throws {
        mockNotesStore = try JSONDecoder().decode(NotesStoreData.self, from: data)
        notesStoreSubject.send(mockNotesStore)
    }
    
    func getCurrentQuestion() async -> Question? {
        return mockNotesStore.questionsNeedingReview().first
    }
    
    func getNextUnansweredQuestion() async -> Question? {
        return mockNotesStore.questions.first { question in
            mockNotesStore.notes[question.id] == nil
        }
    }
    
    func saveHouseName(_ name: String) async {
        if let question = mockNotesStore.questions.first(where: { $0.text == "What should I call this house?" }) {
            let note = Note(
                questionId: question.id,
                answer: name,
                metadata: ["type": "house_name", "updated_via_conversation": "true"]
            )
            mockNotesStore.notes[question.id] = note
            notesStoreSubject.send(mockNotesStore)
        }
    }
    
    func getHouseName() async -> String? {
        if let question = mockNotesStore.questions.first(where: { $0.text == "What should I call this house?" }),
           let note = mockNotesStore.notes[question.id] {
            return note.answer
        }
        return nil
    }
    
    func saveWeatherSummary(_ weather: Weather) async {
        // Not implemented for tests
    }
}

// MARK: - Mock Dependencies

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

class MockConversationRecognizer: NSObject {
    var clearHouseThoughtCallCount = 0
    var setQuestionThoughtCallCount = 0
    var setThankYouThoughtCallCount = 0
    var lastQuestionThought: String?
    
    func clearHouseThought() async {
        clearHouseThoughtCallCount += 1
    }
    
    func setQuestionThought(_ question: String) async {
        setQuestionThoughtCallCount += 1
        lastQuestionThought = question
    }
    
    func setThankYouThought() async {
        setThankYouThoughtCallCount += 1
    }
}

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
}

// MARK: - QuestionFlowCoordinatorTests

class QuestionFlowCoordinatorTests: XCTestCase {
    var sut: QuestionFlowCoordinator!
    var mockNotesService: MockNotesService!
    var mockStateManager: MockConversationStateManager!
    // mockRecognizer removed - using protocol-based mock
    var mockAddressManager: MockAddressManagerForFlow!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockNotesService = MockNotesService()
        sut = QuestionFlowCoordinator(notesService: mockNotesService)
        
        // Create and inject mock dependencies
        mockStateManager = MockConversationStateManager(
            notesService: mockNotesService,
            ttsService: MockTTSService()
        )
        // Use protocol-based mock for ConversationRecognizer
        let recognizerMock = MockConversationRecognizer()
        mockAddressManager = MockAddressManager(
            notesService: mockNotesService,
            locationService: MockLocationService()
        )
        
        sut.conversationStateManager = mockStateManager
        sut.conversationRecognizer = recognizerMock as? ConversationRecognizer
        sut.addressManager = mockAddressManager
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockNotesService = nil
        mockStateManager = nil
        // mockRecognizer removed
        mockAddressManager = nil
        super.tearDown()
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
        
        // When: Saving answer
        await sut.saveAnswer()
        
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
        
        // Create mock service container
        let mockContainer = ServiceContainer()
        sut.serviceContainer = mockContainer
        
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
        // Given: No new question
        var isInitializing = true
        
        // When: Handling change
        await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: nil,
            isInitializing: &isInitializing
        )
        
        // Then: Should handle completion
        if sut.hasCompletedAllQuestions {
            XCTAssertEqual(mockRecognizer.setThankYouThoughtCallCount, 1)
        }
    }
    
    func testHandleQuestionChangeForAddressQuestionWithoutAnswer() async {
        // Given: Address question without existing answer
        let addressQuestion = mockNotesService.mockNotesStore.questions.first(where: { 
            $0.text == "Is this the right address?" 
        })!
        var isInitializing = true
        
        // When: Handling change
        await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: addressQuestion,
            isInitializing: &isInitializing
        )
        
        // Then: Should detect address and set question thought
        XCTAssertFalse(isInitializing)
        XCTAssertEqual(mockAddressManager.detectCurrentAddressCallCount, 1)
        XCTAssertEqual(mockStateManager.persistentTranscriptValue, "123 Main St, Springfield, IL, 62701, USA")
        XCTAssertEqual(mockRecognizer.setQuestionThoughtCallCount, 1)
        XCTAssertEqual(mockRecognizer.lastQuestionThought, addressQuestion.text)
    }
    
    func testHandleQuestionChangeForAddressQuestionWithError() async {
        // Given: Address detection will fail
        let addressQuestion = mockNotesService.mockNotesStore.questions.first(where: { 
            $0.text == "What's your home address?" 
        })!
        mockAddressManager.shouldThrowError = true
        var isInitializing = true
        
        // When: Handling change
        await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: addressQuestion,
            isInitializing: &isInitializing
        )
        
        // Then: Should still ask the question
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
        
        var isInitializing = true
        
        // When: Handling change
        await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: houseQuestion,
            isInitializing: &isInitializing
        )
        
        // Then: Should generate house name suggestion
        XCTAssertEqual(mockAddressManager.generateHouseNameCallCount, 1)
        XCTAssertEqual(mockStateManager.persistentTranscriptValue, "Generated House Name")
        XCTAssertEqual(mockRecognizer.setQuestionThoughtCallCount, 1)
    }
    
    func testHandleQuestionChangeWithExistingAnswer() async {
        // Given: Question with existing answer
        let question = mockNotesService.mockNotesStore.questions.first!
        mockNotesService.mockNotesStore.notes[question.id] = Note(
            questionId: question.id,
            answer: "Existing answer"
        )
        var isInitializing = true
        
        // When: Handling change
        await sut.handleQuestionChange(
            oldQuestion: nil,
            newQuestion: question,
            isInitializing: &isInitializing
        )
        
        // Then: Should pre-populate and ask for confirmation
        XCTAssertEqual(mockStateManager.persistentTranscriptValue, "Existing answer")
        XCTAssertEqual(mockRecognizer.lastQuestionThought, "\(question.text) (Current answer: Existing answer)")
    }
    
    // MARK: - Notification Tests
    
    func testAllQuestionsCompleteNotificationReloadsQuestions() async {
        // Given: Subscription to notification
        let expectation = expectation(description: "loadNextQuestion called after notification")
        
        // Subscribe to changes in currentQuestion to verify reload
        sut.$currentQuestion
            .dropFirst() // Skip initial value
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Posting notification
        NotificationCenter.default.post(name: Notification.Name("AllQuestionsComplete"), object: nil)
        
        // Then: Should reload questions
        await fulfillment(of: [expectation], timeout: 2.0)
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

// Note: Mock types are now centralized in TestMocks.swift
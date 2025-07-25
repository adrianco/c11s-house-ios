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
 * - 2025-01-25: Updated for state machine refactor
 *   - Tests now verify state transitions
 *   - Simplified test cases to match new API
 *   - Focus on state machine behavior
 *   - Test processUserInput instead of saveAnswer
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
    var lastSavedAnswer: String?
    
    override func loadNotesStore() async throws -> NotesStoreData {
        if shouldThrowError {
            throw errorToThrow ?? NotesError.decodingFailed(NSError(domain: "test", code: 1))
        }
        return try await super.loadNotesStore()
    }
    
    override func saveNote(_ note: Note) async throws {
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        saveNoteCallCount += 1
        try await super.saveNote(note)
    }
    
    override func saveOrUpdateNote(for questionId: UUID, answer: String, metadata: [String : String]?) async throws {
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        saveOrUpdateNoteCallCount += 1
        lastSavedAnswer = answer
        try await super.saveOrUpdateNote(for: questionId, answer: answer, metadata: metadata)
    }
}

// MARK: - QuestionFlowCoordinatorTests

@MainActor
class QuestionFlowCoordinatorTests: XCTestCase {
    
    private var coordinator: QuestionFlowCoordinator!
    private var mockNotesService: MockNotesServiceForQuestionFlow!
    private var mockStateManager: MockConversationStateManager!
    private var mockRecognizer: MockConversationRecognizer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mocks
        mockNotesService = MockNotesServiceForQuestionFlow()
        mockStateManager = MockConversationStateManager()
        mockRecognizer = MockConversationRecognizer()
        
        // Create coordinator
        coordinator = QuestionFlowCoordinator(notesService: mockNotesService)
        
        // Set up dependencies
        coordinator.conversationStateManager = mockStateManager
        coordinator.conversationRecognizer = mockRecognizer
    }
    
    override func tearDown() async throws {
        coordinator = nil
        mockNotesService = nil
        mockStateManager = nil
        mockRecognizer = nil
        try await super.tearDown()
    }
    
    // MARK: - State Machine Tests
    
    func testInitialState() async throws {
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertNil(coordinator.currentQuestion)
        XCTAssertFalse(coordinator.hasCompletedAllQuestions)
    }
    
    func testStartConversation() async throws {
        // Set up mock to return questions
        let question1 = Question(text: "What's your name?", category: .personal, displayOrder: 0, isRequired: true)
        let question2 = Question(text: "What's your address?", category: .houseInfo, displayOrder: 1, isRequired: true)
        mockNotesService.mockStore = NotesStoreData(questions: [question1, question2])
        
        // Start conversation
        await coordinator.startConversation()
        
        // Verify state transition
        XCTAssertEqual(coordinator.currentQuestion?.text, "What's your name?")
        XCTAssertFalse(coordinator.hasCompletedAllQuestions)
        
        // Verify the state is waiting for answer
        if case .waitingForAnswer(let q) = coordinator.state {
            XCTAssertEqual(q.text, "What's your name?")
        } else {
            XCTFail("Expected waitingForAnswer state")
        }
    }
    
    func testProcessUserInput() async throws {
        // Set up a question
        let question = Question(text: "What's your name?", category: .personal, displayOrder: 0, isRequired: true)
        mockNotesService.mockStore = NotesStoreData(questions: [question])
        
        // Start conversation to get to waiting state
        await coordinator.startConversation()
        
        // Process user input
        await coordinator.processUserInput("John Doe")
        
        // Verify answer was saved
        XCTAssertEqual(mockNotesService.saveOrUpdateNoteCallCount, 1)
        XCTAssertEqual(mockNotesService.lastSavedAnswer, "John Doe")
        
        // Verify state moved to completed (no more questions)
        XCTAssertEqual(coordinator.state, .completed)
        XCTAssertTrue(coordinator.hasCompletedAllQuestions)
    }
    
    func testProcessUserInputIgnoresAcknowledgmentForAddress() async throws {
        // Set up address question
        let question = Question(text: "Is this the right address?", category: .houseInfo, displayOrder: 0, isRequired: true)
        mockNotesService.mockStore = NotesStoreData(questions: [question])
        
        // Start conversation
        await coordinator.startConversation()
        
        // Try to process acknowledgment
        await coordinator.processUserInput("continue")
        
        // Verify it stayed in waiting state and didn't save
        if case .waitingForAnswer(let q) = coordinator.state {
            XCTAssertEqual(q.text, "Is this the right address?")
        } else {
            XCTFail("Expected to stay in waitingForAnswer state")
        }
        XCTAssertEqual(mockNotesService.saveOrUpdateNoteCallCount, 0)
        
        // Now process real address
        await coordinator.processUserInput("123 Main Street")
        
        // Verify it saved
        XCTAssertEqual(mockNotesService.saveOrUpdateNoteCallCount, 1)
        XCTAssertEqual(mockNotesService.lastSavedAnswer, "123 Main Street")
    }
    
    func testMultipleQuestionsFlow() async throws {
        // Set up multiple questions
        let question1 = Question(text: "What's your name?", category: .personal, displayOrder: 0, isRequired: true)
        let question2 = Question(text: "What's your address?", category: .houseInfo, displayOrder: 1, isRequired: true)
        let question3 = Question(text: "What should I call this house?", category: .houseInfo, displayOrder: 2, isRequired: true)
        mockNotesService.mockStore = NotesStoreData(questions: [question1, question2, question3])
        
        // Start conversation
        await coordinator.startConversation()
        XCTAssertEqual(coordinator.currentQuestion?.text, "What's your name?")
        
        // Answer first question
        await coordinator.processUserInput("John Doe")
        XCTAssertEqual(coordinator.currentQuestion?.text, "What's your address?")
        
        // Answer second question
        await coordinator.processUserInput("123 Main Street")
        XCTAssertEqual(coordinator.currentQuestion?.text, "What should I call this house?")
        
        // Answer third question
        await coordinator.processUserInput("Main Street House")
        
        // Should be completed
        XCTAssertEqual(coordinator.state, .completed)
        XCTAssertTrue(coordinator.hasCompletedAllQuestions)
        XCTAssertNil(coordinator.currentQuestion)
    }
    
    func testReset() async throws {
        // Start conversation and answer a question
        let question = Question(text: "What's your name?", category: .personal, displayOrder: 0, isRequired: true)
        mockNotesService.mockStore = NotesStoreData(questions: [question])
        
        await coordinator.startConversation()
        await coordinator.processUserInput("John Doe")
        
        // Verify completed
        XCTAssertEqual(coordinator.state, .completed)
        
        // Reset
        await coordinator.reset()
        
        // Verify reset to idle
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertNil(coordinator.currentQuestion)
        XCTAssertFalse(coordinator.hasCompletedAllQuestions)
    }
    
    func testErrorHandling() async throws {
        // Set up service to throw error
        mockNotesService.shouldThrowError = true
        mockNotesService.errorToThrow = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // Try to start conversation
        await coordinator.startConversation()
        
        // Verify error state
        if case .error(let message) = coordinator.state {
            XCTAssertEqual(message, "Test error")
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testStateDescription() async throws {
        // Test idle state
        XCTAssertEqual(coordinator.stateDescription, "Idle")
        
        // Test waiting state
        let question = Question(text: "What's your name?", category: .personal, displayOrder: 0)
        mockNotesService.mockStore = NotesStoreData(questions: [question])
        await coordinator.startConversation()
        XCTAssertTrue(coordinator.stateDescription.contains("Waiting for answer"))
        
        // Test completed state
        await coordinator.processUserInput("John Doe")
        XCTAssertEqual(coordinator.stateDescription, "All questions completed")
    }
    
    func testEmptyInputIgnored() async throws {
        // Set up a question
        let question = Question(text: "What's your name?", category: .personal, displayOrder: 0, isRequired: true)
        mockNotesService.mockStore = NotesStoreData(questions: [question])
        
        // Start conversation
        await coordinator.startConversation()
        
        // Try to process empty input
        await coordinator.processUserInput("")
        await coordinator.processUserInput("   ")
        
        // Verify still in waiting state
        if case .waitingForAnswer(let q) = coordinator.state {
            XCTAssertEqual(q.text, "What's your name?")
        } else {
            XCTFail("Expected to stay in waitingForAnswer state")
        }
        XCTAssertEqual(mockNotesService.saveOrUpdateNoteCallCount, 0)
    }
    
    func testLoadNextQuestionCompatibility() async throws {
        // Test that loadNextQuestion works as a compatibility method
        let question = Question(text: "What's your name?", category: .personal, displayOrder: 0, isRequired: true)
        mockNotesService.mockStore = NotesStoreData(questions: [question])
        
        // Call loadNextQuestion when idle (should start conversation)
        await coordinator.loadNextQuestion()
        XCTAssertEqual(coordinator.currentQuestion?.text, "What's your name?")
        
        // Answer the question
        await coordinator.processUserInput("John Doe")
        
        // Call loadNextQuestion when completed (should do nothing)
        await coordinator.loadNextQuestion()
        XCTAssertEqual(coordinator.state, .completed)
    }
}
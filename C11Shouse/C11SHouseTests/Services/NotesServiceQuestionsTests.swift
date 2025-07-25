/*
 * CONTEXT & PURPOSE:
 * NotesServiceQuestionsTests validates the NotesService+Questions extension methods,
 * ensuring proper functionality for question-related operations.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation
 *   - Tests convenience methods
 *   - Validates question filtering
 *   - Verifies progress tracking
 *   - Ensures error handling
 * - 2025-07-25: Fixed test assertions for 3 predefined questions
 *   - Updated from 4 to 3 questions (address, house name, user name)
 *   - Fixed array index out of range crash
 *   - Updated question counts in all affected tests
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
@testable import C11SHouse

@MainActor
class NotesServiceQuestionsTests: XCTestCase {
    
    private var notesService: NotesServiceProtocol!
    
    override func setUp() async throws {
        try await super.setUp()
        notesService = NotesServiceImpl()
        
        // Clear any existing data
        try await notesService.clearAllData()
    }
    
    override func tearDown() async throws {
        try await notesService.clearAllData()
        try await super.tearDown()
    }
    
    func testGetCurrentQuestion() async throws {
        // Test getting current question from predefined questions
        let current = await notesService.getCurrentQuestion()
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.displayOrder, 0) // Should get first question (address)
        
        // Answer the first question
        try await notesService.saveOrUpdateNote(
            for: current!.id,
            answer: "123 Test St",
            metadata: ["updated_via_conversation": "true"]
        )
        
        // Now should get the second question
        let nextCurrent = await notesService.getCurrentQuestion()
        XCTAssertNotNil(nextCurrent)
        XCTAssertEqual(nextCurrent?.displayOrder, 1) // Should get second question (house name)
        
        // Answer all required questions
        let store = try await notesService.loadNotesStore()
        let requiredQuestions = store.questions.filter { $0.isRequired }
        
        for question in requiredQuestions {
            try await notesService.saveOrUpdateNote(
                for: question.id,
                answer: "Test Answer",
                metadata: ["updated_via_conversation": "true"]
            )
        }
        
        // Should return nil when all required questions answered
        let noCurrent = await notesService.getCurrentQuestion()
        XCTAssertNil(noCurrent)
    }
    
    func testGetNextUnansweredQuestion() async throws {
        // Test with predefined questions - should get first required question
        let next = await notesService.getNextUnansweredQuestion()
        XCTAssertNotNil(next)
        XCTAssertTrue(next!.isRequired)
        XCTAssertEqual(next?.displayOrder, 0) // Should be the address question
        
        // Answer the first required question
        try await notesService.saveOrUpdateNote(
            for: next!.id,
            answer: "123 Test St"
        )
        
        // Should get the next required question
        let next2 = await notesService.getNextUnansweredQuestion()
        XCTAssertNotNil(next2)
        XCTAssertTrue(next2!.isRequired)
        XCTAssertEqual(next2?.displayOrder, 1) // Should be the house name question
        
        // Answer all required questions
        let store = try await notesService.loadNotesStore()
        let requiredQuestions = store.questions.filter { $0.isRequired }
        
        for question in requiredQuestions {
            try await notesService.saveOrUpdateNote(
                for: question.id,
                answer: "Test Answer",
                metadata: ["updated_via_conversation": "true"]
            )
        }
        
        // Should return nil when all required questions are answered
        let next3 = await notesService.getNextUnansweredQuestion()
        XCTAssertNil(next3)
    }
    
    func testGetQuestionsInCategory() async throws {
        // Test with predefined questions first
        let personal = await notesService.getQuestions(in: .personal)
        XCTAssertEqual(personal.count, 1) // "What's your name?"
        XCTAssertTrue(personal.allSatisfy { $0.category == .personal })
        
        let houseInfo = await notesService.getQuestions(in: .houseInfo)
        XCTAssertEqual(houseInfo.count, 2) // Address and house name questions
        XCTAssertTrue(houseInfo.allSatisfy { $0.category == .houseInfo })
        
        // Add a custom question to test category filtering
        let customQuestion = Question(
            id: UUID(),
            text: "What are your hobbies?",
            category: .preferences,
            displayOrder: 100
        )
        try await notesService.addQuestion(customQuestion)
        
        let preferences = await notesService.getQuestions(in: .preferences)
        XCTAssertEqual(preferences.count, 1)
        XCTAssertEqual(preferences.first?.text, "What are your hobbies?")
        
        // Test empty category
        let maintenance = await notesService.getQuestions(in: .maintenance)
        XCTAssertEqual(maintenance.count, 0)
    }
    
    func testAreAllRequiredQuestionsAnswered() async throws {
        // Initially should be false - predefined questions are required
        let allAnswered1 = await notesService.areAllRequiredQuestionsAnswered()
        XCTAssertFalse(allAnswered1)
        
        // Get all required questions and answer them
        let store = try await notesService.loadNotesStore()
        let requiredQuestions = store.questions.filter { $0.isRequired }
        
        // Answer all but one required question
        for (index, question) in requiredQuestions.enumerated() {
            if index < requiredQuestions.count - 1 {
                try await notesService.saveOrUpdateNote(
                    for: question.id,
                    answer: "Answer \(index + 1)"
                )
            }
        }
        
        // Should still be false
        let allAnswered2 = await notesService.areAllRequiredQuestionsAnswered()
        XCTAssertFalse(allAnswered2)
        
        // Answer the last required question
        if let lastQuestion = requiredQuestions.last {
            try await notesService.saveOrUpdateNote(
                for: lastQuestion.id,
                answer: "Final Answer"
            )
        }
        
        // Now should be true
        let allAnswered3 = await notesService.areAllRequiredQuestionsAnswered()
        XCTAssertTrue(allAnswered3)
        
        // Add an optional question - should still be true
        let optionalQuestion = Question(
            id: UUID(),
            text: "Optional question",
            category: .other,
            displayOrder: 100,
            isRequired: false
        )
        try await notesService.addQuestion(optionalQuestion)
        
        let allAnswered4 = await notesService.areAllRequiredQuestionsAnswered()
        XCTAssertTrue(allAnswered4) // Optional questions don't affect this
    }
    
    func testGetQuestionProgress() async throws {
        // Test with predefined questions (3 total, all required)
        let progress1 = await notesService.getQuestionProgress()
        XCTAssertEqual(progress1.answered, 0)
        XCTAssertEqual(progress1.total, 3) // 3 predefined questions
        XCTAssertFalse(progress1.requiredComplete)
        
        // Get predefined questions and answer one
        let store = try await notesService.loadNotesStore()
        let questions = store.questions.sorted { $0.displayOrder < $1.displayOrder }
        
        try await notesService.saveOrUpdateNote(
            for: questions[0].id,
            answer: "Answer"
        )
        
        let progress2 = await notesService.getQuestionProgress()
        XCTAssertEqual(progress2.answered, 1)
        XCTAssertEqual(progress2.total, 3)
        XCTAssertFalse(progress2.requiredComplete)
        
        // Answer all required questions
        for question in questions.filter({ $0.isRequired }) {
            try await notesService.saveOrUpdateNote(
                for: question.id,
                answer: "Answer"
            )
        }
        
        let progress3 = await notesService.getQuestionProgress()
        XCTAssertEqual(progress3.answered, 3) // All questions answered
        XCTAssertEqual(progress3.total, 3)
        XCTAssertTrue(progress3.requiredComplete) // All required answered
        
        // Add an optional question
        let optionalQuestion = Question(
            id: UUID(),
            text: "Optional question",
            category: .other,
            displayOrder: 100,
            isRequired: false
        )
        try await notesService.addQuestion(optionalQuestion)
        
        let progress4 = await notesService.getQuestionProgress()
        XCTAssertEqual(progress4.answered, 3) // Still 3 answered
        XCTAssertEqual(progress4.total, 4) // Now 4 total
        XCTAssertTrue(progress4.requiredComplete) // Required still complete
    }
    
    func testGetUnansweredQuestions() async throws {
        // Test with predefined questions - all should be unanswered initially
        let unanswered1 = try await notesService.getUnansweredQuestions()
        XCTAssertEqual(unanswered1.count, 3) // 3 predefined questions
        
        // Should be sorted by displayOrder
        XCTAssertEqual(unanswered1[0].displayOrder, 0) // Address question
        XCTAssertEqual(unanswered1[1].displayOrder, 1) // House name question
        XCTAssertEqual(unanswered1[2].displayOrder, 2) // User name question
        
        // Answer the first question
        try await notesService.saveOrUpdateNote(
            for: unanswered1[0].id,
            answer: "123 Test St"
        )
        
        let unanswered2 = try await notesService.getUnansweredQuestions()
        XCTAssertEqual(unanswered2.count, 3)
        XCTAssertFalse(unanswered2.contains { $0.displayOrder == 0 })
        
        // Answer all questions
        for question in unanswered1 {
            try await notesService.saveOrUpdateNote(
                for: question.id,
                answer: "Test Answer"
            )
        }
        
        let unanswered3 = try await notesService.getUnansweredQuestions()
        XCTAssertEqual(unanswered3.count, 0)
    }
    
    func testIsQuestionAnswered() async throws {
        // Test with predefined questions - should be unanswered initially
        let store = try await notesService.loadNotesStore()
        let firstQuestion = store.questions.first!
        
        let answered1 = await notesService.isQuestionAnswered(firstQuestion.id)
        XCTAssertFalse(answered1)
        
        // Answer the question
        try await notesService.saveOrUpdateNote(
            for: firstQuestion.id,
            answer: "Test answer"
        )
        
        // Now should be answered
        let answered2 = await notesService.isQuestionAnswered(firstQuestion.id)
        XCTAssertTrue(answered2)
        
        // Test with non-existent question ID
        let randomId = UUID()
        let answered3 = await notesService.isQuestionAnswered(randomId)
        XCTAssertFalse(answered3)
        
        // Test with empty answer
        try await notesService.saveOrUpdateNote(
            for: firstQuestion.id,
            answer: ""
        )
        
        let answered4 = await notesService.isQuestionAnswered(firstQuestion.id)
        XCTAssertFalse(answered4) // Empty answer should be false
    }
}
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
        // Setup test data
        let question1 = Question(
            id: UUID(),
            text: "What's your name?",
            category: .personal,
            displayOrder: 1,
            isRequired: true
        )
        
        let question2 = Question(
            id: UUID(),
            text: "What's your address?",
            category: .houseInfo,
            displayOrder: 2,
            isRequired: true
        )
        
        // Clear existing data and add test questions
        try await notesService.clearAllData()
        try await notesService.addQuestion(question1)
        try await notesService.addQuestion(question2)
        
        // Test getting current question
        let current = await notesService.getCurrentQuestion()
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.displayOrder, 1) // Should get first question
        
        // Answer the first question
        try await notesService.saveOrUpdateNote(
            for: question1.id,
            answer: "Test User"
        )
        
        // Now should get the second question
        let nextCurrent = await notesService.getCurrentQuestion()
        XCTAssertEqual(nextCurrent?.id, question2.id)
        
        // Answer all questions
        try await notesService.saveOrUpdateNote(
            for: question2.id,
            answer: "123 Test St"
        )
        
        // Should return nil when all answered
        let noCurrent = await notesService.getCurrentQuestion()
        XCTAssertNil(noCurrent)
    }
    
    func testGetNextUnansweredQuestion() async throws {
        // Setup test data with mixed priorities
        let highQuestion = Question(
            id: UUID(),
            text: "High priority",
            category: .personal,
            displayOrder: 1,
            isRequired: true
        )
        
        let mediumQuestion = Question(
            id: UUID(),
            text: "Medium priority",
            category: .personal,
            displayOrder: 2,
            isRequired: true
        )
        
        let optionalQuestion = Question(
            id: UUID(),
            text: "Optional question",
            category: .personal,
            displayOrder: 3,
            isRequired: false
        )
        
        // Clear existing data and add test questions
        try await notesService.clearAllData()
        try await notesService.addQuestion(highQuestion)
        try await notesService.addQuestion(mediumQuestion)
        try await notesService.addQuestion(optionalQuestion)
        
        // Should get high priority required question first
        let next = await notesService.getNextUnansweredQuestion()
        XCTAssertEqual(next?.id, highQuestion.id)
        
        // Answer high priority
        try await notesService.saveOrUpdateNote(
            for: highQuestion.id,
            answer: "Answer"
        )
        
        // Should get medium priority next
        let next2 = await notesService.getNextUnansweredQuestion()
        XCTAssertEqual(next2?.id, mediumQuestion.id)
        
        // Answer medium priority
        try await notesService.saveOrUpdateNote(
            for: mediumQuestion.id,
            answer: "Answer"
        )
        
        // Should return nil (optional question is not required)
        let next3 = await notesService.getNextUnansweredQuestion()
        XCTAssertNil(next3)
    }
    
    func testGetQuestionsInCategory() async throws {
        // Setup questions in different categories
        let personalQuestions = [
            Question(id: UUID(), text: "Name?", category: .personal, displayOrder: 1),
            Question(id: UUID(), text: "Age?", category: .personal, displayOrder: 2)
        ]
        
        let locationQuestions = [
            Question(id: UUID(), text: "Address?", category: .houseInfo, displayOrder: 3),
            Question(id: UUID(), text: "City?", category: .houseInfo, displayOrder: 4)
        ]
        
        let lifestyleQuestions = [
            Question(id: UUID(), text: "Hobbies?", category: .preferences, displayOrder: 5)
        ]
        
        // Clear existing data and add test questions
        try await notesService.clearAllData()
        for question in personalQuestions + locationQuestions + lifestyleQuestions {
            try await notesService.addQuestion(question)
        }
        
        // Test category filtering
        let personal = await notesService.getQuestions(in: .personal)
        XCTAssertEqual(personal.count, 2)
        XCTAssertTrue(personal.allSatisfy { $0.category == .personal })
        
        let houseInfo = await notesService.getQuestions(in: .houseInfo)
        XCTAssertEqual(houseInfo.count, 2)
        XCTAssertTrue(houseInfo.allSatisfy { $0.category == .houseInfo })
        
        let preferences = await notesService.getQuestions(in: .preferences)
        XCTAssertEqual(preferences.count, 1)
        XCTAssertEqual(preferences.first?.text, "Hobbies?")
    }
    
    func testAreAllRequiredQuestionsAnswered() async throws {
        // Setup mix of required and optional questions
        let required1 = Question(
            id: UUID(),
            text: "Required 1",
            category: .personal,
            displayOrder: 1,
            isRequired: true
        )
        
        let required2 = Question(
            id: UUID(),
            text: "Required 2",
            category: .personal,
            displayOrder: 1,
            isRequired: true
        )
        
        let optional = Question(
            id: UUID(),
            text: "Optional",
            category: .personal,
            displayOrder: 3,
            isRequired: false
        )
        
        // Clear existing data and add test questions
        try await notesService.clearAllData()
        try await notesService.addQuestion(required1)
        try await notesService.addQuestion(required2)
        try await notesService.addQuestion(optional)
        
        // Initially should be false
        let allAnswered1 = await notesService.areAllRequiredQuestionsAnswered()
        XCTAssertFalse(allAnswered1)
        
        // Answer one required question
        try await notesService.saveOrUpdateNote(
            for: required1.id,
            answer: "Answer 1"
        )
        
        // Still false
        let allAnswered2 = await notesService.areAllRequiredQuestionsAnswered()
        XCTAssertFalse(allAnswered2)
        
        // Answer second required question
        try await notesService.saveOrUpdateNote(
            for: required2.id,
            answer: "Answer 2"
        )
        
        // Now should be true (optional doesn't matter)
        let allAnswered3 = await notesService.areAllRequiredQuestionsAnswered()
        XCTAssertTrue(allAnswered3)
    }
    
    func testGetQuestionProgress() async throws {
        // Setup test questions
        let questions = [
            Question(id: UUID(), text: "Q1", category: .personal, displayOrder: 1, isRequired: true),
            Question(id: UUID(), text: "Q2", category: .personal, displayOrder: 2, isRequired: true),
            Question(id: UUID(), text: "Q3", category: .personal, displayOrder: 3, isRequired: false)
        ]
        
        // Clear existing data and add test questions
        try await notesService.clearAllData()
        for question in questions {
            try await notesService.addQuestion(question)
        }
        
        // Initial progress
        let progress1 = await notesService.getQuestionProgress()
        XCTAssertEqual(progress1.answered, 0)
        XCTAssertEqual(progress1.total, 3)
        XCTAssertFalse(progress1.requiredComplete)
        
        // Answer one required question
        try await notesService.saveOrUpdateNote(
            for: questions[0].id,
            answer: "Answer"
        )
        
        let progress2 = await notesService.getQuestionProgress()
        XCTAssertEqual(progress2.answered, 1)
        XCTAssertEqual(progress2.total, 3)
        XCTAssertFalse(progress2.requiredComplete)
        
        // Answer second required question
        try await notesService.saveOrUpdateNote(
            for: questions[1].id,
            answer: "Answer"
        )
        
        let progress3 = await notesService.getQuestionProgress()
        XCTAssertEqual(progress3.answered, 2)
        XCTAssertEqual(progress3.total, 3)
        XCTAssertTrue(progress3.requiredComplete) // All required answered
        
        // Answer optional question
        try await notesService.saveOrUpdateNote(
            for: questions[2].id,
            answer: "Answer"
        )
        
        let progress4 = await notesService.getQuestionProgress()
        XCTAssertEqual(progress4.answered, 3)
        XCTAssertEqual(progress4.total, 3)
        XCTAssertTrue(progress4.requiredComplete)
    }
    
    func testGetUnansweredQuestions() async throws {
        // Setup questions with different priorities
        let questions = [
            Question(id: UUID(), text: "Low", category: .personal, displayOrder: 3),
            Question(id: UUID(), text: "High", category: .personal, displayOrder: 1),
            Question(id: UUID(), text: "Medium", category: .personal, displayOrder: 2)
        ]
        
        // Clear existing data and add test questions
        try await notesService.clearAllData()
        for question in questions {
            try await notesService.addQuestion(question)
        }
        
        // All should be unanswered initially
        let unanswered1 = try await notesService.getUnansweredQuestions()
        XCTAssertEqual(unanswered1.count, 3)
        
        // Should be sorted by displayOrder
        XCTAssertEqual(unanswered1[0].displayOrder, 1)
        XCTAssertEqual(unanswered1[1].displayOrder, 2)
        XCTAssertEqual(unanswered1[2].displayOrder, 3)
        
        // Answer one question
        try await notesService.saveOrUpdateNote(
            for: questions[1].id, // High priority
            answer: "Answer"
        )
        
        let unanswered2 = try await notesService.getUnansweredQuestions()
        XCTAssertEqual(unanswered2.count, 2)
        XCTAssertFalse(unanswered2.contains { $0.text == "High" })
    }
    
    func testIsQuestionAnswered() async throws {
        let question = Question(
            id: UUID(),
            text: "Test question",
            category: .personal,
            displayOrder: 1
        )
        
        // Clear existing data and add test question
        try await notesService.clearAllData()
        try await notesService.addQuestion(question)
        
        // Initially not answered
        let answered1 = await notesService.isQuestionAnswered(question.id)
        XCTAssertFalse(answered1)
        
        // Answer the question
        try await notesService.saveOrUpdateNote(
            for: question.id,
            answer: "Test answer"
        )
        
        // Now should be answered
        let answered2 = await notesService.isQuestionAnswered(question.id)
        XCTAssertTrue(answered2)
        
        // Test with non-existent question ID
        let randomId = UUID()
        let answered3 = await notesService.isQuestionAnswered(randomId)
        XCTAssertFalse(answered3)
    }
}
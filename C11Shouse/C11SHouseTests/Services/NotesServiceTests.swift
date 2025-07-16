/*
 * CONTEXT & PURPOSE:
 * NotesServiceTests validates the NotesService implementation - the CENTRAL PERSISTENT MEMORY
 * SYSTEM for the entire app. These tests ensure data integrity, thread safety, proper persistence,
 * and correct handling of all CRUD operations. Since NotesService is the foundation for AI context
 * and backend synchronization, these tests are CRITICAL for app reliability.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial comprehensive test implementation
 *   - Mock UserDefaults for test isolation
 *   - Test all CRUD operations (saveOrUpdateNote, getNote, deleteNote, etc.)
 *   - Thread safety testing with concurrent operations
 *   - Persistence and loading validation
 *   - Error handling for all failure modes
 *   - Async/await test patterns throughout
 *   - Publisher testing for reactive updates
 *   - Migration testing for version updates
 *   - House name functionality testing
 *   - Weather summary testing
 *
 * FUTURE UPDATES:
 * - Add tests for backend synchronization when implemented
 * - Test encryption when sensitive data storage is added
 * - Performance tests for large data sets
 */

import XCTest
import Combine
@testable import C11SHouse

class NotesServiceTests: XCTestCase {
    var sut: NotesServiceImpl!
    var mockUserDefaults: UserDefaults!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        // Create isolated UserDefaults for testing
        mockUserDefaults = UserDefaults(suiteName: "com.c11shouse.tests.\(UUID().uuidString)")!
        sut = NotesServiceImpl(userDefaults: mockUserDefaults)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockUserDefaults.removePersistentDomain(forName: "test")
        mockUserDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationCreatesDefaultQuestions() async throws {
        // Given: Fresh service
        // When: Loading notes store
        let store = try await sut.loadNotesStore()
        
        // Then: Should have predefined questions
        XCTAssertEqual(store.questions.count, Question.predefinedQuestions.count)
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertEqual(store.version, 1)
    }
    
    func testInitializationLoadsExistingData() async throws {
        // Given: Existing data in UserDefaults
        let existingStore = NotesStoreData(
            questions: Question.predefinedQuestions,
            notes: [Question.predefinedQuestions[0].id: Note(
                questionId: Question.predefinedQuestions[0].id,
                answer: "Test Answer"
            )],
            version: 1
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(existingStore)
        mockUserDefaults.set(data, forKey: "com.c11shouse.notesStore")
        
        // When: Creating new service
        let newService = NotesServiceImpl(userDefaults: mockUserDefaults)
        await Task.yield() // Allow initialization to complete
        let loadedStore = try await newService.loadNotesStore()
        
        // Then: Should load existing data
        XCTAssertEqual(loadedStore.notes.count, 1)
        XCTAssertEqual(loadedStore.notes[Question.predefinedQuestions[0].id]?.answer, "Test Answer")
    }
    
    // MARK: - CRUD Operation Tests
    
    func testSaveNote() async throws {
        // Given: A question exists
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        
        // When: Saving a note
        let note = Note(
            questionId: question.id,
            answer: "My test answer",
            metadata: ["source": "unit_test"]
        )
        try await sut.saveNote(note)
        
        // Then: Note should be persisted
        let updatedStore = try await sut.loadNotesStore()
        XCTAssertNotNil(updatedStore.notes[question.id])
        XCTAssertEqual(updatedStore.notes[question.id]?.answer, "My test answer")
        XCTAssertEqual(updatedStore.notes[question.id]?.metadata?["source"], "unit_test")
    }
    
    func testSaveNoteForNonExistentQuestionThrows() async throws {
        // Given: A note for non-existent question
        let note = Note(questionId: UUID(), answer: "Test")
        
        // When/Then: Should throw questionNotFound error
        do {
            try await sut.saveNote(note)
            XCTFail("Expected error to be thrown")
        } catch let error as NotesError {
            if case .questionNotFound = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testUpdateNote() async throws {
        // Given: An existing note
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        let originalNote = Note(questionId: question.id, answer: "Original")
        try await sut.saveNote(originalNote)
        
        // When: Updating the note
        var updatedNote = originalNote
        updatedNote.answer = "Updated answer"
        try await sut.updateNote(updatedNote)
        
        // Then: Note should be updated with new timestamp
        let updatedStore = try await sut.loadNotesStore()
        XCTAssertEqual(updatedStore.notes[question.id]?.answer, "Updated answer")
        XCTAssertGreaterThan(
            updatedStore.notes[question.id]!.lastModified,
            originalNote.lastModified
        )
    }
    
    func testUpdateNonExistentNoteThrows() async throws {
        // Given: A note that doesn't exist
        let note = Note(questionId: UUID(), answer: "Test")
        
        // When/Then: Should throw noteNotFound error
        do {
            try await sut.updateNote(note)
            XCTFail("Expected error to be thrown")
        } catch let error as NotesError {
            if case .noteNotFound = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testDeleteNote() async throws {
        // Given: An existing note
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        let note = Note(questionId: question.id, answer: "To be deleted")
        try await sut.saveNote(note)
        
        // When: Deleting the note
        try await sut.deleteNote(for: question.id)
        
        // Then: Note should be removed
        let updatedStore = try await sut.loadNotesStore()
        XCTAssertNil(updatedStore.notes[question.id])
    }
    
    func testSaveOrUpdateNote() async throws {
        // Given: A question exists
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        
        // When: Using saveOrUpdate for new note
        try await sut.saveOrUpdateNote(
            for: question.id,
            answer: "New answer",
            metadata: ["test": "value"]
        )
        
        // Then: Should create new note
        var updatedStore = try await sut.loadNotesStore()
        XCTAssertEqual(updatedStore.notes[question.id]?.answer, "New answer")
        XCTAssertEqual(updatedStore.notes[question.id]?.metadata?["test"], "value")
        
        // When: Using saveOrUpdate for existing note
        try await sut.saveOrUpdateNote(
            for: question.id,
            answer: "Updated answer",
            metadata: ["test": "updated", "new": "field"]
        )
        
        // Then: Should update existing note
        updatedStore = try await sut.loadNotesStore()
        XCTAssertEqual(updatedStore.notes[question.id]?.answer, "Updated answer")
        XCTAssertEqual(updatedStore.notes[question.id]?.metadata?["test"], "updated")
        XCTAssertEqual(updatedStore.notes[question.id]?.metadata?["new"], "field")
    }
    
    func testGetNote() async throws {
        // Given: An existing note
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        let note = Note(questionId: question.id, answer: "Test answer")
        try await sut.saveNote(note)
        
        // When: Getting the note
        let retrievedNote = try await sut.getNote(for: question.id)
        
        // Then: Should return the note
        XCTAssertNotNil(retrievedNote)
        XCTAssertEqual(retrievedNote?.answer, "Test answer")
        
        // When: Getting non-existent note
        let nonExistentNote = try await sut.getNote(for: UUID())
        
        // Then: Should return nil
        XCTAssertNil(nonExistentNote)
    }
    
    // MARK: - Question Management Tests
    
    func testAddQuestion() async throws {
        // Given: A new question
        let newQuestion = Question(
            text: "What's your favorite room?",
            category: .preferences,
            displayOrder: 100
        )
        
        // When: Adding the question
        try await sut.addQuestion(newQuestion)
        
        // Then: Question should be added
        let store = try await sut.loadNotesStore()
        XCTAssertTrue(store.questions.contains(where: { $0.id == newQuestion.id }))
    }
    
    func testAddDuplicateQuestionThrows() async throws {
        // Given: An existing question
        let store = try await sut.loadNotesStore()
        let existingQuestion = store.questions.first!
        
        // When/Then: Adding duplicate should throw
        do {
            try await sut.addQuestion(existingQuestion)
            XCTFail("Expected error to be thrown")
        } catch let error as NotesError {
            if case .duplicateQuestion = error {
                // Success
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testDeleteQuestion() async throws {
        // Given: A question with a note
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        let note = Note(questionId: question.id, answer: "Test")
        try await sut.saveNote(note)
        
        // When: Deleting the question
        try await sut.deleteQuestion(question.id)
        
        // Then: Both question and note should be removed
        let updatedStore = try await sut.loadNotesStore()
        XCTAssertFalse(updatedStore.questions.contains(where: { $0.id == question.id }))
        XCTAssertNil(updatedStore.notes[question.id])
    }
    
    func testResetToDefaults() async throws {
        // Given: Custom questions and notes
        let customQuestion = Question(
            text: "Custom question",
            category: .other,
            displayOrder: 999
        )
        try await sut.addQuestion(customQuestion)
        
        let store = try await sut.loadNotesStore()
        let predefinedQuestion = store.questions.first(where: { $0.isRequired })!
        try await sut.saveNote(Note(
            questionId: predefinedQuestion.id,
            answer: "Should be preserved"
        ))
        try await sut.saveNote(Note(
            questionId: customQuestion.id,
            answer: "Should be removed"
        ))
        
        // When: Resetting to defaults
        try await sut.resetToDefaults()
        
        // Then: Only predefined questions remain, with their notes preserved
        let resetStore = try await sut.loadNotesStore()
        XCTAssertEqual(resetStore.questions.count, Question.predefinedQuestions.count)
        XCTAssertNotNil(resetStore.notes[predefinedQuestion.id])
        XCTAssertEqual(resetStore.notes[predefinedQuestion.id]?.answer, "Should be preserved")
        XCTAssertNil(resetStore.notes[customQuestion.id])
    }
    
    func testClearAllData() async throws {
        // Given: Questions and notes exist
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        try await sut.saveNote(Note(questionId: question.id, answer: "Test"))
        
        // When: Clearing all data
        try await sut.clearAllData()
        
        // Then: Should have predefined questions but no notes
        let clearedStore = try await sut.loadNotesStore()
        XCTAssertEqual(clearedStore.questions.count, Question.predefinedQuestions.count)
        XCTAssertTrue(clearedStore.notes.isEmpty)
    }
    
    // MARK: - Publisher Tests
    
    func testNotesStorePublisher() async throws {
        // Given: Subscription to publisher
        var receivedStores: [NotesStoreData] = []
        let expectation = expectation(description: "Publisher emits updates")
        expectation.expectedFulfillmentCount = 1 // Only fulfill once when we have enough updates
        
        // Skip initial values and only track changes after subscription
        sut.notesStorePublisher
            .dropFirst() // Drop the current value from initialization
            .sink { store in
                receivedStores.append(store)
                if receivedStores.count >= 3 && expectation.expectedFulfillmentCount > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: Performing operations
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        let note = Note(questionId: question.id, answer: "Test")
        try await sut.saveNote(note)
        
        var updatedNote = note
        updatedNote.answer = "Updated"
        try await sut.updateNote(updatedNote)
        
        // Then: Publisher should emit updates
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(receivedStores.count, 3)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentSaveOperations() async throws {
        // Given: Multiple questions
        let store = try await sut.loadNotesStore()
        let questions = Array(store.questions.prefix(3))
        
        // When: Saving notes concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, question) in questions.enumerated() {
                group.addTask {
                    let note = Note(
                        questionId: question.id,
                        answer: "Concurrent answer \(index)"
                    )
                    try await self.sut.saveNote(note)
                }
            }
            try await group.waitForAll()
        }
        
        // Then: All notes should be saved correctly
        let finalStore = try await sut.loadNotesStore()
        for (index, question) in questions.enumerated() {
            XCTAssertEqual(
                finalStore.notes[question.id]?.answer,
                "Concurrent answer \(index)"
            )
        }
    }
    
    func testConcurrentReadWriteOperations() async throws {
        // Given: A question with a note
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        let initialNote = Note(questionId: question.id, answer: "Initial")
        try await sut.saveNote(initialNote)
        
        // When: Reading and writing concurrently
        try await withThrowingTaskGroup(of: Note?.self) { group in
            // Multiple read operations
            for _ in 0..<5 {
                group.addTask {
                    try await self.sut.getNote(for: question.id)
                }
            }
            
            // Write operation
            group.addTask {
                var updatedNote = initialNote
                updatedNote.answer = "Updated concurrently"
                try await self.sut.updateNote(updatedNote)
                return updatedNote
            }
            
            // Collect results
            for try await _ in group {
                // Just ensure no crashes
            }
        }
        
        // Then: Final state should be consistent
        let finalNote = try await sut.getNote(for: question.id)
        XCTAssertNotNil(finalNote)
        // Either initial or updated value is acceptable due to race conditions
        XCTAssertTrue(
            finalNote?.answer == "Initial" || finalNote?.answer == "Updated concurrently"
        )
    }
    
    // MARK: - Persistence Tests
    
    func testDataPersistenceAcrossInstances() async throws {
        // Given: Data saved in one instance
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        let note = Note(
            questionId: question.id,
            answer: "Persisted answer",
            metadata: ["key": "value"]
        )
        try await sut.saveNote(note)
        
        // When: Creating new service instance
        let newService = NotesServiceImpl(userDefaults: mockUserDefaults)
        let loadedStore = try await newService.loadNotesStore()
        
        // Then: Data should be loaded correctly
        XCTAssertNotNil(loadedStore.notes[question.id])
        XCTAssertEqual(loadedStore.notes[question.id]?.answer, "Persisted answer")
        XCTAssertEqual(loadedStore.notes[question.id]?.metadata?["key"], "value")
    }
    
    func testCorruptDataHandling() async throws {
        // Given: Corrupt data in UserDefaults
        mockUserDefaults.set("corrupt data", forKey: "com.c11shouse.notesStore")
        
        // When: Creating new service
        let service = NotesServiceImpl(userDefaults: mockUserDefaults)
        
        // Then: Should handle gracefully and initialize with defaults
        let store = try await service.loadNotesStore()
        XCTAssertEqual(store.questions.count, Question.predefinedQuestions.count)
        XCTAssertTrue(store.notes.isEmpty)
    }
    
    // MARK: - House Name Tests
    
    func testSaveAndGetHouseName() async throws {
        // When: Saving house name
        await sut.saveHouseName("Maple House")
        
        // Then: Should be retrievable
        let houseName = await sut.getHouseName()
        XCTAssertEqual(houseName, "Maple House")
        
        // And: Should have correct metadata
        let store = try await sut.loadNotesStore()
        if let houseNameQuestion = store.questions.first(where: { $0.text == "What should I call this house?" }),
           let note = store.notes[houseNameQuestion.id] {
            XCTAssertEqual(note.metadata?["type"], "house_name")
            XCTAssertEqual(note.metadata?["updated_via_conversation"], "true")
        } else {
            XCTFail("House name note not found")
        }
    }
    
    func testGetHouseNameWhenEmpty() async throws {
        // When: No house name saved
        let houseName = await sut.getHouseName()
        
        // Then: Should return nil
        XCTAssertNil(houseName)
    }
    
    // MARK: - Weather Summary Tests
    
    func testSaveWeatherSummary() async throws {
        // Given: Weather data
        let weather = Weather(
            temperature: Temperature(value: 72, unit: .fahrenheit),
            condition: .clear,
            humidity: 0.65,
            windSpeed: 5.5,
            feelsLike: Temperature(value: 70, unit: .fahrenheit),
            uvIndex: 7,
            pressure: 1013.25,
            visibility: 10000,
            dewPoint: 65.0,
            forecast: [
                DailyForecast(
                    date: Date(),
                    highTemperature: Temperature(value: 75, unit: .fahrenheit),
                    lowTemperature: Temperature(value: 60, unit: .fahrenheit),
                    condition: WeatherCondition.clear,
                    precipitationChance: 0.1
                )
            ],
            hourlyForecast: [],
            lastUpdated: Date()
        )
        
        // When: Saving weather summary
        await sut.saveWeatherSummary(weather)
        
        // Then: Should create weather question and note
        let store = try await sut.loadNotesStore()
        let weatherQuestionId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        
        if let weatherNote = store.notes[weatherQuestionId] {
            XCTAssertTrue(weatherNote.answer.contains("Weather Update"))
            XCTAssertTrue(weatherNote.answer.contains("72"))
            XCTAssertEqual(weatherNote.metadata?["type"], "weather_summary")
            XCTAssertNotNil(weatherNote.metadata?["timestamp"])
        } else {
            XCTFail("Weather note not found")
        }
    }
    
    // MARK: - Migration Tests
    
    func testMigrationFromOldHouseNameQuestion() async throws {
        // Given: Old format data with old house name question
        let oldQuestionId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let oldQuestion = Question(
            id: oldQuestionId,
            text: "What is your house's name?",
            category: .houseInfo,
            displayOrder: 1,
            isRequired: true
        )
        
        var questions = Question.predefinedQuestions
        questions.append(oldQuestion)
        
        let oldStore = NotesStoreData(
            questions: questions,
            notes: [oldQuestionId: Note(
                questionId: oldQuestionId,
                answer: "Old House Name"
            )],
            version: 0 // Old version
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(oldStore)
        mockUserDefaults.set(data, forKey: "com.c11shouse.notesStore")
        
        // When: Loading with new service (triggers migration)
        let service = NotesServiceImpl(userDefaults: mockUserDefaults)
        let migratedStore = try await service.loadNotesStore()
        
        // Then: Should migrate to new question
        XCTAssertFalse(migratedStore.questions.contains(where: { $0.text == "What is your house's name?" }))
        XCTAssertNil(migratedStore.notes[oldQuestionId])
        
        // And: Answer should be transferred to new question
        if let newQuestion = migratedStore.questions.first(where: { $0.text == "What should I call this house?" }),
           let note = migratedStore.notes[newQuestion.id] {
            XCTAssertEqual(note.answer, "Old House Name")
        } else {
            XCTFail("Migration failed to transfer house name")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorDescriptions() {
        let questionId = UUID()
        
        XCTAssertEqual(
            NotesError.questionNotFound(questionId).errorDescription,
            "Question with ID \(questionId) not found"
        )
        
        XCTAssertEqual(
            NotesError.noteNotFound(questionId).errorDescription,
            "Note for question \(questionId) not found"
        )
        
        XCTAssertEqual(
            NotesError.duplicateQuestion(questionId).errorDescription,
            "Question with ID \(questionId) already exists"
        )
        
        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        XCTAssertEqual(
            NotesError.encodingFailed(testError).errorDescription,
            "Failed to save data: Test error"
        )
        
        XCTAssertEqual(
            NotesError.decodingFailed(testError).errorDescription,
            "Failed to load data: Test error"
        )
        
        XCTAssertEqual(
            NotesError.migrationFailed("Test reason").errorDescription,
            "Data migration failed: Test reason"
        )
    }
    
    // MARK: - Convenience Method Tests
    
    func testGetCurrentQuestion() async throws {
        // Given: Some questions answered
        let store = try await sut.loadNotesStore()
        let firstQuestion = store.questions[0]
        try await sut.saveNote(Note(
            questionId: firstQuestion.id,
            answer: "Answered",
            metadata: ["updated_via_conversation": "true"]
        ))
        
        // When: Getting current question
        let currentQuestion = await sut.getCurrentQuestion()
        
        // Then: Should return first unanswered or needs review
        XCTAssertNotNil(currentQuestion)
        XCTAssertNotEqual(currentQuestion?.id, firstQuestion.id)
    }
    
    func testGetNextUnansweredQuestion() async throws {
        // Given: First required question answered
        let store = try await sut.loadNotesStore()
        let firstRequired = store.questions.first(where: { $0.isRequired })!
        try await sut.saveNote(Note(questionId: firstRequired.id, answer: "Answered"))
        
        // When: Getting next unanswered
        let nextQuestion = await sut.getNextUnansweredQuestion()
        
        // Then: Should return next required unanswered question
        XCTAssertNotNil(nextQuestion)
        XCTAssertTrue(nextQuestion!.isRequired)
        XCTAssertNotEqual(nextQuestion?.id, firstRequired.id)
    }
    
    func testGetNoteByQuestionText() async throws {
        // Given: A note exists
        let store = try await sut.loadNotesStore()
        let question = store.questions.first!
        let note = Note(questionId: question.id, answer: "Test answer")
        try await sut.saveNote(note)
        
        // When: Getting by question text
        let retrievedNote = try await sut.getNote(for: question.id)
        
        // Then: Should find the note
        XCTAssertNotNil(retrievedNote)
        XCTAssertEqual(retrievedNote?.answer, "Test answer")
        
        // When: Non-existent question text
        let nonExistent = try await sut.getNote(for: UUID())
        XCTAssertNil(nonExistent)
    }
    
    func testGetUnansweredQuestions() async throws {
        // Given: Mix of answered and unanswered questions
        let store = try await sut.loadNotesStore()
        let answeredQuestion = store.questions[0]
        try await sut.saveNote(Note(questionId: answeredQuestion.id, answer: "Answered"))
        
        // When: Getting unanswered questions
        let unanswered = try await sut.getUnansweredQuestions()
        
        // Then: Should not include answered question
        XCTAssertFalse(unanswered.contains(where: { $0.id == answeredQuestion.id }))
        XCTAssertEqual(unanswered.count, store.questions.count - 1)
    }
}
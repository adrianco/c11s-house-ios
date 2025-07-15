/*
 * CONTEXT & PURPOSE:
 * Unit tests for ConversationStateManager to ensure proper state management,
 * transcript handling, TTS coordination, and user preferences.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Initial test implementation
 *   - Test all public methods and state changes
 *   - Mock dependencies (NotesService, TTSService)
 *   - Verify async behavior and state updates
 *   - Test error handling scenarios
 *
 * FUTURE UPDATES:
 * - Add performance tests for large transcripts
 * - Test concurrent access patterns
 */

import XCTest
import Combine
@testable import C11SHouse

@MainActor
class ConversationStateManagerTests: XCTestCase {
    var sut: ConversationStateManager!
    var mockNotesService: SharedMockNotesService!
    var mockTTSService: MockTTSService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        mockNotesService = SharedMockNotesService()
        mockTTSService = MockTTSService()
        sut = ConversationStateManager(
            notesService: mockNotesService,
            ttsService: mockTTSService
        )
        cancellables = []
    }
    
    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        mockTTSService = nil
        mockNotesService = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(sut.persistentTranscript, "")
        XCTAssertFalse(sut.isEditing)
        XCTAssertEqual(sut.currentSessionStart, "")
        XCTAssertTrue(sut.isNewSession)
        XCTAssertEqual(sut.userName, "")
        XCTAssertFalse(sut.isSavingAnswer)
        XCTAssertFalse(sut.hasPlayedInitialThought)
    }
    
    // MARK: - User Name Tests
    
    func testLoadUserName_WithSavedName() async throws {
        // Given
        let expectedName = "John Doe"
        let nameQuestion = Question(
            id: UUID(),
            text: "What's your name?",
            category: .personal,
            displayOrder: 1,
            isRequired: true
        )
        let nameNote = Note(
            questionId: nameQuestion.id,
            answer: expectedName,
            metadata: nil
        )
        
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: [nameQuestion],
            notes: [nameQuestion.id: nameNote],
            version: 1
        )
        
        // When
        await sut.loadUserName()
        
        // Then
        XCTAssertEqual(sut.userName, expectedName)
        XCTAssertTrue(mockNotesService.loadNotesStoreCalled)
    }
    
    func testLoadUserName_WithNoSavedName() async {
        // Given
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: Question.predefinedQuestions,
            notes: [:],
            version: 1
        )
        
        // When
        await sut.loadUserName()
        
        // Then
        XCTAssertEqual(sut.userName, "")
    }
    
    func testUpdateUserName() async throws {
        // Given
        let newName = "Jane Smith"
        let nameQuestion = Question(
            id: UUID(),
            text: "What's your name?",
            category: .personal,
            displayOrder: 1,
            isRequired: true
        )
        
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: [nameQuestion],
            notes: [:],
            version: 1
        )
        
        // When
        await sut.updateUserName(newName)
        
        // Then
        XCTAssertEqual(sut.userName, newName)
        XCTAssertEqual(mockNotesService.savedNotes.count, 1)
        XCTAssertEqual(mockNotesService.savedNotes.first?.answer, newName)
        XCTAssertEqual(mockNotesService.savedNotes.first?.metadata?["updated_via_conversation"], "true")
    }
    
    // MARK: - Transcript Management Tests
    
    func testStartNewRecordingSession() {
        // Given
        sut.persistentTranscript = "Previous content"
        sut.isNewSession = false
        
        // When
        sut.startNewRecordingSession()
        
        // Then
        XCTAssertEqual(sut.currentSessionStart, "Previous content")
        XCTAssertTrue(sut.isNewSession)
    }
    
    func testUpdateTranscript_FirstUpdate() {
        // Given
        sut.currentSessionStart = "Hello"
        sut.isNewSession = true
        
        // When
        sut.updateTranscript(with: "world")
        
        // Then
        XCTAssertEqual(sut.persistentTranscript, "Hello world")
        XCTAssertFalse(sut.isNewSession)
    }
    
    func testUpdateTranscript_SubsequentUpdate() {
        // Given
        sut.currentSessionStart = "Hello"
        sut.isNewSession = false
        sut.persistentTranscript = "Hello world"
        
        // When
        sut.updateTranscript(with: "everyone")
        
        // Then
        XCTAssertEqual(sut.persistentTranscript, "Hello everyone")
    }
    
    func testUpdateTranscript_EmptySessionStart() {
        // Given
        sut.currentSessionStart = ""
        sut.isNewSession = true
        
        // When
        sut.updateTranscript(with: "Hello")
        
        // Then
        XCTAssertEqual(sut.persistentTranscript, "Hello")
        XCTAssertFalse(sut.isNewSession)
    }
    
    func testClearTranscript() {
        // Given
        sut.persistentTranscript = "Some content"
        sut.currentSessionStart = "Some"
        sut.isNewSession = false
        
        // When
        sut.clearTranscript()
        
        // Then
        XCTAssertEqual(sut.persistentTranscript, "")
        XCTAssertEqual(sut.currentSessionStart, "")
        XCTAssertTrue(sut.isNewSession)
    }
    
    func testToggleEditing() {
        // Given
        XCTAssertFalse(sut.isEditing)
        
        // When
        sut.toggleEditing()
        
        // Then
        XCTAssertTrue(sut.isEditing)
        
        // When
        sut.toggleEditing()
        
        // Then
        XCTAssertFalse(sut.isEditing)
    }
    
    // MARK: - TTS Tests
    
    func testSpeak_WhenNotMuted() async {
        // Given
        let text = "Hello world"
        
        // When
        await sut.speak(text, isMuted: false)
        
        // Then
        XCTAssertTrue(mockTTSService.speakCalled)
        XCTAssertEqual(mockTTSService.lastSpokenText, text)
    }
    
    func testSpeak_WhenMuted() async {
        // Given
        let text = "Hello world"
        
        // When
        await sut.speak(text, isMuted: true)
        
        // Then
        XCTAssertFalse(mockTTSService.speakCalled)
    }
    
    func testSpeak_WhenAlreadySpeaking() async {
        // Given
        mockTTSService.isSpeaking = true
        let text = "Hello world"
        
        // When
        await sut.speak(text, isMuted: false)
        
        // Then
        XCTAssertFalse(mockTTSService.speakCalled)
    }
    
    func testSpeak_WhenSavingAnswer() async {
        // Given
        sut.beginSavingAnswer()
        let text = "Hello world"
        
        // When
        await sut.speak(text, isMuted: false)
        
        // Then
        XCTAssertFalse(mockTTSService.speakCalled)
    }
    
    func testSpeak_WithError() async {
        // Given
        mockTTSService.speakError = TTSError.speechInterrupted
        let text = "Hello world"
        
        // When
        await sut.speak(text, isMuted: false)
        
        // Then
        XCTAssertTrue(mockTTSService.speakCalled)
        // Should not crash - error is handled
    }
    
    func testStopSpeaking() {
        // When
        sut.stopSpeaking()
        
        // Then
        XCTAssertFalse(mockTTSService.isSpeaking)
    }
    
    func testIsSpeaking() {
        // Given
        mockTTSService.isSpeaking = true
        
        // Then
        XCTAssertTrue(sut.isSpeaking)
        
        // Given
        mockTTSService.isSpeaking = false
        
        // Then
        XCTAssertFalse(sut.isSpeaking)
    }
    
    // MARK: - Display Tests
    
    func testGetTranscriptHeader_WithUserName() {
        // Given
        sut.userName = "John"
        
        // When
        let header = sut.getTranscriptHeader()
        
        // Then
        XCTAssertEqual(header, "John's Response:")
    }
    
    func testGetTranscriptHeader_WithoutUserName() {
        // Given
        sut.userName = ""
        
        // When
        let header = sut.getTranscriptHeader()
        
        // Then
        XCTAssertEqual(header, "Real-time Transcript:")
    }
    
    // MARK: - Save State Tests
    
    func testBeginAndEndSavingAnswer() {
        // Given
        XCTAssertFalse(sut.isSavingAnswer)
        
        // When
        sut.beginSavingAnswer()
        
        // Then
        XCTAssertTrue(sut.isSavingAnswer)
        
        // When
        sut.endSavingAnswer()
        
        // Then
        XCTAssertFalse(sut.isSavingAnswer)
    }
    
    // MARK: - Session Tests
    
    func testResetSession() {
        // Given
        sut.persistentTranscript = "Content"
        sut.currentSessionStart = "Content"
        sut.isNewSession = false
        sut.isEditing = true
        sut.isSavingAnswer = true
        sut.hasPlayedInitialThought = true
        
        // When
        sut.resetSession()
        
        // Then
        XCTAssertEqual(sut.persistentTranscript, "")
        XCTAssertEqual(sut.currentSessionStart, "")
        XCTAssertTrue(sut.isNewSession)
        XCTAssertFalse(sut.isEditing)
        XCTAssertFalse(sut.isSavingAnswer)
        XCTAssertFalse(sut.hasPlayedInitialThought)
    }
    
    // MARK: - House Thought Tests
    
    func testSpeakHouseThought_WithThoughtOnly() async {
        // Given
        let thought = HouseThought(
            thought: "I understand",
            emotion: .thoughtful,
            category: .observation,
            confidence: 0.9
        )
        
        // When
        await sut.speakHouseThought(thought, isMuted: false)
        
        // Then
        XCTAssertTrue(mockTTSService.speakCalled)
        XCTAssertEqual(mockTTSService.lastSpokenText, "I understand")
    }
    
    func testSpeakHouseThought_WithSuggestion() async {
        // Given
        let thought = HouseThought(
            thought: "I understand",
            emotion: .thoughtful,
            category: .observation,
            confidence: 0.9,
            suggestion: "Try this approach"
        )
        
        // When
        await sut.speakHouseThought(thought, isMuted: false)
        
        // Then
        // Should speak both thought and suggestion
        XCTAssertTrue(mockTTSService.speakCalled)
    }
    
    func testSpeakHouseThought_WhenMuted() async {
        // Given
        let thought = HouseThought(
            thought: "I understand",
            emotion: .thoughtful,
            category: .observation,
            confidence: 0.9
        )
        
        // When
        await sut.speakHouseThought(thought, isMuted: true)
        
        // Then
        XCTAssertFalse(mockTTSService.speakCalled)
    }
    
    func testSpeakHouseThought_WithNil() async {
        // When
        await sut.speakHouseThought(nil, isMuted: false)
        
        // Then
        XCTAssertFalse(mockTTSService.speakCalled)
    }
    
    // MARK: - Session Update Tests
    
    func testUpdateTranscriptFromSession_MatchingSession() {
        // Given
        sut.currentSessionStart = "Hello"
        sut.persistentTranscript = "Hello"
        sut.isNewSession = false
        
        // When
        sut.updateTranscriptFromSession("world", at: "Hello", isFinal: true)
        
        // Then
        XCTAssertEqual(sut.persistentTranscript, "Hello world")
    }
    
    func testUpdateTranscriptFromSession_DifferentSession() {
        // Given
        sut.currentSessionStart = "Hello"
        sut.persistentTranscript = "Hello"
        
        // When
        sut.updateTranscriptFromSession("world", at: "Different", isFinal: true)
        
        // Then
        XCTAssertEqual(sut.persistentTranscript, "Hello") // Should not change
    }
    
    func testCurrentSessionStartIndex() {
        // Given
        sut.currentSessionStart = "Test session"
        
        // Then
        XCTAssertEqual(sut.currentSessionStartIndex, "Test session")
    }
    
    // MARK: - State Publishing Tests
    
    func testPublishedPropertiesUpdate() {
        let expectation = XCTestExpectation(description: "Published property updates")
        var receivedValues: [String] = []
        
        sut.$persistentTranscript
            .dropFirst() // Skip initial value
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger updates
        sut.updateTranscript(with: "First")
        sut.updateTranscript(with: "Second")
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertTrue(receivedValues.contains("First"))
    }
}
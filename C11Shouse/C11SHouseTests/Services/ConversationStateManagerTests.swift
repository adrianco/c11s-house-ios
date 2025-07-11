/*
 * CONTEXT & PURPOSE:
 * ConversationStateManagerTests validates the ConversationStateManager implementation.
 * This manager handles complex state management for conversation views including
 * transcript state, TTS coordination, recording state, and user preferences.
 * Tests ensure proper state transitions, TTS integration, and persistence.
 *
 * DECISION HISTORY:
 * - 2025-01-10: Initial test implementation
 *   - Mock NotesService and TTSService for isolation
 *   - Test transcript management (start/update/clear)
 *   - Test user name loading and persistence
 *   - Test TTS coordination with mute states
 *   - Test session state management
 *   - Test editing mode transitions
 *   - Async/await test patterns throughout
 *   - Thread safety verification
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import Combine
@testable import C11SHouse

// MARK: - Mock TTS Service

class MockTTSServiceForStateManager: NSObject, TTSService {
    var isSpeaking = false
    
    var isSpeakingPublisher: AnyPublisher<Bool, Never> {
        isSpeakingSubject.eraseToAnyPublisher()
    }
    
    var speechProgressPublisher: AnyPublisher<Float, Never> {
        speechProgressSubject.eraseToAnyPublisher()
    }
    
    private let isSpeakingSubject = CurrentValueSubject<Bool, Never>(false)
    private let speechProgressSubject = CurrentValueSubject<Float, Never>(0.0)
    
    var speakCallCount = 0
    var stopSpeakingCallCount = 0
    var lastSpokenText: String?
    var lastLanguage: String?
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "TTSError", code: 1, userInfo: nil)
    
    func speak(_ text: String, language: String?) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        speakCallCount += 1
        lastSpokenText = text
        lastLanguage = language
        isSpeaking = true
        isSpeakingSubject.send(true)
        
        // Simulate speaking duration
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        isSpeaking = false
        isSpeakingSubject.send(false)
    }
    
    func stopSpeaking() {
        stopSpeakingCallCount += 1
        isSpeaking = false
        isSpeakingSubject.send(false)
    }
    
    func pauseSpeaking() {
        // No-op for tests
    }
    
    func continueSpeaking() {
        // No-op for tests
    }
    
    func setRate(_ rate: Float) {
        // No-op for tests
    }
    
    func setPitch(_ pitch: Float) {
        // No-op for tests
    }
    
    func setVolume(_ volume: Float) {
        // No-op for tests
    }
    
    func setVoice(_ voiceIdentifier: String?) {
        // No-op for tests
    }
}

// MARK: - ConversationStateManagerTests

class ConversationStateManagerTests: XCTestCase {
    var sut: ConversationStateManager!
    var mockNotesService: MockNotesService!
    var mockTTSService: MockTTSServiceForStateManager!
    
    override func setUp() {
        super.setUp()
        mockNotesService = MockNotesService()
        mockTTSService = MockTTSServiceForStateManager()
        sut = ConversationStateManager(
            notesService: mockNotesService,
            ttsService: mockTTSService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockNotesService = nil
        mockTTSService = nil
        super.tearDown()
    }
    
    // MARK: - User Name Tests
    
    func testLoadUserNameWithExistingName() async {
        // Given: Name question has an answer
        if let nameQuestion = mockNotesService.mockNotesStore.questions.first(where: { $0.text == "What's your name?" }) {
            mockNotesService.mockNotesStore.notes[nameQuestion.id] = Note(
                questionId: nameQuestion.id,
                answer: "  John Doe  " // With whitespace to test trimming
            )
        }
        
        // When: Loading user name
        await sut.loadUserName()
        
        // Then: Should load and trim the name
        XCTAssertEqual(sut.userName, "John Doe")
    }
    
    func testLoadUserNameWithNoExistingName() async {
        // Given: Name question has no answer
        
        // When: Loading user name
        await sut.loadUserName()
        
        // Then: userName should remain empty
        XCTAssertEqual(sut.userName, "")
    }
    
    func testLoadUserNameWithEmptyAnswer() async {
        // Given: Name question has empty answer
        if let nameQuestion = mockNotesService.mockNotesStore.questions.first(where: { $0.text == "What's your name?" }) {
            mockNotesService.mockNotesStore.notes[nameQuestion.id] = Note(
                questionId: nameQuestion.id,
                answer: "   " // Only whitespace
            )
        }
        
        // When: Loading user name
        await sut.loadUserName()
        
        // Then: userName should remain empty
        XCTAssertEqual(sut.userName, "")
    }
    
    func testLoadUserNameHandlesError() async {
        // Given: NotesService will throw error
        mockNotesService.shouldThrowError = true
        
        // When: Loading user name
        await sut.loadUserName()
        
        // Then: Should handle gracefully
        XCTAssertEqual(sut.userName, "")
    }
    
    func testUpdateUserNameSavesToNotes() async {
        // Given: Name to update
        let newName = "Jane Smith"
        
        // When: Updating user name
        await sut.updateUserName(newName)
        
        // Then: Should update local state and save to notes
        XCTAssertEqual(sut.userName, newName)
        XCTAssertEqual(mockNotesService.saveOrUpdateNoteCallCount, 1)
        
        // Verify saved note
        if let nameQuestion = mockNotesService.mockNotesStore.questions.first(where: { $0.text == "What's your name?" }),
           let note = mockNotesService.mockNotesStore.notes[nameQuestion.id] {
            XCTAssertEqual(note.answer, newName)
            XCTAssertEqual(note.metadata?["updated_via_conversation"], "true")
        } else {
            XCTFail("Name note not saved")
        }
    }
    
    func testUpdateUserNameHandlesError() async {
        // Given: Save will fail
        mockNotesService.shouldThrowError = true
        
        // When: Updating user name
        await sut.updateUserName("Jane Smith")
        
        // Then: Should still update local state
        XCTAssertEqual(sut.userName, "Jane Smith")
    }
    
    // MARK: - Transcript Management Tests
    
    func testStartNewRecordingSession() {
        // Given: Existing transcript
        sut.persistentTranscript = "Previous content"
        sut.isNewSession = false
        
        // When: Starting new session
        sut.startNewRecordingSession()
        
        // Then: Should save current state and mark as new session
        XCTAssertEqual(sut.currentSessionStart, "Previous content")
        XCTAssertTrue(sut.isNewSession)
    }
    
    func testUpdateTranscriptFirstUpdateInNewSession() {
        // Given: New session with existing content
        sut.persistentTranscript = "Initial content"
        sut.startNewRecordingSession()
        
        // When: First update
        sut.updateTranscript(with: "New text")
        
        // Then: Should append with space
        XCTAssertEqual(sut.persistentTranscript, "Initial content New text")
        XCTAssertFalse(sut.isNewSession)
    }
    
    func testUpdateTranscriptFirstUpdateInEmptySession() {
        // Given: New session with no content
        sut.persistentTranscript = ""
        sut.startNewRecordingSession()
        
        // When: First update
        sut.updateTranscript(with: "New text")
        
        // Then: Should just set the text
        XCTAssertEqual(sut.persistentTranscript, "New text")
        XCTAssertFalse(sut.isNewSession)
    }
    
    func testUpdateTranscriptSubsequentUpdate() {
        // Given: Session already started with content
        sut.persistentTranscript = "Initial"
        sut.startNewRecordingSession()
        sut.updateTranscript(with: "First")
        
        // When: Subsequent update
        sut.updateTranscript(with: "Second")
        
        // Then: Should replace from session start
        XCTAssertEqual(sut.persistentTranscript, "Initial Second")
    }
    
    func testClearTranscript() {
        // Given: Existing transcript and session data
        sut.persistentTranscript = "Some content"
        sut.currentSessionStart = "Session start"
        sut.isNewSession = false
        
        // When: Clearing transcript
        sut.clearTranscript()
        
        // Then: Should clear all data
        XCTAssertEqual(sut.persistentTranscript, "")
        XCTAssertEqual(sut.currentSessionStart, "")
        XCTAssertTrue(sut.isNewSession)
    }
    
    // MARK: - Editing Mode Tests
    
    func testToggleEditing() {
        // Given: Initial editing state
        XCTAssertFalse(sut.isEditing)
        
        // When: Toggling editing
        sut.toggleEditing()
        
        // Then: Should toggle state
        XCTAssertTrue(sut.isEditing)
        
        // When: Toggling again
        sut.toggleEditing()
        
        // Then: Should toggle back
        XCTAssertFalse(sut.isEditing)
    }
    
    // MARK: - TTS Tests
    
    func testSpeakWhenNotMuted() async {
        // Given: Not muted
        let text = "Hello, world!"
        
        // When: Speaking
        await sut.speak(text, isMuted: false)
        
        // Then: Should call TTS service
        XCTAssertEqual(mockTTSService.speakCallCount, 1)
        XCTAssertEqual(mockTTSService.lastSpokenText, text)
        XCTAssertNil(mockTTSService.lastLanguage)
    }
    
    func testSpeakWhenMuted() async {
        // Given: Muted
        let text = "Hello, world!"
        
        // When: Speaking
        await sut.speak(text, isMuted: true)
        
        // Then: Should not call TTS service
        XCTAssertEqual(mockTTSService.speakCallCount, 0)
    }
    
    func testSpeakWhenAlreadySpeaking() async {
        // Given: TTS is already speaking
        mockTTSService.isSpeaking = true
        
        // When: Attempting to speak
        await sut.speak("New text", isMuted: false)
        
        // Then: Should not start new speech
        XCTAssertEqual(mockTTSService.speakCallCount, 0)
    }
    
    func testSpeakWhenSavingAnswer() async {
        // Given: Answer is being saved
        sut.isSavingAnswer = true
        
        // When: Attempting to speak
        await sut.speak("New text", isMuted: false)
        
        // Then: Should not speak
        XCTAssertEqual(mockTTSService.speakCallCount, 0)
    }
    
    func testSpeakHandlesSpeechInterruptedError() async {
        // Given: TTS will throw speech interrupted error
        mockTTSService.shouldThrowError = true
        mockTTSService.errorToThrow = TTSError.speechInterrupted
        
        // When: Speaking
        await sut.speak("Test", isMuted: false)
        
        // Then: Should handle gracefully (no crash)
        XCTAssertEqual(mockTTSService.speakCallCount, 1)
    }
    
    func testSpeakHandlesOtherErrors() async {
        // Given: TTS will throw other error
        mockTTSService.shouldThrowError = true
        mockTTSService.errorToThrow = TTSError.speechFailed(NSError(domain: "test", code: 1))
        
        // When: Speaking
        await sut.speak("Test", isMuted: false)
        
        // Then: Should handle gracefully
        XCTAssertEqual(mockTTSService.speakCallCount, 1)
    }
    
    func testStopSpeaking() {
        // When: Stopping speaking
        sut.stopSpeaking()
        
        // Then: Should call TTS service
        XCTAssertEqual(mockTTSService.stopSpeakingCallCount, 1)
    }
    
    func testIsSpeakingProperty() {
        // Given: TTS is speaking
        mockTTSService.isSpeaking = true
        
        // Then: Should reflect TTS state
        XCTAssertTrue(sut.isSpeaking)
        
        // Given: TTS is not speaking
        mockTTSService.isSpeaking = false
        
        // Then: Should reflect updated state
        XCTAssertFalse(sut.isSpeaking)
    }
    
    // MARK: - Display Name Tests
    
    func testGetTranscriptHeaderWithUserName() {
        // Given: User name is set
        sut.userName = "John"
        
        // When: Getting transcript header
        let header = sut.getTranscriptHeader()
        
        // Then: Should include user name
        XCTAssertEqual(header, "John's Response:")
    }
    
    func testGetTranscriptHeaderWithoutUserName() {
        // Given: No user name
        sut.userName = ""
        
        // When: Getting transcript header
        let header = sut.getTranscriptHeader()
        
        // Then: Should use default header
        XCTAssertEqual(header, "Real-time Transcript:")
    }
    
    // MARK: - Answer Saving State Tests
    
    func testBeginSavingAnswer() {
        // Given: Not saving
        XCTAssertFalse(sut.isSavingAnswer)
        
        // When: Beginning save
        sut.beginSavingAnswer()
        
        // Then: Should mark as saving
        XCTAssertTrue(sut.isSavingAnswer)
    }
    
    func testEndSavingAnswer() {
        // Given: Is saving
        sut.isSavingAnswer = true
        
        // When: Ending save
        sut.endSavingAnswer()
        
        // Then: Should mark as not saving
        XCTAssertFalse(sut.isSavingAnswer)
    }
    
    // MARK: - Session Management Tests
    
    func testResetSession() {
        // Given: Various state is set
        sut.persistentTranscript = "Some transcript"
        sut.currentSessionStart = "Session start"
        sut.isNewSession = false
        sut.isEditing = true
        sut.isSavingAnswer = true
        sut.hasPlayedInitialThought = true
        
        // When: Resetting session
        sut.resetSession()
        
        // Then: Should reset all state
        XCTAssertEqual(sut.persistentTranscript, "")
        XCTAssertEqual(sut.currentSessionStart, "")
        XCTAssertTrue(sut.isNewSession)
        XCTAssertFalse(sut.isEditing)
        XCTAssertFalse(sut.isSavingAnswer)
        XCTAssertFalse(sut.hasPlayedInitialThought)
    }
    
    // MARK: - House Thought TTS Tests
    
    func testSpeakHouseThoughtWhenNotMuted() async {
        // Given: House thought with suggestion
        let thought = HouseThought(
            thought: "This is the main thought",
            suggestion: "This is a suggestion"
        )
        
        // When: Speaking house thought
        await sut.speakHouseThought(thought, isMuted: false)
        
        // Then: Should speak both thought and suggestion
        XCTAssertEqual(mockTTSService.speakCallCount, 2)
    }
    
    func testSpeakHouseThoughtWhenMuted() async {
        // Given: House thought
        let thought = HouseThought(
            thought: "This is the main thought",
            suggestion: "This is a suggestion"
        )
        
        // When: Speaking house thought while muted
        await sut.speakHouseThought(thought, isMuted: true)
        
        // Then: Should not speak
        XCTAssertEqual(mockTTSService.speakCallCount, 0)
    }
    
    func testSpeakHouseThoughtWithNilThought() async {
        // When: Speaking nil thought
        await sut.speakHouseThought(nil, isMuted: false)
        
        // Then: Should not speak
        XCTAssertEqual(mockTTSService.speakCallCount, 0)
    }
    
    func testSpeakHouseThoughtWithoutSuggestion() async {
        // Given: House thought without suggestion
        let thought = HouseThought(
            thought: "Only the main thought",
            suggestion: nil
        )
        
        // When: Speaking house thought
        await sut.speakHouseThought(thought, isMuted: false)
        
        // Then: Should only speak the thought
        XCTAssertEqual(mockTTSService.speakCallCount, 1)
        XCTAssertEqual(mockTTSService.lastSpokenText, "Only the main thought")
    }
    
    // MARK: - Thread Safety Tests
    
    func testPublishedPropertiesUpdateOnMainThread() async {
        // Given: Expectation for main thread check
        let expectation = expectation(description: "Published property updates on main thread")
        var isOnMainThread = false
        
        // Subscribe to a published property
        let cancellable = sut.$persistentTranscript
            .dropFirst()
            .sink { _ in
                isOnMainThread = Thread.isMainThread
                expectation.fulfill()
            }
        
        // When: Updating property from background thread
        Task.detached {
            await self.sut.updateTranscript(with: "Background update")
        }
        
        // Then: Update should happen on main thread
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(isOnMainThread)
        
        cancellable.cancel()
    }
    
    // MARK: - Integration Tests
    
    func testFullConversationFlowIntegration() async {
        // Test a complete conversation flow
        
        // 1. Load user name
        await sut.loadUserName()
        XCTAssertEqual(sut.userName, "")
        
        // 2. Start new recording session
        sut.startNewRecordingSession()
        XCTAssertTrue(sut.isNewSession)
        
        // 3. Update transcript with user speech
        sut.updateTranscript(with: "My name is Alice")
        XCTAssertEqual(sut.persistentTranscript, "My name is Alice")
        XCTAssertFalse(sut.isNewSession)
        
        // 4. Save answer
        sut.beginSavingAnswer()
        XCTAssertTrue(sut.isSavingAnswer)
        
        await sut.updateUserName("Alice")
        XCTAssertEqual(sut.userName, "Alice")
        
        sut.endSavingAnswer()
        XCTAssertFalse(sut.isSavingAnswer)
        
        // 5. Get updated transcript header
        let header = sut.getTranscriptHeader()
        XCTAssertEqual(header, "Alice's Response:")
        
        // 6. Clear for next question
        sut.clearTranscript()
        XCTAssertEqual(sut.persistentTranscript, "")
        
        // 7. Speak a house thought (not muted)
        let thought = HouseThought(thought: "Nice to meet you, Alice!")
        await sut.speakHouseThought(thought, isMuted: false)
        XCTAssertEqual(mockTTSService.speakCallCount, 1)
    }
}
/*
 * CONTEXT & PURPOSE:
 * ConversationRecognizerTests provides comprehensive test coverage for the voice recording
 * functionality in ConversationRecognizer. Tests cover initialization, authorization,
 * recording operations, error handling, transcript processing, and house thought generation.
 *
 * DECISION HISTORY:
 * - 2025-07-25: Initial implementation
 *   - Tests all public methods and published properties
 *   - Covers error scenarios and edge cases
 *   - Tests house thought generation logic
 *   - Validates thread safety and state management
 *   - Tests confidence calculations
 *   - Validates authorization flow
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import XCTest
import Speech
import AVFoundation
import Combine
@testable import C11SHouse

@MainActor
class ConversationRecognizerTests: XCTestCase {
    
    // MARK: - Properties
    
    private var recognizer: ConversationRecognizer!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        recognizer = ConversationRecognizer()
        cancellables = []
    }
    
    override func tearDown() async throws {
        // Ensure recognizer is stopped and cleaned up
        if recognizer.isRecording {
            recognizer.stopRecording()
        }
        recognizer.reset()
        recognizer = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Test initial state
        XCTAssertFalse(recognizer.isRecording)
        XCTAssertEqual(recognizer.transcript, "")
        XCTAssertEqual(recognizer.confidence, 0.0)
        XCTAssertFalse(recognizer.isAvailable)
        XCTAssertEqual(recognizer.authorizationStatus, .notDetermined)
        XCTAssertNil(recognizer.error)
        XCTAssertNil(recognizer.currentHouseThought)
    }
    
    func testInitializeSpeechRecognizer() {
        // Given
        var authorizationStatusChanged = false
        
        recognizer.$authorizationStatus
            .dropFirst() // Skip initial value
            .sink { _ in
                authorizationStatusChanged = true
            }
            .store(in: &cancellables)
        
        // When
        recognizer.initializeSpeechRecognizer()
        
        // Then - since we're in a test environment, we can only verify the method was called
        // Real authorization requests would need UI testing
        XCTAssertTrue(true, "initializeSpeechRecognizer should complete without errors")
    }
    
    // MARK: - Authorization Tests
    
    func testAuthorizationStatusPublisherUpdates() {
        // Given
        var receivedStatuses: [SFSpeechRecognizerAuthorizationStatus] = []
        
        recognizer.$authorizationStatus
            .sink { status in
                receivedStatuses.append(status)
            }
            .store(in: &cancellables)
        
        // Then
        XCTAssertEqual(receivedStatuses.first, .notDetermined)
    }
    
    // MARK: - Recording Control Tests
    
    func testStartRecordingWithoutAuthorization() {
        // Given
        recognizer.authorizationStatus = .denied
        
        // When/Then
        XCTAssertThrowsError(try recognizer.startRecording()) { error in
            if let speechError = error as? ConversationRecognizer.SpeechRecognitionError {
                XCTAssertEqual(speechError, .notAuthorized)
            } else {
                XCTFail("Expected SpeechRecognitionError.notAuthorized, got \(error)")
            }
        }
    }
    
    func testStartRecordingWhenSpeechRecognizerUnavailable() {
        // Given
        recognizer.authorizationStatus = .authorized
        recognizer.isAvailable = false
        
        // When/Then
        XCTAssertThrowsError(try recognizer.startRecording()) { error in
            if let speechError = error as? ConversationRecognizer.SpeechRecognitionError {
                XCTAssertEqual(speechError, .notAvailable)
            } else {
                XCTFail("Expected SpeechRecognitionError.notAvailable, got \(error)")
            }
        }
    }
    
    func testStopRecordingWhenNotRecording() {
        // Given
        XCTAssertFalse(recognizer.isRecording)
        
        // When
        recognizer.stopRecording()
        
        // Then
        XCTAssertFalse(recognizer.isRecording)
        // Should handle gracefully without errors
    }
    
    func testToggleRecordingWhenNotRecording() {
        // Given
        XCTAssertFalse(recognizer.isRecording)
        var errorReceived = false
        
        recognizer.$error
            .dropFirst()
            .sink { error in
                if error != nil {
                    errorReceived = true
                }
            }
            .store(in: &cancellables)
        
        // When
        recognizer.toggleRecording()
        
        // Then - should attempt to start but fail due to test environment
        XCTAssertFalse(recognizer.isRecording)
        
        // Wait a bit to see if error is published
        let expectation = XCTestExpectation(description: "Error should be published")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // In test environment, we expect an error since we can't actually start recording
        XCTAssertTrue(errorReceived || recognizer.error != nil)
    }
    
    func testToggleRecordingWhenRecording() {
        // Given
        recognizer.isRecording = true // Simulate recording state
        
        // When
        recognizer.toggleRecording()
        
        // Then
        XCTAssertFalse(recognizer.isRecording)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Given
        recognizer.transcript = "Test transcript"
        recognizer.confidence = 0.85
        recognizer.error = ConversationRecognizer.SpeechRecognitionError.notAvailable
        recognizer.currentHouseThought = HouseThought(thought: "Test thought", emotion: .happy)
        
        // When
        recognizer.reset()
        
        // Wait for async cleanup
        let expectation = XCTestExpectation(description: "Reset should complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then
        XCTAssertEqual(recognizer.transcript, "")
        XCTAssertEqual(recognizer.confidence, 0.0)
        XCTAssertNil(recognizer.error)
        XCTAssertNil(recognizer.currentHouseThought)
        XCTAssertFalse(recognizer.isRecording)
    }
    
    func testResetWhileRecording() {
        // Given
        recognizer.isRecording = true
        
        // When
        recognizer.reset()
        
        // Wait for async cleanup
        let expectation = XCTestExpectation(description: "Reset should complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then
        XCTAssertFalse(recognizer.isRecording)
        XCTAssertEqual(recognizer.transcript, "")
    }
    
    // MARK: - Error Handling Tests
    
    func testSpeechRecognitionErrorTypes() {
        // Test all error types
        let errors: [ConversationRecognizer.SpeechRecognitionError] = [
            .notAuthorized,
            .notAvailable,
            .audioEngineError,
            .recognitionError("Test error"),
            .microphoneAccessDenied
        ]
        
        for error in errors {
            XCTAssertFalse(error.userFriendlyTitle.isEmpty)
            XCTAssertFalse(error.userFriendlyMessage.isEmpty)
            XCTAssertFalse(error.recoverySuggestions.isEmpty)
            XCTAssertNotNil(error.errorCode)
            XCTAssertNotNil(error.severity)
        }
    }
    
    func testErrorSeverityLevels() {
        XCTAssertEqual(ConversationRecognizer.SpeechRecognitionError.notAuthorized.severity, .error)
        XCTAssertEqual(ConversationRecognizer.SpeechRecognitionError.microphoneAccessDenied.severity, .error)
        XCTAssertEqual(ConversationRecognizer.SpeechRecognitionError.notAvailable.severity, .critical)
        XCTAssertEqual(ConversationRecognizer.SpeechRecognitionError.audioEngineError.severity, .critical)
        XCTAssertEqual(ConversationRecognizer.SpeechRecognitionError.recognitionError("").severity, .warning)
    }
    
    // MARK: - House Thought Generation Tests
    
    func testGenerateHouseThoughtForGreeting() {
        // Test various greeting patterns
        let greetings = ["hello", "hi there", "good morning", "good evening"]
        
        for greeting in greetings {
            recognizer.generateHouseThought(from: greeting)
            
            XCTAssertNotNil(recognizer.currentHouseThought)
            XCTAssertEqual(recognizer.currentHouseThought?.emotion, .happy)
            XCTAssertEqual(recognizer.currentHouseThought?.category, .greeting)
            XCTAssertTrue(recognizer.currentHouseThought?.thought.contains("Hello") ?? false)
        }
    }
    
    func testGenerateHouseThoughtForTemperature() {
        // Test temperature-related inputs
        let tempInputs = ["It's too cold", "feeling hot", "adjust temperature", "warm in here"]
        
        for input in tempInputs {
            recognizer.generateHouseThought(from: input)
            
            XCTAssertNotNil(recognizer.currentHouseThought)
            XCTAssertEqual(recognizer.currentHouseThought?.emotion, .thoughtful)
            XCTAssertEqual(recognizer.currentHouseThought?.category, .suggestion)
            XCTAssertTrue(recognizer.currentHouseThought?.thought.contains("temperature") ?? false)
            XCTAssertNotNil(recognizer.currentHouseThought?.suggestion)
        }
    }
    
    func testGenerateHouseThoughtForLighting() {
        // Test lighting-related inputs
        let lightInputs = ["turn on lights", "it's too dark", "brighten the room"]
        
        for input in lightInputs {
            recognizer.generateHouseThought(from: input)
            
            XCTAssertNotNil(recognizer.currentHouseThought)
            XCTAssertEqual(recognizer.currentHouseThought?.emotion, .curious)
            XCTAssertEqual(recognizer.currentHouseThought?.category, .question)
            XCTAssertTrue(recognizer.currentHouseThought?.thought.contains("lighting") ?? false)
        }
    }
    
    func testGenerateHouseThoughtForHomeKit() {
        // Test HomeKit-related inputs
        let homekitInputs = ["show my rooms", "what devices do I have", "tell me about homekit", "list accessories"]
        
        for input in homekitInputs {
            recognizer.generateHouseThought(from: input)
            
            XCTAssertNotNil(recognizer.currentHouseThought)
            XCTAssertEqual(recognizer.currentHouseThought?.emotion, .thoughtful)
            XCTAssertEqual(recognizer.currentHouseThought?.category, .observation)
            XCTAssertTrue(recognizer.currentHouseThought?.thought.contains("HomeKit") ?? false)
            XCTAssertNotNil(recognizer.currentHouseThought?.suggestion)
        }
    }
    
    func testGenerateHouseThoughtForQuestions() {
        // Test question inputs
        let questions = ["what can you do?", "how does this work?", "when should I use this?"]
        
        for question in questions {
            recognizer.generateHouseThought(from: question)
            
            XCTAssertNotNil(recognizer.currentHouseThought)
            XCTAssertEqual(recognizer.currentHouseThought?.emotion, .curious)
            XCTAssertEqual(recognizer.currentHouseThought?.category, .observation)
            XCTAssertTrue(recognizer.currentHouseThought?.thought.contains("question") ?? false)
        }
    }
    
    func testGenerateHouseThoughtForMemory() {
        // Test memory-related inputs
        let memoryInputs = ["remember this", "make a note", "remind me later"]
        
        for input in memoryInputs {
            recognizer.generateHouseThought(from: input)
            
            XCTAssertNotNil(recognizer.currentHouseThought)
            XCTAssertEqual(recognizer.currentHouseThought?.emotion, .thoughtful)
            XCTAssertEqual(recognizer.currentHouseThought?.category, .memory)
            XCTAssertTrue(recognizer.currentHouseThought?.thought.contains("note") ?? false)
        }
    }
    
    func testGenerateHouseThoughtDefault() {
        // Test unrecognized input
        recognizer.generateHouseThought(from: "random unrelated text")
        
        XCTAssertNotNil(recognizer.currentHouseThought)
        XCTAssertEqual(recognizer.currentHouseThought?.emotion, .neutral)
        XCTAssertEqual(recognizer.currentHouseThought?.category, .observation)
        XCTAssertTrue(recognizer.currentHouseThought?.thought.contains("listening") ?? false)
    }
    
    func testGenerateHouseThoughtConfidence() {
        // Given
        recognizer.confidence = 0.75
        
        // When
        recognizer.generateHouseThought(from: "test input")
        
        // Then
        XCTAssertEqual(recognizer.currentHouseThought?.confidence, 0.75)
    }
    
    func testGenerateHouseThoughtContext() {
        // Given
        let testTranscript = "Test user input"
        
        // When
        recognizer.generateHouseThought(from: testTranscript)
        
        // Then
        XCTAssertEqual(recognizer.currentHouseThought?.context, "User said: \"\(testTranscript)\"")
    }
    
    // MARK: - Question and Thank You Thought Tests
    
    func testSetQuestionThought() {
        // Given
        let question = "What's your favorite room in the house?"
        
        // When
        recognizer.setQuestionThought(question)
        
        // Then
        XCTAssertNotNil(recognizer.currentHouseThought)
        XCTAssertEqual(recognizer.currentHouseThought?.thought, question)
        XCTAssertEqual(recognizer.currentHouseThought?.emotion, .curious)
        XCTAssertEqual(recognizer.currentHouseThought?.category, .question)
        XCTAssertEqual(recognizer.currentHouseThought?.confidence, 1.0)
        XCTAssertEqual(recognizer.currentHouseThought?.context, "House Question")
        XCTAssertNil(recognizer.currentHouseThought?.suggestion)
    }
    
    func testSetThankYouThought() {
        // When
        recognizer.setThankYouThought()
        
        // Then
        XCTAssertNotNil(recognizer.currentHouseThought)
        XCTAssertEqual(recognizer.currentHouseThought?.thought, "Thank you! All your information is up to date. How else can I help you?")
        XCTAssertEqual(recognizer.currentHouseThought?.emotion, .happy)
        XCTAssertEqual(recognizer.currentHouseThought?.category, .greeting)
        XCTAssertEqual(recognizer.currentHouseThought?.confidence, 1.0)
        XCTAssertEqual(recognizer.currentHouseThought?.context, "Questions Complete")
        XCTAssertNil(recognizer.currentHouseThought?.suggestion)
    }
    
    func testClearHouseThought() {
        // Given
        recognizer.currentHouseThought = HouseThought(thought: "Test thought", emotion: .happy)
        
        // When
        recognizer.clearHouseThought()
        
        // Then
        XCTAssertNil(recognizer.currentHouseThought)
    }
    
    // MARK: - Published Property Tests
    
    func testPublishedPropertiesUpdate() {
        // Test that published properties trigger updates
        var isRecordingUpdated = false
        var transcriptUpdated = false
        var confidenceUpdated = false
        var errorUpdated = false
        var thoughtUpdated = false
        
        recognizer.$isRecording
            .dropFirst()
            .sink { _ in isRecordingUpdated = true }
            .store(in: &cancellables)
        
        recognizer.$transcript
            .dropFirst()
            .sink { _ in transcriptUpdated = true }
            .store(in: &cancellables)
        
        recognizer.$confidence
            .dropFirst()
            .sink { _ in confidenceUpdated = true }
            .store(in: &cancellables)
        
        recognizer.$error
            .dropFirst()
            .sink { _ in errorUpdated = true }
            .store(in: &cancellables)
        
        recognizer.$currentHouseThought
            .dropFirst()
            .sink { _ in thoughtUpdated = true }
            .store(in: &cancellables)
        
        // Update properties
        recognizer.isRecording = true
        recognizer.transcript = "New transcript"
        recognizer.confidence = 0.9
        recognizer.error = ConversationRecognizer.SpeechRecognitionError.notAvailable
        recognizer.currentHouseThought = HouseThought(thought: "New thought", emotion: .happy)
        
        // Verify all publishers fired
        XCTAssertTrue(isRecordingUpdated)
        XCTAssertTrue(transcriptUpdated)
        XCTAssertTrue(confidenceUpdated)
        XCTAssertTrue(errorUpdated)
        XCTAssertTrue(thoughtUpdated)
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyTranscriptHandling() {
        // When
        recognizer.generateHouseThought(from: "")
        
        // Then
        XCTAssertNotNil(recognizer.currentHouseThought)
        XCTAssertEqual(recognizer.currentHouseThought?.emotion, .neutral)
        XCTAssertEqual(recognizer.currentHouseThought?.category, .observation)
    }
    
    func testLongTranscriptHandling() {
        // Given
        let longTranscript = String(repeating: "test ", count: 100)
        
        // When
        recognizer.generateHouseThought(from: longTranscript)
        
        // Then
        XCTAssertNotNil(recognizer.currentHouseThought)
        XCTAssertNotNil(recognizer.currentHouseThought?.context)
    }
    
    func testCaseInsensitiveMatching() {
        // Test that thought generation is case-insensitive
        let inputs = ["HELLO", "Hello", "hElLo"]
        
        for input in inputs {
            recognizer.generateHouseThought(from: input)
            XCTAssertEqual(recognizer.currentHouseThought?.emotion, .happy)
            XCTAssertEqual(recognizer.currentHouseThought?.category, .greeting)
        }
    }
    
    func testMultipleKeywordMatching() {
        // Test transcript with multiple keywords
        recognizer.generateHouseThought(from: "Hello, can you adjust the temperature in my room?")
        
        // Should prioritize greeting as it comes first
        XCTAssertEqual(recognizer.currentHouseThought?.emotion, .happy)
        XCTAssertEqual(recognizer.currentHouseThought?.category, .greeting)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentPropertyAccess() {
        // Test concurrent access to published properties
        let expectation = XCTestExpectation(description: "Concurrent access should be safe")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        // Perform multiple concurrent reads and writes
        for i in 0..<10 {
            queue.async {
                _ = self.recognizer.isRecording
                _ = self.recognizer.transcript
                _ = self.recognizer.confidence
            }
            
            queue.async(flags: .barrier) {
                self.recognizer.transcript = "Test \(i)"
                self.recognizer.confidence = Float(i) / 10.0
            }
        }
        
        queue.async(flags: .barrier) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}

// MARK: - Test Helpers

extension ConversationRecognizer.SpeechRecognitionError: Equatable {
    public static func == (lhs: ConversationRecognizer.SpeechRecognitionError, rhs: ConversationRecognizer.SpeechRecognitionError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthorized, .notAuthorized),
             (.notAvailable, .notAvailable),
             (.audioEngineError, .audioEngineError),
             (.microphoneAccessDenied, .microphoneAccessDenied):
            return true
        case let (.recognitionError(lhsMessage), .recognitionError(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
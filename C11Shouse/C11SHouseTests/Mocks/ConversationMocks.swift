/*
 * CONTEXT & PURPOSE:
 * Mock implementations specific to conversation testing, including
 * message store, conversation recognizer, and question flow mocks.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Initial mock implementations
 *   - MockMessageStore for testing message persistence
 *   - MockConversationRecognizer for voice input simulation
 *   - MockQuestionFlowCoordinator for question flow testing
 *   - MockHouseThought generator for response testing
 *
 * FUTURE UPDATES:
 * - Add more sophisticated response generation
 * - Add delay simulation for async operations
 */

import Foundation
import Combine
import Speech
@testable import C11SHouse

// MARK: - Message Store Mock

class MockMessageStore: ObservableObject {
    @Published var messages: [Message] = []
    
    var addMessageCalled = false
    var clearAllMessagesCalled = false
    var lastAddedMessage: Message?
    
    init(initialMessages: [Message] = []) {
        self.messages = initialMessages
    }
    
    func addMessage(_ message: Message) {
        addMessageCalled = true
        lastAddedMessage = message
        messages.append(message)
    }
    
    func clearAllMessages() {
        clearAllMessagesCalled = true
        messages.removeAll()
    }
    
    func getMessage(at index: Int) -> Message? {
        guard index >= 0 && index < messages.count else { return nil }
        return messages[index]
    }
}

// MARK: - Conversation Recognizer Mock

class MockConversationRecognizer: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var error: SpeechError?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .authorized
    @Published var currentHouseThought: HouseThought?
    
    var toggleRecordingCalled = false
    var stopRecordingCalled = false
    var setQuestionThoughtCalled = false
    var setThankYouThoughtCalled = false
    var clearHouseThoughtCalled = false
    
    var mockTranscript: String?
    var shouldFailWithError: SpeechError?
    
    func toggleRecording() {
        toggleRecordingCalled = true
        
        if let error = shouldFailWithError {
            self.error = error
            return
        }
        
        isRecording.toggle()
        
        if isRecording, let mock = mockTranscript {
            // Simulate gradual transcript update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.transcript = mock
            }
        }
    }
    
    func stopRecording() {
        stopRecordingCalled = true
        isRecording = false
    }
    
    func setQuestionThought(_ question: String) async {
        setQuestionThoughtCalled = true
        currentHouseThought = HouseThought(
            thought: question,
            emotion: .curious,
            category: .question,
            confidence: 1.0
        )
    }
    
    func setThankYouThought() async {
        setThankYouThoughtCalled = true
        currentHouseThought = HouseThought(
            thought: "Thank you!",
            emotion: .happy,
            category: .celebration,
            confidence: 1.0
        )
    }
    
    func clearHouseThought() async {
        clearHouseThoughtCalled = true
        currentHouseThought = nil
    }
}

// MARK: - Question Flow Coordinator Mock

class MockQuestionFlowCoordinator: ObservableObject {
    @Published var currentQuestion: Question?
    @Published var hasCompletedAllQuestions = false
    @Published var isLoadingQuestion = false
    
    var conversationRecognizer: ConversationRecognizer?
    var conversationStateManager: ConversationStateManager?
    var addressManager: AddressManager?
    var addressSuggestionService: AddressSuggestionService?
    var serviceContainer: ServiceContainer?
    
    var loadNextQuestionCalled = false
    var saveAnswerCalled = false
    var handleQuestionChangeCalled = false
    
    var mockQuestions: [Question] = []
    var currentQuestionIndex = 0
    var savedAnswers: [UUID: String] = [:]
    
    init(questions: [Question] = []) {
        self.mockQuestions = questions
        if !questions.isEmpty {
            self.currentQuestion = questions[0]
        }
    }
    
    func loadNextQuestion() async {
        loadNextQuestionCalled = true
        isLoadingQuestion = true
        
        // Simulate async loading
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        if currentQuestionIndex < mockQuestions.count - 1 {
            currentQuestionIndex += 1
            currentQuestion = mockQuestions[currentQuestionIndex]
        } else {
            currentQuestion = nil
            hasCompletedAllQuestions = true
        }
        
        isLoadingQuestion = false
    }
    
    func saveAnswer() async {
        saveAnswerCalled = true
        
        if let question = currentQuestion,
           let transcript = await conversationStateManager?.persistentTranscript {
            savedAnswers[question.id] = transcript
        }
    }
    
    func handleQuestionChange(oldQuestion: Question?, newQuestion: Question?, isInitializing: Bool) async -> Bool {
        handleQuestionChangeCalled = true
        return true
    }
    
    func reset() {
        currentQuestionIndex = 0
        currentQuestion = mockQuestions.first
        hasCompletedAllQuestions = false
        savedAnswers.removeAll()
    }
}

// MARK: - Service Container Mock

class MockConversationServiceContainer: ObservableObject {
    let mockNotesService: SharedMockNotesService
    let mockTTSService: MockTTSService
    let mockLocationService: MockLocationService
    let mockAddressManager: SharedMockAddressManager
    let mockQuestionFlow: MockQuestionFlowCoordinator
    
    init() {
        self.mockNotesService = SharedMockNotesService()
        self.mockTTSService = MockTTSService()
        self.mockLocationService = MockLocationService()
        self.mockAddressManager = SharedMockAddressManager(notesService: mockNotesService, locationService: mockLocationService)
        self.mockQuestionFlow = MockQuestionFlowCoordinator()
    }
    
    // Mock service access methods
    var notesService: NotesServiceProtocol { mockNotesService }
    var ttsService: TTSService { mockTTSService }
    var locationService: LocationServiceProtocol { mockLocationService }
    var addressManager: AddressManager { mockAddressManager }
    var questionFlowCoordinator: MockQuestionFlowCoordinator { mockQuestionFlow }
}

// MARK: - House Thought Generator Mock

class MockHouseThoughtGenerator {
    static func generateThought(for input: String) -> HouseThought {
        let lowercased = input.lowercased()
        
        if lowercased.contains("hello") || lowercased.contains("hi") {
            return HouseThought(
                thought: "Hello! Great to chat with you.",
                emotion: .happy,
                category: .greeting,
                confidence: 1.0
            )
        } else if lowercased.contains("weather") {
            return HouseThought(
                thought: "Let me check the weather for you.",
                emotion: .thoughtful,
                category: .observation,
                confidence: 0.9,
                suggestion: "I'll need your location to get accurate weather."
            )
        } else if lowercased.contains("thank") {
            return HouseThought(
                thought: "You're very welcome!",
                emotion: .happy,
                category: .celebration,
                confidence: 1.0
            )
        } else {
            return HouseThought(
                thought: "I understand. Let me help with that.",
                emotion: .thoughtful,
                category: .observation,
                confidence: 0.8
            )
        }
    }
}

// MARK: - Message Factory

class MessageFactory {
    static func createUserMessage(_ content: String, isVoice: Bool = false) -> Message {
        return Message(
            content: content,
            isFromUser: true,
            isVoice: isVoice
        )
    }
    
    static func createHouseMessage(_ content: String, isVoice: Bool = false) -> Message {
        return Message(
            content: content,
            isFromUser: false,
            isVoice: isVoice
        )
    }
    
    static func createConversationHistory(messageCount: Int) -> [Message] {
        var messages: [Message] = []
        
        for i in 0..<messageCount {
            if i % 2 == 0 {
                messages.append(createUserMessage("User message \(i/2 + 1)"))
            } else {
                messages.append(createHouseMessage("House response \(i/2 + 1)"))
            }
        }
        
        return messages
    }
}

// MARK: - View Model Factory Mock

class MockViewModelFactory: ViewModelFactory {
    let mockStateManager: ConversationStateManager
    
    @MainActor
    override init(serviceContainer: ServiceContainer, appState: AppState) {
        let mockNotes = SharedMockNotesService()
        let mockTTS = MockTTSService()
        self.mockStateManager = ConversationStateManager(
            notesService: mockNotes,
            ttsService: mockTTS
        )
        super.init(serviceContainer: serviceContainer, appState: appState)
    }
    
    @MainActor
    convenience init() {
        self.init(serviceContainer: .shared, appState: .shared)
    }
    
    @MainActor
    override func makeConversationStateManager() -> ConversationStateManager {
        return mockStateManager
    }
}
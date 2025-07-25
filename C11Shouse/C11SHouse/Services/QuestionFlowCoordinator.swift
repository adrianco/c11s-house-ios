/*
 * CONTEXT & PURPOSE:
 * QuestionFlowCoordinator manages the flow of questions in the conversation interface.
 * It handles question progression, validation, and coordinates with NotesService for
 * persistence. This extracts the complex question management logic from ConversationView.
 *
 * DECISION HISTORY:
 * - 2025-01-09: Initial implementation
 *   - Extracted from ConversationView to reduce its complexity
 *   - ObservableObject for SwiftUI integration
 *   - Coordinates with NotesService for persistence
 *   - Handles question loading, progression, and answer validation
 *   - Manages current question state and transitions
 *   - Supports pre-populated answers for review
 * - 2025-01-25: Refactored into simple state machine
 *   - Added ConversationState enum for clear state tracking
 *   - Implemented queue-based question management
 *   - Removed complex dependencies and cruft
 *   - Single-threaded conversation flow
 *   - Clear separation between state transitions and actions
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation
import Combine

// MARK: - State Machine

enum ConversationState: Equatable {
    case idle
    case loadingQuestion
    case waitingForAnswer(Question)
    case processingAnswer(Question, String)
    case completed
    case error(String)
}

class QuestionFlowCoordinator: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var state: ConversationState = .idle
    @Published private(set) var currentQuestion: Question?
    @Published var isLoadingQuestion = false
    @Published var hasCompletedAllQuestions = false
    
    // MARK: - Private Properties
    
    private let notesService: NotesServiceProtocol
    private var questionQueue: [Question] = []
    private var processedQuestions: Set<UUID> = []
    
    // Simplified dependencies
    weak var conversationStateManager: ConversationStateManager?
    weak var conversationRecognizer: ConversationRecognizer?
    weak var addressManager: AddressManager?
    weak var serviceContainer: ServiceContainer?
    var addressSuggestionService: AddressSuggestionService?
    
    // MARK: - Initialization
    
    init(notesService: NotesServiceProtocol) {
        self.notesService = notesService
        print("[QuestionFlowCoordinator] Initialized with state machine")
    }
    
    // MARK: - State Machine Methods
    
    /// Transition to a new state
    @MainActor
    private func transition(to newState: ConversationState) {
        print("[QuestionFlowCoordinator] State transition: \(state) -> \(newState)")
        state = newState
        
        // Update published properties based on state
        switch newState {
        case .idle:
            isLoadingQuestion = false
            currentQuestion = nil
        case .loadingQuestion:
            isLoadingQuestion = true
        case .waitingForAnswer(let question):
            isLoadingQuestion = false
            currentQuestion = question
        case .processingAnswer:
            isLoadingQuestion = false
        case .completed:
            isLoadingQuestion = false
            currentQuestion = nil
            hasCompletedAllQuestions = true
        case .error:
            isLoadingQuestion = false
        }
    }
    
    // MARK: - Public Methods
    
    /// Start the conversation flow
    func startConversation() async {
        await transition(to: .loadingQuestion)
        await loadQuestionQueue()
        await processNextQuestion()
    }
    
    /// Load all questions that need to be answered
    private func loadQuestionQueue() async {
        do {
            let notesStore = try await notesService.loadNotesStore()
            let questionsNeedingReview = notesStore.questionsNeedingReview()
                .filter { !processedQuestions.contains($0.id) }
            
            questionQueue = questionsNeedingReview
            print("[QuestionFlowCoordinator] Loaded \(questionQueue.count) questions into queue")
        } catch {
            print("[QuestionFlowCoordinator] Error loading questions: \(error)")
            await transition(to: .error(error.localizedDescription))
        }
    }
    
    /// Process the next question in the queue
    private func processNextQuestion() async {
        guard !questionQueue.isEmpty else {
            print("[QuestionFlowCoordinator] No more questions in queue")
            await transition(to: .completed)
            
            // Notify completion
            NotificationCenter.default.post(name: Notification.Name("AllQuestionsComplete"), object: nil)
            
            // Check for HomeKit configuration
            await checkForHomeKitConfiguration()
            return
        }
        
        let nextQuestion = questionQueue.removeFirst()
        print("[QuestionFlowCoordinator] Processing question: '\(nextQuestion.text)'")
        
        // Prepare question display
        await prepareQuestionDisplay(nextQuestion)
        
        // Transition to waiting state
        await transition(to: .waitingForAnswer(nextQuestion))
    }
    
    /// Prepare the question for display (handle special cases)
    private func prepareQuestionDisplay(_ question: Question) async {
        guard let recognizer = conversationRecognizer else { return }
        
        // Get existing answer if any
        let existingAnswer = await getCurrentAnswer(for: question)
        
        // Handle special question types
        if question.text.contains("address") {
            await prepareAddressQuestion(question, existingAnswer: existingAnswer)
        } else if question.text.contains("call this house") {
            await prepareHouseNameQuestion(question, existingAnswer: existingAnswer)
        } else if let answer = existingAnswer, !answer.isEmpty {
            // Pre-populate with existing answer
            conversationStateManager?.persistentTranscript = answer
            
            let thought = HouseThought(
                thought: "\(question.text)\n\n\(answer)",
                emotion: .curious,
                category: .question,
                confidence: 0.9
            )
            await MainActor.run {
                recognizer.currentHouseThought = thought
            }
        } else {
            // Simple question
            await MainActor.run {
                recognizer.setQuestionThought(question.text)
            }
        }
    }
    
    /// Get the current answer for a question if it exists
    func getCurrentAnswer(for question: Question) async -> String? {
        do {
            let note = try await notesService.getNote(for: question.id)
            return note?.answer
        } catch {
            return nil
        }
    }
    
    /// Process user input as an answer to the current question
    func processUserInput(_ input: String) async {
        guard case .waitingForAnswer(let question) = state else {
            print("[QuestionFlowCoordinator] Not waiting for answer, ignoring input")
            return
        }
        
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            print("[QuestionFlowCoordinator] Empty input, ignoring")
            return
        }
        
        // Special handling for address questions with simple acknowledgments
        if isAddressQuestion(question) && isSimpleAcknowledgment(trimmedInput) {
            print("[QuestionFlowCoordinator] Ignoring acknowledgment during address question")
            // Stay in waiting state, don't process as answer
            return
        }
        
        // Transition to processing state
        await transition(to: .processingAnswer(question, trimmedInput))
        
        // Process the answer
        await saveAnswerForQuestion(question, answer: trimmedInput)
        
        // Mark question as processed
        processedQuestions.insert(question.id)
        
        // Move to next question
        await processNextQuestion()
    }
    
    /// Save answer for a specific question
    private func saveAnswerForQuestion(_ question: Question, answer: String) async {
        do {
            // Save to notes service
            var metadata: [String: String] = ["updated_via_conversation": "true"]
            try await notesService.saveOrUpdateNote(
                for: question.id,
                answer: answer,
                metadata: metadata
            )
            
            // Handle special question types
            await handleSpecialQuestionTypes(question, answer: answer)
            
            // Clear transcript
            conversationStateManager?.clearTranscript()
            
            // Send acknowledgment
            await sendAcknowledgment()
            
            print("[QuestionFlowCoordinator] Answer saved successfully")
        } catch {
            print("[QuestionFlowCoordinator] Error saving answer: \(error)")
            await transition(to: .error(error.localizedDescription))
        }
    }
    
    /// Handle special processing for specific question types
    private func handleSpecialQuestionTypes(_ question: Question, answer: String) async {
        if question.text == "What's your name?" {
            await conversationStateManager?.updateUserName(answer)
        } else if isAddressQuestion(question) {
            if let manager = addressManager,
               let address = manager.parseAddress(answer) {
                try? await manager.saveAddress(address)
            }
        } else if question.text.contains("call this house") {
            if let container = serviceContainer {
                await container.notesService.saveHouseName(answer)
            } else {
                await notesService.saveHouseName(answer)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a question is about address
    private func isAddressQuestion(_ question: Question) -> Bool {
        return question.text.contains("address")
    }
    
    /// Check if input is a simple acknowledgment
    private func isSimpleAcknowledgment(_ input: String) -> Bool {
        let lowercased = input.lowercased()
        let acknowledgments = ["continue", "ok", "yes", "got it", "thanks", "okay", "sure"]
        return acknowledgments.contains(lowercased)
    }
    
    /// Prepare address question display
    private func prepareAddressQuestion(_ question: Question, existingAnswer: String?) async {
        guard let recognizer = conversationRecognizer else { return }
        
        if let answer = existingAnswer, !answer.isEmpty {
            // Use existing answer
            conversationStateManager?.persistentTranscript = answer
            let thought = HouseThought(
                thought: "\(question.text)\n\n\(answer)",
                emotion: .curious,
                category: .question,
                confidence: 0.9
            )
            await MainActor.run {
                recognizer.currentHouseThought = thought
            }
        } else {
            // Try to detect address
            if let manager = addressManager,
               let detectedAddress = try? await manager.detectCurrentAddress() {
                await manager.storeDetectedAddress(detectedAddress)
                conversationStateManager?.persistentTranscript = detectedAddress.fullAddress
                
                let thought = HouseThought(
                    thought: "\(question.text)\n\n\(detectedAddress.fullAddress)",
                    emotion: .curious,
                    category: .question,
                    confidence: 0.9
                )
                await MainActor.run {
                    recognizer.currentHouseThought = thought
                }
            } else {
                // No address available
                await MainActor.run {
                    recognizer.setQuestionThought("What's your home address?")
                }
            }
        }
    }
    
    /// Prepare house name question display
    private func prepareHouseNameQuestion(_ question: Question, existingAnswer: String?) async {
        guard let recognizer = conversationRecognizer else { return }
        
        if let answer = existingAnswer, !answer.isEmpty {
            // Use existing answer
            conversationStateManager?.persistentTranscript = answer
            let thought = HouseThought(
                thought: "\(question.text)\n\n\(answer)",
                emotion: .curious,
                category: .question,
                confidence: 0.9
            )
            await MainActor.run {
                recognizer.currentHouseThought = thought
            }
        } else {
            // Generate suggestions based on address
            let addressAnswer = await getAnswer(for: "Is this the right address?") ??
                               await getAnswer(for: "What's your home address?")
            
            if let addressAnswer = addressAnswer, !addressAnswer.isEmpty {
                if let suggestionService = addressSuggestionService {
                    let suggestions = suggestionService.generateHouseNameSuggestions(from: addressAnswer)
                    if !suggestions.isEmpty {
                        conversationStateManager?.persistentTranscript = suggestions.first!
                        let thought = suggestionService.createHouseNameSuggestionResponse(suggestions)
                        await MainActor.run {
                            recognizer.currentHouseThought = thought
                        }
                    }
                } else {
                    await MainActor.run {
                        recognizer.setQuestionThought(question.text)
                    }
                }
            } else {
                await MainActor.run {
                    recognizer.setQuestionThought(question.text)
                }
            }
        }
    }
    
    /// Check if a specific question type has been answered
    func isQuestionAnswered(_ questionText: String) async -> Bool {
        do {
            let notesStore = try await notesService.loadNotesStore()
            if let question = notesStore.questions.first(where: { $0.text == questionText }),
               let note = notesStore.notes[question.id] {
                return note.isAnswered
            }
        } catch {
            print("Error checking question status: \(error)")
        }
        return false
    }
    
    /// Get the answer for a specific question type
    func getAnswer(for questionText: String) async -> String? {
        do {
            let notesStore = try await notesService.loadNotesStore()
            if let question = notesStore.questions.first(where: { $0.text == questionText }),
               let note = notesStore.notes[question.id] {
                return note.answer
            }
        } catch {
            print("Error getting answer: \(error)")
        }
        return nil
    }
    
    /// Send acknowledgment after saving an answer
    private func sendAcknowledgment() async {
        guard let recognizer = conversationRecognizer else { return }
        
        let acknowledgment = HouseThought(
            thought: "Got it!",
            emotion: .happy,
            category: .greeting,
            confidence: 1.0,
            context: "Answer acknowledgment"
        )
        
        await MainActor.run {
            recognizer.currentHouseThought = acknowledgment
        }
    }
    
    /// Load the next question (compatibility method for existing code)
    func loadNextQuestion() async {
        if state == .idle {
            await startConversation()
        } else {
            await processNextQuestion()
        }
    }
    
    /// Reset the conversation flow
    func reset() async {
        processedQuestions.removeAll()
        questionQueue.removeAll()
        await transition(to: .idle)
    }
    
    /// Get current state description for debugging
    var stateDescription: String {
        switch state {
        case .idle:
            return "Idle"
        case .loadingQuestion:
            return "Loading questions..."
        case .waitingForAnswer(let question):
            return "Waiting for answer to: \(question.text)"
        case .processingAnswer(let question, let answer):
            return "Processing answer '\(answer)' for: \(question.text)"
        case .completed:
            return "All questions completed"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    // MARK: - Existing Helper Methods (simplified)
    
    private func checkForHomeKitConfiguration() async {
        guard let container = serviceContainer,
              let recognizer = conversationRecognizer else { return }
        
        // Check if we have any HomeKit configuration notes
        do {
            let store = try await notesService.loadNotesStore()
            let homeKitNotes = store.notes.values.filter { note in
                if let metadata = note.metadata,
                   let category = metadata["category"] {
                    return category == "homekit_summary" || 
                           category == "homekit_room" || 
                           category == "homekit_device"
                }
                return false
            }
            
            if !homeKitNotes.isEmpty {
                // Find the summary note
                if let summaryNote = homeKitNotes.first(where: { $0.metadata?["category"] == "homekit_summary" }) {
                    // Parse the summary to get counts
                    let content = summaryNote.answer
                    var homeCount = 0
                    var roomCount = 0
                    var deviceCount = 0
                    
                    // Simple parsing of the summary content
                    let homesRegex = try? NSRegularExpression(pattern: "Found (\\d+) home", options: [])
                    if let match = homesRegex?.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
                        if let range = Range(match.range(at: 1), in: content) {
                            homeCount = Int(content[range]) ?? 0
                        }
                    }
                    
                    let roomsRegex = try? NSRegularExpression(pattern: "Total Rooms: (\\d+)", options: [])
                    if let match = roomsRegex?.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
                        if let range = Range(match.range(at: 1), in: content) {
                            roomCount = Int(content[range]) ?? 0
                        }
                    }
                    
                    let devicesRegex = try? NSRegularExpression(pattern: "Total Accessories: (\\d+)", options: [])
                    if let match = devicesRegex?.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
                        if let range = Range(match.range(at: 1), in: content) {
                            deviceCount = Int(content[range]) ?? 0
                        }
                    }
                    
                    // Create an acknowledgment thought
                    let message = roomCount > 0 
                        ? "I've imported your HomeKit configuration! I found \(homeCount) home\(homeCount == 1 ? "" : "s") with \(roomCount) room\(roomCount == 1 ? "" : "s") and \(deviceCount) device\(deviceCount == 1 ? "" : "s"). Since you already have rooms set up, I won't ask you to create room notes - you can ask me about any of your existing rooms or add more notes anytime."
                        : "I've imported your HomeKit configuration! I found \(homeCount) home\(homeCount == 1 ? "" : "s") with \(deviceCount) device\(deviceCount == 1 ? "" : "s"). You can now ask me about any of your devices."
                    
                    let thought = HouseThought(
                        thought: message,
                        emotion: .proud,
                        category: .celebration,
                        confidence: 1.0,
                        context: "HomeKit import complete",
                        suggestion: "Try asking 'What devices are in the living room?' or 'Tell me about my lights'"
                    )
                    
                    await MainActor.run {
                        recognizer.currentHouseThought = thought
                    }
                    
                    print("[QuestionFlowCoordinator] Acknowledged HomeKit configuration import")
                }
            }
        } catch {
            print("[QuestionFlowCoordinator] Error checking for HomeKit configuration: \(error)")
        }
    }
}

// MARK: - Error Types

enum QuestionFlowError: LocalizedError {
    case noCurrentQuestion
    case emptyAnswer
    
    var errorDescription: String? {
        switch self {
        case .noCurrentQuestion:
            return "No question is currently active"
        case .emptyAnswer:
            return "Answer cannot be empty"
        }
    }
}
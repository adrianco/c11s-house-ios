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
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation
import Combine

class QuestionFlowCoordinator: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentQuestion: Question?
    @Published var isLoadingQuestion = false
    @Published var hasCompletedAllQuestions = false
    
    // MARK: - Private Properties
    
    private let notesService: NotesServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // Dependencies for complex operations
    weak var conversationStateManager: ConversationStateManager?
    weak var conversationRecognizer: ConversationRecognizer?
    weak var addressManager: AddressManager?
    weak var serviceContainer: ServiceContainer?
    var addressSuggestionService: AddressSuggestionService?
    
    // MARK: - Initialization
    
    init(notesService: NotesServiceProtocol) {
        self.notesService = notesService
        print("[QuestionFlowCoordinator] Initialized")
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Load the next question that needs review
    func loadNextQuestion() async {
        print("[QuestionFlowCoordinator] loadNextQuestion() called")
        print("[QuestionFlowCoordinator] Current state - isLoadingQuestion: \(isLoadingQuestion), hasCompletedAllQuestions: \(hasCompletedAllQuestions)")
        guard !isLoadingQuestion else { 
            print("[QuestionFlowCoordinator] Already loading question, skipping")
            return 
        }
        
        await MainActor.run {
            isLoadingQuestion = true
        }
        defer { 
            Task { @MainActor in
                self.isLoadingQuestion = false
            }
        }
        
        do {
            let notesStore = try await notesService.loadNotesStore()
            print("[QuestionFlowCoordinator] Loaded notes store with \(notesStore.questions.count) questions")
            
            let questionsNeedingReview = notesStore.questionsNeedingReview()
            print("[QuestionFlowCoordinator] Questions needing review: \(questionsNeedingReview.count)")
            
            if let nextQuestion = questionsNeedingReview.first {
                print("[QuestionFlowCoordinator] Next question: '\(nextQuestion.text)' (required: \(nextQuestion.isRequired))")
                await MainActor.run {
                    currentQuestion = nextQuestion
                    hasCompletedAllQuestions = false
                }
            } else {
                print("[QuestionFlowCoordinator] No more questions to ask")
                await MainActor.run {
                    currentQuestion = nil
                    hasCompletedAllQuestions = true
                }
                
                // Post notification that all questions are complete
                print("[QuestionFlowCoordinator] Posting AllQuestionsComplete notification")
                print("[QuestionFlowCoordinator] All questions completed, NOT reloading (infinite loop prevention)")
                NotificationCenter.default.post(name: Notification.Name("AllQuestionsComplete"), object: nil)
            }
        } catch {
            print("[QuestionFlowCoordinator] Error loading questions: \(error)")
            await MainActor.run {
                currentQuestion = nil
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
    
    /// Save an answer for the current question with full integration
    @MainActor
    func saveAnswer() async {
        guard let question = currentQuestion else { 
            print("[QuestionFlowCoordinator] No current question to save answer for")
            return 
        }
        guard let stateManager = conversationStateManager else { 
            print("[QuestionFlowCoordinator] No conversationStateManager")
            return 
        }
        guard let recognizer = conversationRecognizer else { 
            print("[QuestionFlowCoordinator] No conversationRecognizer")
            return 
        }
        
        // Prevent multiple saves
        guard !stateManager.isSavingAnswer else { 
            print("[QuestionFlowCoordinator] Already saving answer, skipping")
            return 
        }
        
        print("[QuestionFlowCoordinator] Saving answer for question: '\(question.text)'")
        stateManager.beginSavingAnswer()
        
        do {
            let trimmedAnswer = stateManager.persistentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[QuestionFlowCoordinator] Answer: '\(trimmedAnswer)'")
            
            // Clear any existing house thought to prevent duplicate speech
            recognizer.clearHouseThought()
            
            // Save the answer using the existing method
            try await saveAnswer(trimmedAnswer)
            print("[QuestionFlowCoordinator] Answer saved successfully")
            
            // If this was the name question, update the userName
            if question.text == "What's your name?" {
                print("[QuestionFlowCoordinator] Updating user name")
                await stateManager.updateUserName(trimmedAnswer)
            }
            
            // If this was the address question, save it properly and fetch weather
            if question.text == "Is this the right address?" || question.text == "What's your home address?" {
                print("[QuestionFlowCoordinator] Processing address answer: \(trimmedAnswer)")
                if let manager = addressManager,
                   let address = manager.parseAddress(trimmedAnswer) {
                    print("[QuestionFlowCoordinator] User confirmed address, now saving as answered")
                    try await manager.saveAddress(address)
                    
                    // Weather fetch is handled by ContentViewModel when it detects the address update
                    // This prevents duplicate weather fetches
                    print("[QuestionFlowCoordinator] Address saved - ContentViewModel will fetch weather")
                }
            }
            
            // If this was the house name question, save it to ContentViewModel
            if question.text == "What should I call this house?" {
                print("[QuestionFlowCoordinator] Saving house name")
                if let container = serviceContainer {
                    await container.notesService.saveHouseName(trimmedAnswer)
                }
            }
            
            // Clear the transcript
            stateManager.clearTranscript()
            
        } catch {
            print("[QuestionFlowCoordinator] Error saving answer: \(error)")
        }
        
        stateManager.endSavingAnswer()
    }
    
    /// Save an answer for the current question (basic version)
    func saveAnswer(_ answer: String, metadata: [String: String]? = nil) async throws {
        print("[QuestionFlowCoordinator] saveAnswer called with answer: '\(answer)'")
        guard let question = currentQuestion else {
            print("[QuestionFlowCoordinator] Error: No current question")
            throw QuestionFlowError.noCurrentQuestion
        }
        
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[QuestionFlowCoordinator] Trimmed answer: '\(trimmedAnswer)'")
        guard !trimmedAnswer.isEmpty else {
            print("[QuestionFlowCoordinator] Error: Empty answer after trimming")
            throw QuestionFlowError.emptyAnswer
        }
        
        var finalMetadata = metadata ?? [:]
        finalMetadata["updated_via_conversation"] = "true"
        
        print("[QuestionFlowCoordinator] Calling notesService.saveOrUpdateNote for question: \(question.id)")
        try await notesService.saveOrUpdateNote(
            for: question.id,
            answer: trimmedAnswer,
            metadata: finalMetadata
        )
        print("[QuestionFlowCoordinator] saveOrUpdateNote completed successfully")
        
        // Clear current question after saving
        await MainActor.run {
            currentQuestion = nil
        }
        
        // Send acknowledgment
        await sendAcknowledgment()
        
        // Load the next question
        await loadNextQuestion()
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
    
    /// Handle question change events
    /// Returns true if still initializing, false otherwise
    @MainActor
    func handleQuestionChange(oldQuestion: Question?, newQuestion: Question?, isInitializing: Bool) async -> Bool {
        guard let question = newQuestion else {
            // No more questions
            if hasCompletedAllQuestions {
                conversationRecognizer?.setThankYouThought()
            }
            // Always return false when there's no question (initialization is complete)
            return false
        }
        
        // Mark initialization as complete
        let newInitializingState = false
        
        guard let stateManager = conversationStateManager,
              let recognizer = conversationRecognizer else { return newInitializingState }
        
        // Get current answer if any
        let currentAnswer = await getCurrentAnswer(for: question) ?? ""
        
        // Handle different question types
        if question.text == "Is this the right address?" || question.text == "What's your home address?" {
            if currentAnswer.isEmpty {
                // Check for detected address first
                var detectedAddress: Address? = nil
                
                // Try to get stored detected address
                if let manager = addressManager {
                    detectedAddress = manager.loadDetectedAddress()
                    if detectedAddress != nil {
                        print("[QuestionFlowCoordinator] Found stored detected address: \(detectedAddress!.fullAddress)")
                    }
                }
                
                // If no stored address, try to detect now
                if detectedAddress == nil {
                    do {
                        if let manager = addressManager {
                            detectedAddress = try await manager.detectCurrentAddress()
                            await manager.storeDetectedAddress(detectedAddress!)
                        }
                    } catch {
                        print("[QuestionFlowCoordinator] Failed to detect address: \(error)")
                    }
                }
                
                // Format question with detected address for SuggestedAnswerQuestionView
                if let address = detectedAddress {
                    stateManager.persistentTranscript = address.fullAddress
                    
                    // Create house thought with proper format: Question?\n\nAnswer
                    let thought = HouseThought(
                        thought: "\(question.text)\n\n\(address.fullAddress)",
                        emotion: .curious,
                        category: .question,
                        confidence: 0.9,
                        context: "Address confirmation",
                        suggestion: nil
                    )
                    recognizer.currentHouseThought = thought
                    
                    print("[QuestionFlowCoordinator] Formatted address question with detected address")
                } else {
                    // No address available, just ask the question
                    recognizer.setQuestionThought(question.text)
                }
            } else {
                // Pre-populate with existing answer
                stateManager.persistentTranscript = currentAnswer
                recognizer.setQuestionThought(question.text)
            }
        } else if question.text == "What should I call this house?" {
            if currentAnswer.isEmpty {
                // Generate suggestions from address if available
                var addressAnswer: String? = await getAnswer(for: "Is this the right address?")
                if addressAnswer == nil {
                    addressAnswer = await getAnswer(for: "What's your home address?")
                }
                if let addressAnswer = addressAnswer, !addressAnswer.isEmpty {
                    
                    if let suggestionService = addressSuggestionService {
                        let suggestions = suggestionService.generateHouseNameSuggestions(from: addressAnswer)
                        if !suggestions.isEmpty {
                            // Pre-populate with first suggestion
                            stateManager.persistentTranscript = suggestions.first!
                            
                            // Set house thought with all suggestions
                            let thought = suggestionService.createHouseNameSuggestionResponse(suggestions)
                            recognizer.currentHouseThought = thought
                        }
                    } else if let manager = addressManager {
                        let suggestedName = manager.generateHouseName(from: addressAnswer)
                        stateManager.persistentTranscript = suggestedName
                        
                        // Format with suggested answer for SuggestedAnswerQuestionView
                        let thought = HouseThought(
                            thought: "\(question.text)\n\n\(suggestedName)",
                            emotion: .curious,
                            category: .question,
                            confidence: 0.9,
                            context: "House naming suggestion",
                            suggestion: nil
                        )
                        recognizer.currentHouseThought = thought
                    }
                } else {
                    recognizer.setQuestionThought(question.text)
                }
            } else {
                stateManager.persistentTranscript = currentAnswer
                recognizer.setQuestionThought(question.text)
            }
        } else if currentAnswer.isEmpty {
            // No answer yet, just ask the question
            recognizer.setQuestionThought(question.text)
        } else {
            // Pre-populate and ask for confirmation with consistent format
            stateManager.persistentTranscript = currentAnswer
            
            // Create a house thought with the question and suggested answer
            let thought = HouseThought(
                thought: "\(question.text)\n\n\(currentAnswer)",
                emotion: .curious,
                category: .question,
                confidence: 0.9,
                context: "Confirming existing answer",
                suggestion: nil
            )
            recognizer.currentHouseThought = thought
        }
        
        return newInitializingState
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // NOTE: Removed AllQuestionsComplete listener to prevent infinite loop
        // The notification is posted when all questions are complete, but we don't need to reload
        print("[QuestionFlowCoordinator] Notifications setup complete (AllQuestionsComplete listener removed)")
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
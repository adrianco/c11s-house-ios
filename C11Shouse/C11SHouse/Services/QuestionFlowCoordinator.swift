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
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Load the next question that needs review
    func loadNextQuestion() async {
        guard !isLoadingQuestion else { return }
        
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
            let questionsNeedingReview = notesStore.questionsNeedingReview()
            
            if let nextQuestion = questionsNeedingReview.first {
                await MainActor.run {
                    currentQuestion = nextQuestion
                    hasCompletedAllQuestions = false
                }
            } else {
                await MainActor.run {
                    currentQuestion = nil
                    hasCompletedAllQuestions = true
                }
                
                // Post notification that all questions are complete
                NotificationCenter.default.post(name: Notification.Name("AllQuestionsComplete"), object: nil)
            }
        } catch {
            print("Error loading questions: \(error)")
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
        guard let question = currentQuestion else { return }
        guard let stateManager = conversationStateManager else { return }
        guard let recognizer = conversationRecognizer else { return }
        
        // Prevent multiple saves
        guard !stateManager.isSavingAnswer else { return }
        
        stateManager.beginSavingAnswer()
        
        do {
            let trimmedAnswer = stateManager.persistentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Clear any existing house thought to prevent duplicate speech
            await recognizer.clearHouseThought()
            
            // Save the answer using the existing method
            try await saveAnswer(trimmedAnswer)
            
            // If this was the name question, update the userName
            if question.text == "What's your name?" {
                await stateManager.updateUserName(trimmedAnswer)
            }
            
            // If this was the address question, save it properly and fetch weather
            if question.text == "Is this the right address?" || question.text == "What's your home address?" {
                if let manager = addressManager,
                   let address = manager.parseAddress(trimmedAnswer) {
                    try await manager.saveAddress(address)
                    
                    // Trigger weather fetch after address confirmation
                    if let suggestionService = addressSuggestionService {
                        await suggestionService.fetchWeatherForConfirmedAddress(address)
                    }
                }
            }
            
            // If this was the house name question, save it to ContentViewModel
            if question.text == "What should I call this house?" {
                if let container = serviceContainer {
                    await container.notesService.saveHouseName(trimmedAnswer)
                }
            }
            
            // Clear the transcript
            stateManager.clearTranscript()
            
        } catch {
            print("Error saving answer: \(error)")
        }
        
        stateManager.endSavingAnswer()
    }
    
    /// Save an answer for the current question (basic version)
    func saveAnswer(_ answer: String, metadata: [String: String]? = nil) async throws {
        guard let question = currentQuestion else {
            throw QuestionFlowError.noCurrentQuestion
        }
        
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else {
            throw QuestionFlowError.emptyAnswer
        }
        
        var finalMetadata = metadata ?? [:]
        finalMetadata["updated_via_conversation"] = "true"
        
        try await notesService.saveOrUpdateNote(
            for: question.id,
            answer: trimmedAnswer,
            metadata: finalMetadata
        )
        
        // Clear current question after saving
        await MainActor.run {
            currentQuestion = nil
        }
        
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
    
    /// Handle question change events
    /// Returns true if still initializing, false otherwise
    @MainActor
    func handleQuestionChange(oldQuestion: Question?, newQuestion: Question?, isInitializing: Bool) async -> Bool {
        guard let question = newQuestion else {
            // No more questions
            if hasCompletedAllQuestions {
                await conversationRecognizer?.setThankYouThought()
            }
            return isInitializing
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
                // Try to detect the address
                do {
                    if let suggestionService = addressSuggestionService {
                        let detectedAddress = try await suggestionService.suggestCurrentAddress()
                        stateManager.persistentTranscript = detectedAddress
                        
                        // Set house thought with address confirmation
                        let thought = suggestionService.createAddressConfirmationResponse(detectedAddress)
                        recognizer.currentHouseThought = thought
                    } else if let manager = addressManager {
                        let detected = try await manager.detectCurrentAddress()
                        stateManager.persistentTranscript = detected.fullAddress
                        await recognizer.setQuestionThought(question.text)
                    }
                } catch {
                    await recognizer.setQuestionThought(question.text)
                }
            } else {
                // Pre-populate with existing answer
                stateManager.persistentTranscript = currentAnswer
                await recognizer.setQuestionThought(question.text)
            }
        } else if question.text == "What should I call this house?" {
            if currentAnswer.isEmpty {
                // Generate suggestions from address if available
                if let addressAnswer = await getAnswer(for: "Is this the right address?") ?? 
                                          await getAnswer(for: "What's your home address?"),
                   !addressAnswer.isEmpty {
                    
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
                        await recognizer.setQuestionThought(question.text)
                    }
                } else {
                    await recognizer.setQuestionThought(question.text)
                }
            } else {
                stateManager.persistentTranscript = currentAnswer
                await recognizer.setQuestionThought(question.text)
            }
        } else if currentAnswer.isEmpty {
            // No answer yet, just ask the question
            await recognizer.setQuestionThought(question.text)
        } else {
            // Pre-populate and ask for confirmation
            stateManager.persistentTranscript = currentAnswer
            await recognizer.setQuestionThought("\(question.text) (Current answer: \(currentAnswer))")
        }
        
        return newInitializingState
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Listen for all questions complete notification to reload
        NotificationCenter.default.publisher(for: Notification.Name("AllQuestionsComplete"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadNextQuestion()
                }
            }
            .store(in: &cancellables)
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
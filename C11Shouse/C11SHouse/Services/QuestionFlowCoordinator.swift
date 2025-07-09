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
    
    /// Save an answer for the current question
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
/*
 * CONTEXT & PURPOSE:
 * NotesService+Questions provides convenience methods for working with questions
 * in the NotesService. These extensions make it easier for coordinators and
 * view models to interact with question-related functionality.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation
 *   - Created as part of Phase 5.2 refactoring
 *   - Provides typed, convenient access to question data
 *   - Reduces code duplication across coordinators
 *   - Maintains NotesService as single source of truth
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation

extension NotesServiceProtocol {
    /// Get the current question that needs to be answered
    func getCurrentQuestion() async -> Question? {
        do {
            let notesStore = try await loadNotesStore()
            return notesStore.questionsNeedingReview().first
        } catch {
            print("Error loading current question: \(error)")
            return nil
        }
    }
    
    /// Get the next unanswered question in order
    func getNextUnansweredQuestion() async -> Question? {
        do {
            let notesStore = try await loadNotesStore()
            return notesStore.sortedQuestions.first { question in
                notesStore.notes[question.id] == nil && question.isRequired
            }
        } catch {
            print("Error loading next unanswered question: \(error)")
            return nil
        }
    }
    
    /// Get all questions in a specific category
    func getQuestions(in category: QuestionCategory) async -> [Question] {
        do {
            let notesStore = try await loadNotesStore()
            return notesStore.sortedQuestions.filter { $0.category == category }
        } catch {
            print("Error loading questions for category \(category): \(error)")
            return []
        }
    }
    
    /// Check if all required questions are answered
    func areAllRequiredQuestionsAnswered() async -> Bool {
        do {
            let notesStore = try await loadNotesStore()
            return notesStore.sortedQuestions
                .filter { $0.isRequired }
                .allSatisfy { question in
                    notesStore.notes[question.id] != nil
                }
        } catch {
            print("Error checking required questions: \(error)")
            return false
        }
    }
    
    /// Get progress information for questions
    func getQuestionProgress() async -> (answered: Int, total: Int, requiredComplete: Bool) {
        do {
            let notesStore = try await loadNotesStore()
            let allQuestions = notesStore.sortedQuestions
            let answeredCount = allQuestions.filter { notesStore.notes[$0.id] != nil }.count
            let requiredQuestions = allQuestions.filter { $0.isRequired }
            let requiredAnswered = requiredQuestions.filter { notesStore.notes[$0.id] != nil }.count
            
            return (
                answered: answeredCount,
                total: allQuestions.count,
                requiredComplete: requiredAnswered == requiredQuestions.count
            )
        } catch {
            print("Error getting question progress: \(error)")
            return (answered: 0, total: 0, requiredComplete: false)
        }
    }
    
    
    /// Check if a specific question has been answered
    func isQuestionAnswered(_ questionId: UUID) async -> Bool {
        do {
            let notesStore = try await loadNotesStore()
            return notesStore.notes[questionId] != nil
        } catch {
            print("Error checking if question answered: \(error)")
            return false
        }
    }
}
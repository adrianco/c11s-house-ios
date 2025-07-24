/*
 * CONTEXT & PURPOSE:
 * ConversationStateManager handles the complex state management for conversation views.
 * It manages transcript state, TTS coordination, recording state, and user preferences,
 * extracting this complexity from ConversationView to make it more maintainable.
 *
 * DECISION HISTORY:
 * - 2025-01-09: Initial implementation
 *   - Extracted from ConversationView state management
 *   - ObservableObject for SwiftUI integration
 *   - Manages transcript persistence and editing
 *   - Coordinates TTS playback with mute preferences
 *   - Handles session state and user name
 *   - Centralizes conversation-related state logic
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation
import SwiftUI

@MainActor
class ConversationStateManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var persistentTranscript = ""
    @Published var isEditing = false
    @Published var currentSessionStart = ""
    @Published var isNewSession = true
    @Published var userName = ""
    @Published var isSavingAnswer = false
    @Published var hasPlayedInitialThought = false
    
    // MARK: - Private Properties
    
    private let notesService: NotesServiceProtocol
    private let ttsService: TTSService
    
    // MARK: - Initialization
    
    init(notesService: NotesServiceProtocol, ttsService: TTSService) {
        self.notesService = notesService
        self.ttsService = ttsService
    }
    
    // MARK: - Public Methods
    
    /// Load user name from saved notes
    func loadUserName() async {
        do {
            let questions = try await notesService.loadNotesStore().questions
            if let nameQuestion = questions.first(where: { $0.text == "What's your name?" }),
               let note = try await notesService.getNote(for: nameQuestion.id),
               !note.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                userName = note.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Error loading user name: \(error)")
        }
    }
    
    /// Update user name and save if needed
    func updateUserName(_ name: String) async {
        userName = name
        
        // Save to notes if this is from the name question
        do {
            let questions = try await notesService.loadNotesStore().questions
            if let nameQuestion = questions.first(where: { $0.text == "What's your name?" }) {
                try await notesService.saveOrUpdateNote(
                    for: nameQuestion.id,
                    answer: name,
                    metadata: ["updated_via_conversation": "true"]
                )
            }
        } catch {
            print("Error saving user name: \(error)")
        }
    }
    
    /// Prepare for new recording session
    func startNewRecordingSession() {
        currentSessionStart = persistentTranscript
        isNewSession = true
    }
    
    /// Update transcript with new content
    func updateTranscript(with newText: String) {
        if isNewSession {
            // First update in a new session - add space if needed
            if !currentSessionStart.isEmpty {
                persistentTranscript = currentSessionStart + " " + newText
            } else {
                persistentTranscript = newText
            }
            isNewSession = false
        } else {
            // Subsequent update - replace from session start
            persistentTranscript = currentSessionStart + (currentSessionStart.isEmpty ? "" : " ") + newText
        }
    }
    
    /// Clear all transcript data
    func clearTranscript() {
        persistentTranscript = ""
        currentSessionStart = ""
        isNewSession = true
    }
    
    /// Toggle editing mode
    func toggleEditing() {
        isEditing.toggle()
    }
    
    /// Speak text using TTS if not muted
    func speak(_ text: String, isMuted: Bool) async {
        print("[ConversationStateManager] speak called - text: '\(text.prefix(50))...', isMuted: \(isMuted)")
        guard !isMuted else { 
            print("[ConversationStateManager] Not speaking - muted")
            return 
        }
        guard !ttsService.isSpeaking else { 
            print("[ConversationStateManager] Not speaking - TTS already speaking")
            return 
        }
        guard !isSavingAnswer else { 
            print("[ConversationStateManager] Not speaking - saving answer")
            return 
        } // Don't speak while saving
        
        do {
            print("[ConversationStateManager] Speaking text...")
            try await ttsService.speak(text, language: nil)
        } catch {
            // Only log non-interruption errors
            if case TTSError.speechInterrupted = error {
                // Expected behavior - speech was interrupted
                print("[ConversationStateManager] Speech interrupted")
            } else {
                print("[ConversationStateManager] Error speaking: \(error)")
            }
        }
    }
    
    /// Stop any ongoing TTS
    func stopSpeaking() {
        ttsService.stopSpeaking()
    }
    
    /// Check if TTS is currently speaking
    var isSpeaking: Bool {
        ttsService.isSpeaking
    }
    
    /// Get display name for transcript header
    func getTranscriptHeader() -> String {
        if userName.isEmpty {
            return "Real-time Transcript:"
        } else {
            return "\(userName)'s Response:"
        }
    }
    
    /// Mark that answer saving has started
    func beginSavingAnswer() {
        isSavingAnswer = true
    }
    
    /// Mark that answer saving has completed
    func endSavingAnswer() {
        isSavingAnswer = false
    }
    
    /// Reset session state
    func resetSession() {
        clearTranscript()
        isEditing = false
        isSavingAnswer = false
        hasPlayedInitialThought = false
    }
    
    /// Speak a house thought using TTS if not muted
    func speakHouseThought(_ thought: HouseThought?, isMuted: Bool) async {
        guard !isMuted else { return }
        guard let thought = thought else { return }
        
        await speak(thought.thought, isMuted: isMuted)
        
        // Optionally speak the suggestion too
        if let suggestion = thought.suggestion {
            await speak(suggestion, isMuted: isMuted)
        }
    }
    
    /// Update transcript from session with proper handling
    func updateTranscriptFromSession(_ newText: String, at startIndex: String, isFinal: Bool) {
        if startIndex == currentSessionStart {
            updateTranscript(with: newText)
        }
    }
    
    /// Get the current session start index
    var currentSessionStartIndex: String {
        return currentSessionStart
    }
}
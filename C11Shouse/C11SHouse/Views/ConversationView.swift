/*
 * CONTEXT & PURPOSE:
 * ConversationView is the main interface for voice conversations with the house consciousness.
 * It provides real-time speech recognition, transcription display, and conversation state
 * management to enable natural voice interactions with the intelligent home system.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation for testing fixed speech recognition
 *   - StateObject for ConversationRecognizer lifecycle management
 *   - Status display for recording state, availability, and authorization
 *   - Real-time transcript display with confidence percentage
 *   - Error display with red background for visibility
 *   - Toggle button changes between start/stop with color feedback
 *   - Reset button to clear transcript and state
 *   - Authorization status helper for readable text
 *   - Automatic cleanup on view dismissal to prevent orphaned recordings
 *   - Disabled state for button when not authorized
 *   - Gray backgrounds for content sections
 *   - Minimum height for transcript area to prevent layout shifts
 * - 2025-07-04: Renamed from FixedSpeechTestView to ConversationView
 *   - Updated to reflect production use as conversation interface
 *   - Changed recognizer from FixedSpeechRecognizer to ConversationRecognizer
 *   - Maintained all existing functionality while clarifying purpose
 * - 2025-07-04: Added persistent transcript and editing capabilities
 *   - Transcript persists in memory while app is running
 *   - Added Edit button to toggle between view and edit modes
 *   - TextEditor for transcript editing when in edit mode
 *   - New recordings append to existing transcript instead of replacing
 *   - Manual transcript management separate from recognizer
 *   - Updated onChange to iOS 17 syntax with oldValue, newValue parameters
 * - 2025-07-04: Fixed incremental speech recognition updates
 *   - Track session start position to handle incremental updates properly
 *   - Speech recognizer sends progressive updates (e.g., "One", "One two", "One two three")
 *   - Now correctly shows final result without duplication
 * - 2025-07-07: Added HouseThoughts component
 *   - Integrated HouseThoughtsView above transcript display
 *   - Provides interactive Q&A interface for house consciousness
 *   - First question: "What's your name?" for personalization
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  ConversationView.swift
//  C11SHouse
//
//  Main view for voice conversations with the house consciousness
//

import SwiftUI
import Speech

struct ConversationView: View {
    @StateObject private var recognizer = ConversationRecognizer()
    @State private var persistentTranscript = ""
    @State private var isEditing = false
    @State private var currentSessionStart = ""
    @State private var isNewSession = true
    @State private var currentQuestion: Question?
    @State private var userName: String = ""
    @State private var isMuted = false
    @State private var hasPlayedInitialThought = false
    @State private var isLoadingQuestion = false
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    // Default house thought when no question is active
    private var defaultHouseThought: HouseThought {
        HouseThought(
            thought: "Hi!",
            emotion: .happy,
            category: .greeting,
            confidence: 1.0,
            context: nil,
            suggestion: nil
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // House Thoughts component - always visible
                HouseThoughtsView(
                    thought: recognizer.currentHouseThought ?? defaultHouseThought,
                    isMuted: $isMuted,
                    onToggleMute: toggleMute
                )
                .padding(.horizontal)
                .padding(.top)
                
                VStack(spacing: 10) {
                HStack {
                    Text("Status:")
                        .font(.headline)
                    Text(recognizer.isRecording ? "Recording" : "Ready")
                        .foregroundColor(recognizer.isRecording ? .red : .green)
                        .fontWeight(.semibold)
                }
                
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            if let error = recognizer.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(userName.isEmpty ? "Real-time Transcript:" : "\(userName)'s Response:")
                        .font(.headline)
                    
                    if recognizer.confidence > 0 {
                        Spacer()
                        Text("Confidence: \(Int(recognizer.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isEditing {
                    TextEditor(text: $persistentTranscript)
                        .padding(8)
                        .frame(minHeight: 150)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                } else {
                    ScrollView {
                        Text(persistentTranscript.isEmpty ? "Say something..." : persistentTranscript)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 150)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            
            // Button row - single row layout
            HStack(spacing: 12) {
                Button(action: {
                    if recognizer.isRecording {
                        // Stop recording and finalize the current session
                        recognizer.toggleRecording()
                        isNewSession = true
                        
                        // If we have a transcript and a current question, save the answer
                        if !recognizer.transcript.isEmpty && currentQuestion != nil {
                            saveAnswer()
                        }
                        
                        // Generate house thought based on the transcript
                        if !recognizer.transcript.isEmpty {
                            recognizer.generateHouseThought(from: recognizer.transcript)
                        }
                    } else {
                        // Stop any ongoing TTS before starting new recording
                        serviceContainer.ttsService.stopSpeaking()
                        
                        // Mark the start of a new recording session
                        currentSessionStart = persistentTranscript
                        isNewSession = true
                        recognizer.transcript = ""
                        recognizer.toggleRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                        Text(recognizer.isRecording ? "Stop" : "Start")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(recognizer.isRecording ? Color.red : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(recognizer.authorizationStatus != .authorized || isEditing)
                    
                    Button(action: {
                    isEditing.toggle()
                }) {
                    HStack {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                        Text(isEditing ? "Done" : "Edit")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isEditing ? Color.green : Color.orange)
                    .cornerRadius(10)
                }
                
                Button("Reset") {
                    recognizer.reset()
                    persistentTranscript = ""
                    currentSessionStart = ""
                    isNewSession = true
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.gray)
                .cornerRadius(10)
                    
                // Save button removed - saving happens automatically
            } // End of button HStack
            } // End of main VStack
        } // End of ScrollView
        .navigationTitle("Conversations")
        .onAppear {
            // Set default thought initially
            if recognizer.currentHouseThought == nil {
                recognizer.currentHouseThought = defaultHouseThought
            }
            loadCurrentQuestion()
            loadUserName()
        }
        .onChange(of: recognizer.currentHouseThought) { oldValue, newValue in
            // Auto-play TTS when house thought changes (unless muted)
            if !isMuted && newValue != nil && newValue?.thought != oldValue?.thought {
                // Skip the initial default thought to avoid duplicate speech
                if !hasPlayedInitialThought && newValue?.thought == defaultHouseThought.thought {
                    hasPlayedInitialThought = true
                    return
                }
                
                // Add small delay to ensure audio session is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    speakHouseThought()
                }
            }
        }
        .onChange(of: recognizer.transcript) { oldValue, newValue in
            // Handle incremental speech recognition updates
            if !newValue.isEmpty {
                if isNewSession {
                    // First update in a new session - add space if needed
                    if !currentSessionStart.isEmpty {
                        persistentTranscript = currentSessionStart + " " + newValue
                    } else {
                        persistentTranscript = newValue
                    }
                    isNewSession = false
                } else {
                    // Subsequent update - replace from session start
                    persistentTranscript = currentSessionStart + (currentSessionStart.isEmpty ? "" : " ") + newValue
                }
            }
        }
        .onDisappear {
            // Ensure recording stops when view is dismissed
            if recognizer.isRecording {
                recognizer.stopRecording()
            }
            // Stop any ongoing TTS
            serviceContainer.ttsService.stopSpeaking()
        }
    }
    
    private func authStatusText(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
    
    private func speakHouseThought() {
        guard !isMuted else { 
            print("TTS is muted")
            return 
        }
        
        guard let thought = recognizer.currentHouseThought else { 
            print("No current house thought to speak")
            return 
        }
        
        // Check if already speaking to avoid duplicate attempts
        guard !serviceContainer.ttsService.isSpeaking else {
            print("TTS is already speaking, skipping")
            return
        }
        
        print("Speaking house thought: \(thought.thought)")
        
        Task {
            do {
                // Speak the thought
                try await serviceContainer.ttsService.speak(thought.thought, language: nil)
                
                // Optionally speak the suggestion too
                if let suggestion = thought.suggestion {
                    try await serviceContainer.ttsService.speak(suggestion, language: nil)
                }
            } catch {
                // Only log non-interruption errors
                if case TTSError.speechInterrupted = error {
                    print("Speech was interrupted (expected behavior)")
                } else {
                    print("Error speaking house thought: \(error)")
                }
            }
        }
    }
    
    private func loadCurrentQuestion() {
        // Prevent duplicate loading
        guard !isLoadingQuestion else { return }
        
        isLoadingQuestion = true
        
        Task {
            do {
                // Get the first unanswered question
                let unansweredQuestions = try await serviceContainer.notesService.getUnansweredQuestions()
                if let firstQuestion = unansweredQuestions.first {
                    currentQuestion = firstQuestion
                    // Set the house thought to display the question
                    recognizer.setQuestionThought(firstQuestion.text)
                } else {
                    // No more questions - clear the current question
                    currentQuestion = nil
                    recognizer.clearHouseThought()
                }
            } catch {
                print("Error loading questions: \(error)")
            }
            
            // Reset loading flag after a delay to prevent rapid calls
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoadingQuestion = false
            }
        }
    }
    
    private func loadUserName() {
        Task {
            do {
                // Try to load the user's name if already saved
                let questions = try await serviceContainer.notesService.loadNotesStore().questions
                if let nameQuestion = questions.first(where: { $0.text == "What's your name?" }),
                   let note = try await serviceContainer.notesService.getNote(for: nameQuestion.id),
                   !note.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    userName = note.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                print("Error loading user name: \(error)")
            }
        }
    }
    
    private func saveAnswer() {
        guard let question = currentQuestion else { return }
        
        Task {
            do {
                let trimmedAnswer = persistentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Only save if there's actual content
                guard !trimmedAnswer.isEmpty else {
                    print("Skipping save - answer is empty")
                    return
                }
                
                // Save the answer
                try await serviceContainer.notesService.saveOrUpdateNote(
                    for: question.id,
                    answer: trimmedAnswer
                )
                
                // If this was the name question, update the userName
                if question.text == "What's your name?" {
                    userName = trimmedAnswer
                }
                
                // Clear the current question
                currentQuestion = nil
                persistentTranscript = ""
                
                // Small delay to allow UI to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // Load the next unanswered question
                    loadCurrentQuestion()
                }
                
            } catch {
                print("Error saving answer: \(error)")
            }
        }
    }
    
    private func toggleMute() {
        isMuted.toggle()
        if isMuted {
            // Stop any current speech when muting
            serviceContainer.ttsService.stopSpeaking()
        }
    }
    
}
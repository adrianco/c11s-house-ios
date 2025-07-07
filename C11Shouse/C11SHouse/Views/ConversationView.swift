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
    @State private var showSaveButton = false
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // House Thoughts component
                HouseThoughtsView(
                    thought: recognizer.currentHouseThought,
                    onSpeak: speakHouseThought
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
            
            HStack(spacing: 15) {
                Button(action: {
                    if recognizer.isRecording {
                        // Stop recording and finalize the current session
                        recognizer.toggleRecording()
                        isNewSession = true
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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
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
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.gray)
                .cornerRadius(10)
                
                // Save button for Q&A responses
                if currentQuestion != nil && !persistentTranscript.isEmpty {
                    Button(action: saveAnswer) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text("Save")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                }
            }
            
            }
        }
        .navigationTitle("Conversations")
        .onAppear {
            loadCurrentQuestion()
            loadUserName()
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
        guard let thought = recognizer.currentHouseThought else { return }
        
        Task {
            do {
                // Stop any current speech
                serviceContainer.ttsService.stopSpeaking()
                
                // Speak the thought
                try await serviceContainer.ttsService.speak(thought.thought, language: nil)
                
                // Optionally speak the suggestion too
                if let suggestion = thought.suggestion {
                    try await serviceContainer.ttsService.speak(suggestion, language: nil)
                }
            } catch {
                print("Error speaking house thought: \(error)")
            }
        }
    }
    
    private func loadCurrentQuestion() {
        Task {
            do {
                // Get the first unanswered question
                let unansweredQuestions = try await serviceContainer.notesService.getUnansweredQuestions()
                if let firstQuestion = unansweredQuestions.first {
                    currentQuestion = firstQuestion
                    // Set the house thought to display the question
                    recognizer.setQuestionThought(firstQuestion.text)
                }
            } catch {
                print("Error loading questions: \(error)")
            }
        }
    }
    
    private func loadUserName() {
        Task {
            do {
                // Try to load the user's name if already saved
                let questions = try await serviceContainer.notesService.loadNotesStore().questions
                if let nameQuestion = questions.first(where: { $0.text == "What's your name?" }),
                   let note = try await serviceContainer.notesService.getNote(for: nameQuestion.id) {
                    userName = note.answer
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
                // Save the answer
                try await serviceContainer.notesService.saveOrUpdateNote(
                    for: question.id,
                    answer: persistentTranscript
                )
                
                // If this was the name question, update the userName
                if question.text == "What's your name?" {
                    userName = persistentTranscript
                }
                
                // Clear the current question and load the next one
                currentQuestion = nil
                persistentTranscript = ""
                recognizer.clearHouseThought()
                
                // Load the next unanswered question
                loadCurrentQuestion()
                
            } catch {
                print("Error saving answer: \(error)")
            }
        }
    }
}
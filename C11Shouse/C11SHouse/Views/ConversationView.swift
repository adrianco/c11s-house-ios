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
 * - 2025-01-09: Swift 6 concurrency fixes
 *   - Added @preconcurrency to Speech import to suppress Sendable warnings
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
@preconcurrency import Speech

struct ConversationView: View {
    @StateObject private var recognizer = ConversationRecognizer()
    @StateObject private var stateManager: ConversationStateManager
    @StateObject private var questionFlow: QuestionFlowCoordinator
    @StateObject private var addressManager: AddressManager
    @AppStorage("conversationViewMuted") private var isMuted = false
    @State private var hasLoadedInitialQuestion = false
    @State private var isInitializing = true
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    init() {
        _stateManager = StateObject(wrappedValue: ServiceContainer.shared.conversationStateManager)
        _questionFlow = StateObject(wrappedValue: ServiceContainer.shared.questionFlowCoordinator)
        _addressManager = StateObject(wrappedValue: ServiceContainer.shared.addressManager)
    }
    
    // Default house thought when no question is active
    private var defaultHouseThought: HouseThought? {
        // Only show default thought after we've checked for questions
        guard !isInitializing else { return nil }
        
        return HouseThought(
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
                // House Thoughts component - only visible when we have a thought
                if let thought = recognizer.currentHouseThought ?? defaultHouseThought {
                    HouseThoughtsView(
                        thought: thought,
                        isMuted: $isMuted,
                        onToggleMute: toggleMute
                    )
                    .padding(.horizontal)
                    .padding(.top)
                }
                
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
                    Text(stateManager.getTranscriptHeader())
                        .font(.headline)
                    
                    if recognizer.confidence > 0 {
                        Spacer()
                        Text("Confidence: \(Int(recognizer.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Action buttons - always visible above text box
                HStack(spacing: 8) {
                    // Talk/Stop button
                    Button(action: {
                        if recognizer.isRecording {
                            // Stop recording and finalize the current session
                            recognizer.toggleRecording()
                            stateManager.isNewSession = true
                            
                            // If we have a transcript and a current question, save the answer
                            if !recognizer.transcript.isEmpty && questionFlow.currentQuestion != nil {
                                saveAnswer()
                                // Don't generate a generic thought when we're answering questions
                            } else if !recognizer.transcript.isEmpty {
                                // Only generate house thought if not in question mode
                                recognizer.generateHouseThought(from: recognizer.transcript)
                            }
                        } else {
                            // Stop any ongoing TTS before starting new recording
                            stateManager.stopSpeaking()
                            
                            // Mark the start of a new recording session
                            stateManager.startNewRecordingSession()
                            recognizer.transcript = ""
                            recognizer.toggleRecording()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: recognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .imageScale(.medium)
                            Text(recognizer.isRecording ? "Stop" : "Talk")
                                .font(.caption)
                        }
                        .foregroundColor(recognizer.isRecording ? .red : .blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(recognizer.authorizationStatus != .authorized || stateManager.isEditing)
                    
                    Spacer()
                    
                    // Save button - only visible when there's text and a question
                    if !stateManager.persistentTranscript.isEmpty && questionFlow.currentQuestion != nil {
                        Button(action: {
                            saveAnswer()
                        }) {
                            Text("Save")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Spacer()
                    }
                    
                    // Edit button
                    Button(action: {
                        stateManager.toggleEditing()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .imageScale(.medium)
                            Text("Edit")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Spacer()
                    
                    // Clear button
                    Button(action: {
                        recognizer.reset()
                        stateManager.clearTranscript()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .imageScale(.medium)
                            Text("Clear")
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
                
                if stateManager.isEditing {
                    TextEditor(text: $stateManager.persistentTranscript)
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
                        Text(stateManager.persistentTranscript.isEmpty ? "Say something..." : stateManager.persistentTranscript)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 150)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            } // End of main VStack
        } // End of ScrollView
        .navigationTitle("Conversations")
        .onAppear {
            // Only load the initial question once
            if !hasLoadedInitialQuestion {
                hasLoadedInitialQuestion = true
                // Load question immediately without default thought
                Task {
                    await questionFlow.loadNextQuestion()
                    await stateManager.loadUserName()
                }
            }
        }
        .onChange(of: recognizer.currentHouseThought) { oldValue, newValue in
            // Auto-play TTS when house thought changes (unless muted)
            if !isMuted && newValue != nil && newValue?.thought != oldValue?.thought {
                // Skip the initial default thought to avoid duplicate speech
                if !stateManager.hasPlayedInitialThought && newValue?.thought == defaultHouseThought?.thought {
                    stateManager.hasPlayedInitialThought = true
                    return
                }
                
                // Skip speaking during answer saving to prevent conflicts
                if stateManager.isSavingAnswer {
                    return
                }
                
                // Add small delay to ensure audio session is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    speakHouseThought()
                }
            }
        }
        .onChange(of: recognizer.transcript) { oldValue, newValue in
            // Handle incremental speech recognition updates
            if !newValue.isEmpty {
                stateManager.updateTranscript(with: newValue)
            }
        }
        .onChange(of: questionFlow.currentQuestion) { oldValue, newValue in
            // Handle question changes
            Task {
                await handleQuestionChange(oldQuestion: oldValue, newQuestion: newValue)
            }
        }
        .onDisappear {
            // Ensure recording stops when view is dismissed
            if recognizer.isRecording {
                recognizer.stopRecording()
            }
            // Stop any ongoing TTS
            stateManager.stopSpeaking()
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
        guard !isMuted else { return }
        guard let thought = recognizer.currentHouseThought else { return }
        
        Task {
            await stateManager.speak(thought.thought, isMuted: isMuted)
            
            // Optionally speak the suggestion too
            if let suggestion = thought.suggestion {
                await stateManager.speak(suggestion, isMuted: isMuted)
            }
        }
    }
    
    private func handleQuestionChange(oldQuestion: Question?, newQuestion: Question?) async {
        guard let question = newQuestion else {
            // No more questions
            if questionFlow.hasCompletedAllQuestions {
                recognizer.setThankYouThought()
            }
            return
        }
        
        // Mark initialization as complete
        isInitializing = false
        
        // Get current answer if any
        let currentAnswer = await questionFlow.getCurrentAnswer(for: question) ?? ""
        
        // Handle different question types
        if question.text == "Is this the right address?" || question.text == "What's your home address?" {
            if currentAnswer.isEmpty {
                // Try to detect the address
                do {
                    let detected = try await addressManager.detectCurrentAddress()
                    stateManager.persistentTranscript = detected.fullAddress
                    recognizer.setQuestionThought(question.text)
                } catch {
                    recognizer.setQuestionThought(question.text)
                }
            } else {
                // Pre-populate with existing answer
                stateManager.persistentTranscript = currentAnswer
                recognizer.setQuestionThought(question.text)
            }
        } else if question.text == "What should I call this house?" {
            if currentAnswer.isEmpty {
                // Generate suggestion from address if available
                if let addressAnswer = await questionFlow.getAnswer(for: "Is this the right address?"),
                   !addressAnswer.isEmpty {
                    let suggestedName = addressManager.generateHouseName(from: addressAnswer)
                    stateManager.persistentTranscript = suggestedName
                }
            } else {
                stateManager.persistentTranscript = currentAnswer
            }
            recognizer.setQuestionThought(question.text)
        } else if currentAnswer.isEmpty {
            // No answer yet, just ask the question
            recognizer.setQuestionThought(question.text)
        } else {
            // Pre-populate and ask for confirmation
            stateManager.persistentTranscript = currentAnswer
            recognizer.setQuestionThought("\(question.text) (Current answer: \(currentAnswer))")
        }
    }
    
    
    private func saveAnswer() {
        guard let question = questionFlow.currentQuestion else { return }
        
        // Prevent multiple saves
        guard !stateManager.isSavingAnswer else { return }
        
        stateManager.beginSavingAnswer()
        
        Task {
            do {
                let trimmedAnswer = stateManager.persistentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Clear any existing house thought to prevent duplicate speech
                recognizer.clearHouseThought()
                
                // Save the answer
                try await questionFlow.saveAnswer(trimmedAnswer)
                
                // If this was the name question, update the userName
                if question.text == "What's your name?" {
                    await stateManager.updateUserName(trimmedAnswer)
                }
                
                // If this was the address question, save it properly
                if question.text == "Is this the right address?" || question.text == "What's your home address?" {
                    if let address = addressManager.parseAddress(trimmedAnswer) {
                        try await addressManager.saveAddress(address)
                    }
                }
                
                // If this was the house name question, save it to ContentViewModel
                if question.text == "What should I call this house?" {
                    await serviceContainer.notesService.saveHouseName(trimmedAnswer)
                }
                
                // Clear the transcript
                stateManager.clearTranscript()
                
            } catch {
                print("Error saving answer: \(error)")
            }
            
            stateManager.endSavingAnswer()
        }
    }
    
    private func toggleMute() {
        isMuted.toggle()
        
        if isMuted {
            // Stop any current speech when muting
            stateManager.stopSpeaking()
        }
    }
    
    
}
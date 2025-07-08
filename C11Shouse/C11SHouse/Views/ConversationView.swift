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
    @AppStorage("conversationViewMuted") private var isMuted = false
    @State private var hasPlayedInitialThought = false
    @State private var isLoadingQuestion = false
    @State private var isSavingAnswer = false
    @State private var hasLoadedInitialQuestion = false
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
                
                // Show action buttons when editing or when transcript has content
                if isEditing || !persistentTranscript.isEmpty {
                    HStack {
                        if isEditing {
                            Button(action: {
                                // Cancel editing - restore original text
                                persistentTranscript = currentSessionStart
                                isEditing = false
                            }) {
                                Text("Cancel")
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        Spacer()
                        
                        if !persistentTranscript.isEmpty && currentQuestion != nil {
                            Button(action: {
                                saveAnswer()
                            }) {
                                Text("Save")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
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
            
            // Button row - matching Notes view style
            HStack(spacing: 16) {
                Button(action: {
                    if recognizer.isRecording {
                        // Stop recording and finalize the current session
                        recognizer.toggleRecording()
                        isNewSession = true
                        
                        // If we have a transcript and a current question, save the answer
                        if !recognizer.transcript.isEmpty && currentQuestion != nil {
                            saveAnswer()
                            // Don't generate a generic thought when we're answering questions
                        } else if !recognizer.transcript.isEmpty {
                            // Only generate house thought if not in question mode
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
                        Image(systemName: recognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .imageScale(.large)
                        Text(recognizer.isRecording ? "Stop" : "Start")
                    }
                    .foregroundColor(recognizer.isRecording ? .red : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(recognizer.authorizationStatus != .authorized || isEditing)
                    
                Spacer()
                    
                Button(action: {
                    isEditing.toggle()
                }) {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .imageScale(.large)
                        Text("Edit")
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()
                
                Button(action: {
                    recognizer.reset()
                    persistentTranscript = ""
                    currentSessionStart = ""
                    isNewSession = true
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .imageScale(.large)
                        Text("Reset")
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(BorderlessButtonStyle())
            } // End of button HStack
            } // End of main VStack
        } // End of ScrollView
        .navigationTitle("Conversations")
        .onAppear {
            // Only load the initial question once
            if !hasLoadedInitialQuestion {
                hasLoadedInitialQuestion = true
                // Load question immediately without default thought
                loadCurrentQuestion()
                loadUserName()
            }
        }
        .onChange(of: recognizer.currentHouseThought) { oldValue, newValue in
            // Auto-play TTS when house thought changes (unless muted)
            if !isMuted && newValue != nil && newValue?.thought != oldValue?.thought {
                // Skip the initial default thought to avoid duplicate speech
                if !hasPlayedInitialThought && newValue?.thought == defaultHouseThought.thought {
                    hasPlayedInitialThought = true
                    return
                }
                
                // Skip speaking during answer saving to prevent conflicts
                if isSavingAnswer {
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
        guard !isMuted else { return }
        guard let thought = recognizer.currentHouseThought else { return }
        guard !serviceContainer.ttsService.isSpeaking else { return }
        
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
                    // Expected behavior - speech was interrupted
                } else {
                    print("Error speaking: \(error)")
                }
            }
        }
    }
    
    private func loadCurrentQuestion() {
        // Prevent duplicate loading
        guard !isLoadingQuestion else { 
            return 
        }
        
        isLoadingQuestion = true
        
        Task {
            do {
                // Get questions that need review (required questions first)
                let notesStore = try await serviceContainer.notesService.loadNotesStore()
                let questionsNeedingReview = notesStore.questionsNeedingReview()
                
                if let firstQuestion = questionsNeedingReview.first {
                    
                    // Get the current answer if any
                    let currentNote = notesStore.notes[firstQuestion.id]
                    let currentAnswer = currentNote?.answer ?? ""
                    
                    await MainActor.run {
                        currentQuestion = firstQuestion
                        
                        // For address question, special handling (check both old and new texts)
                        if firstQuestion.text == "Is this the right address?" || firstQuestion.text == "What's your home address?" {
                            if currentAnswer.isEmpty {
                                // Try to detect the address
                                Task {
                                    await detectAndPreloadAddress(for: firstQuestion)
                                }
                            } else {
                                // Pre-populate with existing answer
                                persistentTranscript = currentAnswer
                                recognizer.setQuestionThought(firstQuestion.text)
                            }
                        } else if currentAnswer.isEmpty {
                            // No answer yet, just ask the question
                            recognizer.setQuestionThought(firstQuestion.text)
                        } else {
                            // For other questions with answers, pre-populate and ask for confirmation
                            persistentTranscript = currentAnswer
                            recognizer.setQuestionThought("\(firstQuestion.text) (Current answer: \(currentAnswer))")
                        }
                    }
                } else {
                    await MainActor.run {
                        // No more questions - clear the current question
                        currentQuestion = nil
                        recognizer.setThankYouThought()
                    }
                }
            } catch {
                // Error loading questions
            }
            
            // Reset loading flag after a delay to prevent rapid calls
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isLoadingQuestion = false
                }
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
        
        // Prevent multiple saves
        guard !isSavingAnswer else { return }
        
        isSavingAnswer = true
        
        Task {
            do {
                let trimmedAnswer = persistentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Only save if there's actual content
                guard !trimmedAnswer.isEmpty else {
                    isSavingAnswer = false
                    return
                }
                
                // Clear any existing house thought to prevent duplicate speech
                recognizer.clearHouseThought()
                
                // Save the answer with conversation metadata
                try await serviceContainer.notesService.saveOrUpdateNote(
                    for: question.id,
                    answer: trimmedAnswer,
                    metadata: ["updated_via_conversation": "true"]
                )
                
                // If this was the name question, update the userName
                if question.text == "What's your name?" {
                    userName = trimmedAnswer
                }
                
                // If this was the address question, save it properly and generate house name
                if question.text == "Is this the right address?" || question.text == "What's your home address?" {
                    await handleAddressSaved(trimmedAnswer)
                }
                
                // Clear the current question
                currentQuestion = nil
                persistentTranscript = ""
                
                // Small delay to allow UI to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Load the next unanswered question
                    loadCurrentQuestion()
                    isSavingAnswer = false
                }
                
            } catch {
                print("Error saving answer: \(error)")
                isSavingAnswer = false
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
    
    private func detectAndPreloadAddress(for question: Question) async {
        do {
            // Check if we have location permission
            let status = await serviceContainer.locationService.authorizationStatusPublisher.values.first { _ in true } ?? .notDetermined
            
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                // No permission, just ask the question
                await MainActor.run {
                    recognizer.setQuestionThought(question.text)
                }
                return
            }
            
            // Try to detect the address
            let location = try await serviceContainer.locationService.getCurrentLocation()
            let address = try await serviceContainer.locationService.lookupAddress(for: location)
            
            await MainActor.run {
                // Pre-populate the transcript with detected address
                persistentTranscript = address.fullAddress
                recognizer.setQuestionThought(question.text)
            }
        } catch {
            await MainActor.run {
                // On error, just ask the question normally
                recognizer.setQuestionThought(question.text)
            }
        }
    }
    
    private func handleAddressSaved(_ addressText: String) async {
        // Parse the address and save it properly
        let components = addressText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        if components.count >= 3 {
            // Try to get coordinates from current location
            var coordinate = Coordinate(latitude: 0, longitude: 0)
            
            do {
                let location = try await serviceContainer.locationService.getCurrentLocation()
                coordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            } catch {
                // Could not get coordinates
            }
            
            let street = components[0]
            let city = components[1]
            let stateZip = components[2].components(separatedBy: " ")
            let state = stateZip.first ?? ""
            let postalCode = stateZip.count > 1 ? stateZip[1] : ""
            
            let address = Address(
                street: street,
                city: city,
                state: state,
                postalCode: postalCode,
                country: "United States",
                coordinate: coordinate
            )
            
            // Save to UserDefaults and LocationService
            if let encoded = try? JSONEncoder().encode(address) {
                UserDefaults.standard.set(encoded, forKey: "confirmedHomeAddress")
            }
            
            do {
                try await serviceContainer.locationService.confirmAddress(address)
            } catch {
                print("Error confirming address: \(error)")
            }
            
            // Generate and save house name
            let streetName = street
                .replacingOccurrences(of: #"\d+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\b(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Place|Pl|Way|Circle|Cir|Terrace|Ter|Parkway|Pkwy)\.?\b"#, 
                                    with: "", 
                                    options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !streetName.isEmpty {
                let houseName = "\(streetName) House"
                await serviceContainer.notesService.saveHouseName(houseName)
            }
        }
    }
    
}
/*
 * CONTEXT & PURPOSE:
 * ConversationView provides a chat-style interface for conversations between the user and house.
 * It supports both voice and text input, with a scrolling message history and mute toggle.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Complete redesign as chat interface
 *   - Chat bubble UI similar to messaging apps
 *   - Scrolling message history with persistence
 *   - Mute button for voice/text mode switching
 *   - Voice recognition when unmuted
 *   - Text input when muted
 *   - Auto-scroll to latest message
 *   - Message timestamps
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI
@preconcurrency import Speech

struct ConversationView: View {
    @StateObject private var messageStore = MessageStore()
    @StateObject private var recognizer = ConversationRecognizer()
    @StateObject private var stateManager: ConversationStateManager
    @StateObject private var questionFlow: QuestionFlowCoordinator
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @Environment(\.presentationMode) var presentationMode
    
    @State private var inputText = ""
    @State private var isMuted = false
    @State private var isProcessing = false
    @State private var scrollToBottom = false
    @State private var pendingVoiceText = ""
    @State private var showVoiceConfirmation = false
    @State private var houseName = "House Chat"
    @FocusState private var isTextFieldFocused: Bool
    
    init() {
        let conversationStateManager = ViewModelFactory.shared.makeConversationStateManager()
        _stateManager = StateObject(wrappedValue: conversationStateManager)
        _questionFlow = StateObject(wrappedValue: ServiceContainer.shared.questionFlowCoordinator)
        
        // Set up dependencies
        ServiceContainer.shared.questionFlowCoordinator.conversationStateManager = conversationStateManager
        ServiceContainer.shared.questionFlowCoordinator.addressManager = ServiceContainer.shared.addressManager
        ServiceContainer.shared.questionFlowCoordinator.serviceContainer = ServiceContainer.shared
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back and mute buttons
            HStack {
                // Back button
                NavigationLink(destination: EmptyView()) {
                    EmptyView()
                }
                .navigationBarBackButtonHidden(true)
                .overlay(
                    Button(action: {
                        // Use presentationMode to go back
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Back")
                                .font(.body)
                        }
                        .foregroundColor(.blue)
                    }
                )
                
                Spacer()
                
                Text(houseName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Mute/Unmute button
                Button(action: {
                    isMuted.toggle()
                    if isMuted && recognizer.isRecording {
                        recognizer.stopRecording()
                    }
                    if isMuted {
                        stateManager.stopSpeaking()
                    }
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundColor(isMuted ? .gray : .blue)
                        .frame(width: 44, height: 44)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .shadow(radius: 1)
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messageStore.messages) { message in
                            MessageBubble(message: message) { editedAddress in
                                // Handle address submission
                                handleAddressSubmission(editedAddress)
                            }
                            .id(message.id)
                        }
                        
                        // Invisible anchor for scrolling with extra padding
                        Color.clear
                            .frame(height: 60) // Increased height to ensure messages clear the input area
                            .id("bottom")
                    }
                    .padding()
                    .padding(.bottom, 20) // Extra bottom padding
                }
                .onChange(of: messageStore.messages.count) { _, _ in
                    // Delay slightly to ensure message is rendered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: scrollToBottom) { _, shouldScroll in
                    if shouldScroll {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                        scrollToBottom = false
                    }
                }
            }
            
            // Input area
            VStack(spacing: 0) {
                if let error = recognizer.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
                
                HStack(spacing: 12) {
                    if isMuted {
                        // Text input field
                        TextField("Type a message...", text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                sendTextMessage()
                            }
                        
                        // Send button
                        Button(action: sendTextMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(inputText.isEmpty ? .gray : .blue)
                        }
                        .disabled(inputText.isEmpty || isProcessing)
                    } else {
                        // Voice input
                        if showVoiceConfirmation {
                            // Show editable transcription with label
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "mic.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("Review and edit your message:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                TextField("Edit your message...", text: $pendingVoiceText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($isTextFieldFocused)
                                    .onSubmit {
                                        confirmVoiceMessage()
                                    }
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    showVoiceConfirmation = false
                                    pendingVoiceText = ""
                                    recognizer.transcript = ""
                                    isTextFieldFocused = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }
                                
                                Button(action: confirmVoiceMessage) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(pendingVoiceText.isEmpty ? .gray : .green)
                                }
                                .disabled(pendingVoiceText.isEmpty)
                            }
                        } else {
                            HStack {
                                // Show live transcript while recording
                                if recognizer.isRecording && !recognizer.transcript.isEmpty {
                                    Text(recognizer.transcript)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.secondarySystemFill))
                                        .cornerRadius(12)
                                        .transition(.opacity)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Spacer()
                                }
                                
                                VStack(spacing: 4) {
                                    Button(action: toggleRecording) {
                                        Image(systemName: recognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(recognizer.isRecording ? .red : .blue)
                                    }
                                    .disabled(recognizer.authorizationStatus != .authorized || isProcessing)
                                    
                                    Text(recognizer.isRecording ? "Recording..." : "Tap to speak")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !recognizer.isRecording || recognizer.transcript.isEmpty {
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("[ConversationView] onAppear called")
            print("[ConversationView] hasCompletedPhase4Tutorial: \(UserDefaults.standard.bool(forKey: "hasCompletedPhase4Tutorial"))")
            print("[ConversationView] isInPhase4Tutorial: \(UserDefaults.standard.bool(forKey: "isInPhase4Tutorial"))")
            setupView()
        }
        .onChange(of: recognizer.transcript) { oldValue, newValue in
            // Update pending voice text while recording
            if recognizer.isRecording && !newValue.isEmpty {
                pendingVoiceText = newValue
            }
        }
        .onChange(of: recognizer.isRecording) { oldValue, newValue in
            // When recording stops, show confirmation if we have text
            if oldValue == true && newValue == false && !pendingVoiceText.isEmpty {
                // Show confirmation with editable text
                showVoiceConfirmation = true
                isTextFieldFocused = true
            }
        }
        .onChange(of: questionFlow.currentQuestion) { oldValue, newValue in
            // When a new question appears, add it to the chat
            if let question = newValue, oldValue != newValue {
                Task { @MainActor in
                    // First, let handleQuestionChange process the question
                    _ = await questionFlow.handleQuestionChange(oldQuestion: oldValue, newQuestion: newValue, isInitializing: false)
                    
                    // Give a moment for any state updates to settle
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
                    
                    var messageContent = question.text
                    var spokenContent = question.text
                    
                    // Check if there's a house thought with suggestions
                    if let houseThought = recognizer.currentHouseThought {
                        messageContent = houseThought.thought
                        if let suggestion = houseThought.suggestion {
                            messageContent += "\n\n" + suggestion
                        }
                        // For address questions, only speak the question part, not the address
                        if question.text.contains("address") && houseThought.thought.contains("\n") {
                            spokenContent = houseThought.thought.components(separatedBy: "\n").first ?? houseThought.thought
                        } else {
                            spokenContent = houseThought.thought
                        }
                    } else {
                        // Special handling for address questions
                        if question.text == "Is this the right address?" || question.text == "What's your home address?" {
                            // Try to detect current address
                            if let addressManager = questionFlow.addressManager {
                                do {
                                    let detectedAddress = try await addressManager.detectCurrentAddress()
                                    messageContent = "Is this the right address?\n\(detectedAddress.fullAddress)"
                                } catch {
                                    // If detection fails, just show the question
                                    messageContent = "What's your home address?"
                                }
                            }
                        }
                    }
                    
                    // Add question message immediately on main actor
                    let questionMessage = Message(
                        content: messageContent,
                        isFromUser: false,
                        isVoice: !isMuted
                    )
                    messageStore.addMessage(questionMessage)
                    
                    // Check for pre-populated transcript after handleQuestionChange
                    if !stateManager.persistentTranscript.isEmpty {
                        inputText = stateManager.persistentTranscript
                        // Force text field update
                        isTextFieldFocused = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isTextFieldFocused = true
                        }
                    }
                    
                    // Trigger scroll to bottom after a brief delay to ensure message is rendered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom = true
                    }
                    
                    // Speak the question if not muted
                    if !isMuted {
                        // Wait a moment for any previous speech to complete
                        Task {
                            // If TTS is currently speaking, wait for it to finish
                            while stateManager.isSpeaking {
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                            }
                            // Add a small pause for natural conversation flow
                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                            // Now speak the question
                            try? await stateManager.speak(spokenContent, isMuted: isMuted)
                        }
                    }
                }
            }
        }
        .onDisappear {
            if recognizer.isRecording {
                recognizer.stopRecording()
            }
            stateManager.stopSpeaking()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClearChatHistory"))) { _ in
            print("[ConversationView] Received ClearChatHistory notification")
            messageStore.clearAllMessages()
            // Also add a welcome message after clearing
            let welcomeMessage = Message(
                content: "Hello! I'm your house consciousness. How can I help you today?",
                isFromUser: false,
                isVoice: false
            )
            messageStore.addMessage(welcomeMessage)
            print("[ConversationView] Chat cleared and welcome message added")
        }
    }
    
    private func setupView() {
        print("[ConversationView] setupView() called")
        
        // Set up recognizer reference
        questionFlow.conversationRecognizer = recognizer
        
        // Set up address suggestion service if not already set
        if questionFlow.addressSuggestionService == nil {
            questionFlow.addressSuggestionService = ServiceContainer.shared.addressSuggestionService
        }
        
        // Load initial state
        Task {
            print("[ConversationView] Loading initial state...")
            await stateManager.loadUserName()
            
            // Load house name
            if let savedHouseName = await serviceContainer.notesService.getHouseName(),
               !savedHouseName.isEmpty {
                houseName = savedHouseName
                print("[ConversationView] Loaded house name: \(houseName)")
            } else {
                print("[ConversationView] No saved house name found")
            }
            
            // Add welcome message if no messages exist
            if messageStore.messages.isEmpty {
                print("[ConversationView] Adding welcome message")
                let welcomeMessage = Message(
                    content: "Hello! I'm your house consciousness. How can I help you today?",
                    isFromUser: false,
                    isVoice: false
                )
                messageStore.addMessage(welcomeMessage)
            } else {
                print("[ConversationView] Found \(messageStore.messages.count) existing messages")
            }
            
            // Pre-fetch location in background if permissions are granted
            Task.detached(priority: .background) {
                let locationService = ServiceContainer.shared.locationService
                await locationService.requestLocationPermission()
            }
            
            // Load any pending questions
            print("[ConversationView] Loading next question...")
            await questionFlow.loadNextQuestion()
            
            // Check if all questions are complete and start Phase 4 tutorial
            print("[ConversationView] hasCompletedAllQuestions: \(questionFlow.hasCompletedAllQuestions)")
            if questionFlow.hasCompletedAllQuestions {
                print("[ConversationView] All questions complete, starting Phase 4 tutorial")
                await startPhase4Tutorial()
            } else {
                print("[ConversationView] Questions still pending, current: \(questionFlow.currentQuestion?.text ?? "none")")
            }
            
            // Scroll to bottom after initial setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                scrollToBottom = true
            }
        }
    }
    
    private func toggleRecording() {
        if recognizer.isRecording {
            recognizer.stopRecording()
        } else {
            stateManager.stopSpeaking()
            recognizer.transcript = ""
            pendingVoiceText = ""  // Clear any previous pending text
            showVoiceConfirmation = false  // Ensure confirmation is hidden
            recognizer.toggleRecording()
        }
    }
    
    private func sendTextMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMessage = Message(content: text, isFromUser: true, isVoice: false)
        messageStore.addMessage(userMessage)
        
        // Clear input
        inputText = ""
        
        // Process message
        processUserInput(text)
    }
    
    private func confirmVoiceMessage() {
        let text = pendingVoiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMessage = Message(content: text, isFromUser: true, isVoice: true)
        messageStore.addMessage(userMessage)
        
        // Clear voice confirmation and recognizer state
        pendingVoiceText = ""
        showVoiceConfirmation = false
        recognizer.transcript = ""
        isTextFieldFocused = false
        
        // Process message
        processUserInput(text)
    }
    
    
    private func processUserInput(_ input: String) {
        print("[ConversationView] processUserInput: '\(input)'")
        isProcessing = true
        
        Task { @MainActor in
            // Update state manager transcript
            stateManager.persistentTranscript = input
            
            // Check if this answers a current question
            if let currentQuestion = questionFlow.currentQuestion {
                print("[ConversationView] Answering question: \(currentQuestion.text)")
                
                // Check if this is the Phase 4 introduction question
                if currentQuestion.text.contains("Let's start by creating your first room note") {
                    print("[ConversationView] This is the Phase 4 intro question, handling specially")
                    
                    // Save the room name as the answer
                    await questionFlow.saveAnswer()
                    
                    // Transition directly to room note details
                    UserDefaults.standard.set(input, forKey: "pendingRoomName")
                    UserDefaults.standard.set("awaitingRoomDetails", forKey: "noteCreationState")
                    
                    let detailsMessage = Message(
                        content: "Great! Now tell me about your \(input). What would you like me to remember about this room?",
                        isFromUser: false,
                        isVoice: !isMuted
                    )
                    messageStore.addMessage(detailsMessage)
                    
                    if !isMuted {
                        try? await stateManager.speak(detailsMessage.content, isMuted: isMuted)
                    }
                } else {
                    // Normal question handling
                    await questionFlow.saveAnswer()
                    
                    // Add acknowledgment message immediately
                    let acknowledgment = Message(
                        content: "Thank you! I've saved that information.",
                        isFromUser: false,
                        isVoice: !isMuted
                    )
                    messageStore.addMessage(acknowledgment)
                    
                    // Speak acknowledgment and wait for completion
                    if !isMuted {
                        let thought = HouseThought(
                            thought: "Thank you! I've saved that information.",
                            emotion: .happy,
                            category: .greeting,
                            confidence: 1.0
                        )
                        // Wait for speech to complete before loading next question
                        try? await stateManager.speak(thought.thought, isMuted: isMuted)
                        
                        // Add a small pause after thank you for natural flow
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    }
                    
                    // Load next question after acknowledgment is complete
                    print("[ConversationView] Loading next question...")
                    await questionFlow.loadNextQuestion()
                    
                    // Check if all questions are complete
                    print("[ConversationView] After loading, hasCompletedAllQuestions: \(questionFlow.hasCompletedAllQuestions)")
                    if questionFlow.hasCompletedAllQuestions {
                        print("[ConversationView] All questions complete after answer, starting Phase 4")
                        await startPhase4Tutorial()
                    }
                }
            } else {
                // Check if we're in Phase 4 tutorial
                if UserDefaults.standard.bool(forKey: "isInPhase4Tutorial") {
                    await handlePhase4TutorialInput(input)
                } else {
                    // Check if we're in the middle of creating a note
                    let noteCreationState = UserDefaults.standard.string(forKey: "noteCreationState")
                    if noteCreationState == "creatingRoomNote" {
                        // User provided room name, now ask for details
                        await handleRoomNoteNameProvided(input)
                    } else if noteCreationState == "awaitingRoomDetails" {
                        // User provided room details, save the note
                        await handleRoomNoteDetailsProvided(input)
                    } else {
                        // Check for note creation commands
                        let lowercased = input.lowercased()
                        if lowercased.contains("new room note") || lowercased.contains("add room note") {
                            await handleRoomNoteCreation()
                        } else if lowercased.contains("new device note") || lowercased.contains("add device note") {
                            await handleDeviceNoteCreation()
                        } else {
                            // Generate house response
                            await generateHouseResponse(for: input)
                        }
                    }
                }
            }
            
            await MainActor.run {
                isProcessing = false
                scrollToBottom = true
            }
        }
    }
    
    private func generateHouseResponse(for input: String) async {
        // Generate a house thought based on input
        let thought = HouseThought(
            thought: "Let me think about that...",
            emotion: .thoughtful,
            category: .observation,
            confidence: 0.8
        )
        
        await MainActor.run {
            // Add house message
            let houseMessage = Message(
                content: thought.thought,
                isFromUser: false,
                isVoice: !isMuted
            )
            messageStore.addMessage(houseMessage)
            
            // Speak if not muted
            if !isMuted {
                Task {
                    try? await stateManager.speak(thought.thought, isMuted: isMuted)
                }
            }
        }
    }
    
    private func handleRoomNoteCreation() async {
        // Check if Phase 4 tutorial should have run but didn't
        if questionFlow.hasCompletedAllQuestions && !UserDefaults.standard.bool(forKey: "hasCompletedPhase4Tutorial") {
            // Start Phase 4 tutorial instead
            await startPhase4Tutorial()
        } else {
            let thought = HouseThought(
                thought: "I'll help you create a room note. What room would you like to add a note about?",
                emotion: .curious,
                category: .question,
                confidence: 1.0
            )
            
            await MainActor.run {
                let message = Message(
                    content: thought.thought,
                    isFromUser: false,
                    isVoice: !isMuted
                )
                messageStore.addMessage(message)
                
                if !isMuted {
                    Task {
                        try? await stateManager.speak(thought.thought, isMuted: isMuted)
                    }
                }
            }
            
            // Mark that we're creating a room note
            UserDefaults.standard.set("creatingRoomNote", forKey: "noteCreationState")
        }
    }
    
    private func handleDeviceNoteCreation() async {
        let thought = HouseThought(
            thought: "I'll help you create a device note. What device or appliance would you like to add a note about?",
            emotion: .curious,
            category: .question,
            confidence: 1.0
        )
        
        await MainActor.run {
            let message = Message(
                content: thought.thought,
                isFromUser: false,
                isVoice: !isMuted
            )
            messageStore.addMessage(message)
            
            if !isMuted {
                Task {
                    try? await stateManager.speak(thought.thought, isMuted: isMuted)
                }
            }
        }
    }
    
    private func handleAddressSubmission(_ address: String) {
        // Add user's response as a message
        let userMessage = Message(
            content: address,
            isFromUser: true,
            isVoice: false
        )
        messageStore.addMessage(userMessage)
        
        // Process as regular input
        processUserInput(address)
    }
    
    // MARK: - Phase 4 Tutorial
    
    private func startPhase4Tutorial() async {
        print("[ConversationView] startPhase4Tutorial() called - no longer needed, Phase 4 is handled as a required question")
        // This method is kept for backward compatibility but doesn't do anything
        // Phase 4 is now handled as the 4th required question
    }
    
    private func checkIfUserHasNotes() async -> Bool {
        // Check if user has created any room or device notes
        do {
            let notesStore = try await serviceContainer.notesService.loadNotesStore()
            // Check for non-required notes (room/device notes)
            return notesStore.notes.values.contains(where: { note in
                if let noteQuestion = notesStore.questions.first(where: { $0.id == note.questionId }) {
                    return !noteQuestion.isRequired && note.isAnswered
                }
                return false
            })
        } catch {
            return false
        }
    }
    
    private func handlePhase4TutorialInput(_ input: String) async {
        let tutorialState = UserDefaults.standard.string(forKey: "phase4TutorialState") ?? ""
        
        switch tutorialState {
        case "awaitingRoomName":
            // User provided room name
            let roomName = input.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Save this as the current room for context
            UserDefaults.standard.set(roomName, forKey: "currentRoomForTutorial")
            
            // Ask about the room details
            let response = """
            Great! I'll remember that you're in the \(roomName).
            
            Tell me about this room, and things that are in it, that you might want to know about in the future. Are there any connected devices here, or things that you sometimes forget how to operate?
            """
            
            let thought = HouseThought(
                thought: response,
                emotion: .curious,
                category: .question,
                confidence: 1.0
            )
            
            await MainActor.run {
                let message = Message(
                    content: thought.thought,
                    isFromUser: false,
                    isVoice: !isMuted
                )
                messageStore.addMessage(message)
                
                if !isMuted {
                    Task {
                        try? await stateManager.speak(thought.thought, isMuted: isMuted)
                    }
                }
            }
            
            UserDefaults.standard.set("awaitingRoomDetails", forKey: "phase4TutorialState")
            
        case "awaitingRoomDetails":
            // User provided room details
            let roomName = UserDefaults.standard.string(forKey: "currentRoomForTutorial") ?? "Room"
            
            // Create a room note
            do {
                // Create a new question for this room
                let roomQuestion = Question(
                    id: UUID(),
                    text: roomName,
                    category: .other,
                    displayOrder: 1000,
                    isRequired: false
                )
                
                // Save the note with room type metadata
                try await serviceContainer.notesService.saveOrUpdateNote(
                    for: roomQuestion.id,
                    answer: input,
                    metadata: [
                        "type": "room",
                        "updated_via_conversation": "true",
                        "createdDate": Date().ISO8601Format()
                    ]
                )
                
                // Complete tutorial
                UserDefaults.standard.set(false, forKey: "isInPhase4Tutorial")
                UserDefaults.standard.removeObject(forKey: "phase4TutorialState")
                UserDefaults.standard.removeObject(forKey: "currentRoomForTutorial")
                UserDefaults.standard.set(true, forKey: "hasCompletedPhase4Tutorial")
                
                let completionMessage = """
                Excellent! I've saved that information about the \(roomName).
                
                You can see and edit all your notes from the main screen. To add more notes in the future, just say something like 'new room note' or 'new device note' and I'll help you create them.
                
                Is there anything else you'd like to know about your home?
                """
                
                let thought = HouseThought(
                    thought: completionMessage,
                    emotion: .happy,
                    category: .suggestion,
                    confidence: 1.0
                )
                
                await MainActor.run {
                    let message = Message(
                        content: thought.thought,
                        isFromUser: false,
                        isVoice: !isMuted
                    )
                    messageStore.addMessage(message)
                    
                    if !isMuted {
                        Task {
                            try? await stateManager.speak(thought.thought, isMuted: isMuted)
                        }
                    }
                }
                
            } catch {
                print("Error saving room note: \(error)")
                // Handle error gracefully
                await generateHouseResponse(for: "I had trouble saving that note. Let me try again.")
            }
            
        default:
            // Shouldn't happen, but handle gracefully
            UserDefaults.standard.set(false, forKey: "isInPhase4Tutorial")
            await generateHouseResponse(for: input)
        }
    }
    
    private func handleRoomNoteNameProvided(_ roomName: String) async {
        // Save the room name temporarily
        UserDefaults.standard.set(roomName, forKey: "currentRoomName")
        UserDefaults.standard.set("awaitingRoomDetails", forKey: "noteCreationState")
        
        let response = """
        Got it! I'll create a note for the \(roomName).
        
        What would you like me to remember about this room? You can include details about devices, furniture, or anything else that might be helpful.
        """
        
        let thought = HouseThought(
            thought: response,
            emotion: .curious,
            category: .question,
            confidence: 1.0
        )
        
        await MainActor.run {
            let message = Message(
                content: thought.thought,
                isFromUser: false,
                isVoice: !isMuted
            )
            messageStore.addMessage(message)
            
            if !isMuted {
                Task {
                    try? await stateManager.speak(thought.thought, isMuted: isMuted)
                }
            }
        }
    }
    
    private func handleRoomNoteDetailsProvided(_ details: String) async {
        let roomName = UserDefaults.standard.string(forKey: "pendingRoomName") ?? 
                      UserDefaults.standard.string(forKey: "currentRoomName") ?? "Room"
        
        do {
            // Create a new question for this room
            let roomQuestion = Question(
                id: UUID(),
                text: roomName,
                category: .other,
                displayOrder: 1000,
                isRequired: false
            )
            
            // Add the question first
            try await serviceContainer.notesService.addQuestion(roomQuestion)
            
            // Save the note with room type metadata
            try await serviceContainer.notesService.saveOrUpdateNote(
                for: roomQuestion.id,
                answer: details,
                metadata: [
                    "type": "room",
                    "updated_via_conversation": "true",
                    "createdDate": Date().ISO8601Format()
                ]
            )
            
            // Clear the note creation state
            UserDefaults.standard.removeObject(forKey: "noteCreationState")
            UserDefaults.standard.removeObject(forKey: "currentRoomName")
            UserDefaults.standard.removeObject(forKey: "pendingRoomName")
            
            // Mark Phase 4 as complete if this was the first room note
            if !UserDefaults.standard.bool(forKey: "hasCompletedPhase4Tutorial") {
                UserDefaults.standard.set(true, forKey: "hasCompletedPhase4Tutorial")
                UserDefaults.standard.set(false, forKey: "isInPhase4Tutorial")
                
                let successMessage = """
                Perfect! I've saved that information about the \(roomName). 
                
                🎉 Congratulations! You've completed the setup and created your first room note. 
                
                You can now:
                • Create more room notes by saying "add room note"
                • Create device notes by saying "add device note"
                • View and edit all your notes from the Notes screen
                • Ask me questions about your house
                
                I'm here to help whenever you need me!
                """
                
                let thought = HouseThought(
                    thought: successMessage,
                    emotion: .happy,
                    category: .celebration,
                    confidence: 1.0
                )
                
                await MainActor.run {
                    let message = Message(
                        content: successMessage,
                        isFromUser: false,
                        isVoice: !isMuted
                    )
                    messageStore.addMessage(message)
                    
                    if !isMuted {
                        Task {
                            try? await stateManager.speak(thought.thought, isMuted: isMuted)
                        }
                    }
                }
            } else {
                let successMessage = "Perfect! I've saved that information about the \(roomName). You can view and edit this note anytime from the Notes screen."
                
                let thought = HouseThought(
                    thought: successMessage,
                    emotion: .happy,
                    category: .celebration,
                    confidence: 1.0
                )
                
                await MainActor.run {
                    let message = Message(
                        content: thought.thought,
                        isFromUser: false,
                        isVoice: !isMuted
                    )
                    messageStore.addMessage(message)
                    
                    if !isMuted {
                        Task {
                            try? await stateManager.speak(thought.thought, isMuted: isMuted)
                        }
                    }
                }
            }
            
        } catch {
            print("Error saving room note: \(error)")
            await generateHouseResponse(for: "I had trouble saving that note. Let me try again.")
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubble: View {
    let message: Message
    let onAddressSubmit: ((String) -> Void)?
    
    init(message: Message, onAddressSubmit: ((String) -> Void)? = nil) {
        self.message = message
        self.onAddressSubmit = onAddressSubmit
    }
    
    // Check if this is a question with a suggested answer
    private var isQuestionWithSuggestion: Bool {
        // Check for common question patterns with newlines indicating suggested answers
        let questionPatterns = [
            "Is this the right address?",
            "What's your home address?",
            "What should I call this house?",
            "What's your name?",
            "What's your phone number?",
            "What's your email?"
        ]
        
        return questionPatterns.contains(where: { pattern in
            message.content.contains(pattern) && message.content.contains("\n")
        })
    }
    
    // Extract question and suggested answer
    private var questionAndAnswer: (question: String, answer: String)? {
        if isQuestionWithSuggestion {
            let components = message.content.components(separatedBy: "\n\n")
            if components.count >= 2 {
                let question = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let answer = components[1...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                return (question, answer)
            }
        }
        return nil
    }
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromUser && isQuestionWithSuggestion, 
                   let (question, answer) = questionAndAnswer {
                    // Use generic suggested answer view
                    SuggestedAnswerQuestionView(
                        question: question,
                        suggestedAnswer: answer,
                        icon: SuggestedAnswerQuestionView.icon(for: question)
                    ) { editedAnswer in
                        onAddressSubmit?(editedAnswer)
                    }
                } else {
                    // Regular message bubble
                    Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.isFromUser ? Color.blue : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                        .cornerRadius(20)
                        .overlay(
                            message.isVoice ?
                            Image(systemName: "mic.fill")
                                .font(.caption2)
                                .foregroundColor(message.isFromUser ? .white.opacity(0.7) : .secondary)
                                .offset(x: message.isFromUser ? -8 : 8, y: -8)
                            : nil,
                            alignment: message.isFromUser ? .topTrailing : .topLeading
                        )
                }
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isFromUser ? .trailing : .leading)
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - HouseThought Extension

extension HouseThought {
    static func generateResponse(for input: String) -> HouseThought {
        let lowercased = input.lowercased()
        
        // Simple response generation - this could be made much more sophisticated
        if lowercased.contains("hello") || lowercased.contains("hi") {
            return HouseThought(
                thought: "Hello! How are you doing today?",
                emotion: .happy,
                category: .greeting,
                confidence: 1.0
            )
        } else if lowercased.contains("weather") {
            return HouseThought(
                thought: "Let me check the weather for you. One moment...",
                emotion: .thoughtful,
                category: .observation,
                confidence: 0.9
            )
        } else if lowercased.contains("temperature") || lowercased.contains("cold") || lowercased.contains("hot") {
            return HouseThought(
                thought: "I'll check the current temperature and adjust if needed.",
                emotion: .thoughtful,
                category: .observation,
                confidence: 0.9
            )
        } else if lowercased.contains("thank") {
            return HouseThought(
                thought: "You're welcome! I'm always here to help.",
                emotion: .happy,
                category: .greeting,
                confidence: 1.0
            )
        } else if lowercased.contains("help") {
            return HouseThought(
                thought: "I can help you with managing your home, checking weather, taking notes, and having conversations. What would you like to know?",
                emotion: .thoughtful,
                category: .suggestion,
                confidence: 1.0
            )
        } else if lowercased.contains("note") || lowercased.contains("notes") {
            return HouseThought(
                thought: "I can help you create notes about your home. Try saying 'new room note' to add a note about a room, or 'new device note' to add a note about a device or appliance.",
                emotion: .thoughtful,
                category: .suggestion,
                confidence: 1.0
            )
        } else {
            return HouseThought(
                thought: "I understand. Let me think about that...",
                emotion: .thoughtful,
                category: .observation,
                confidence: 0.7
            )
        }
    }
}
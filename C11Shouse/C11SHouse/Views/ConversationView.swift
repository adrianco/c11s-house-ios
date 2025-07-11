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
                
                Text("House Chat")
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
                        
                        // Invisible anchor for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
                .onChange(of: messageStore.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
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
            setupView()
        }
        .onChange(of: recognizer.transcript) { oldValue, newValue in
            // When recording completes with transcript
            if !recognizer.isRecording && !newValue.isEmpty && oldValue != newValue {
                // Show confirmation with editable text
                pendingVoiceText = newValue
                showVoiceConfirmation = true
                isTextFieldFocused = true
            }
        }
        .onChange(of: questionFlow.currentQuestion) { oldValue, newValue in
            // When a new question appears, add it to the chat
            if let question = newValue, oldValue != newValue {
                Task { @MainActor in
                    var messageContent = question.text
                    
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
                    
                    // Add question message immediately on main actor
                    let questionMessage = Message(
                        content: messageContent,
                        isFromUser: false,
                        isVoice: !isMuted
                    )
                    messageStore.addMessage(questionMessage)
                    
                    // Speak the question if not muted
                    if !isMuted {
                        let thought = HouseThought(
                            thought: question.text,
                            emotion: .curious,
                            category: .question,
                            confidence: 1.0
                        )
                        // Don't wait for speech to complete - let it run in background
                        Task {
                            try? await stateManager.speak(thought.thought, isMuted: isMuted)
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
    }
    
    private func setupView() {
        // Set up recognizer reference
        questionFlow.conversationRecognizer = recognizer
        
        // Load initial state
        Task {
            await stateManager.loadUserName()
            
            // Add welcome message if no messages exist
            if messageStore.messages.isEmpty {
                let welcomeMessage = Message(
                    content: "Hello! I'm your house consciousness. How can I help you today?",
                    isFromUser: false,
                    isVoice: false
                )
                messageStore.addMessage(welcomeMessage)
            }
            
            // Load any pending questions
            await questionFlow.loadNextQuestion()
        }
    }
    
    private func toggleRecording() {
        if recognizer.isRecording {
            recognizer.stopRecording()
        } else {
            stateManager.stopSpeaking()
            recognizer.transcript = ""
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
        
        // Clear voice confirmation
        pendingVoiceText = ""
        showVoiceConfirmation = false
        recognizer.transcript = ""
        
        // Process message
        processUserInput(text)
    }
    
    
    private func processUserInput(_ input: String) {
        isProcessing = true
        
        Task { @MainActor in
            // Update state manager transcript
            stateManager.persistentTranscript = input
            
            // Check if this answers a current question
            if questionFlow.currentQuestion != nil {
                await questionFlow.saveAnswer()
                
                // Add acknowledgment message immediately
                let acknowledgment = Message(
                    content: "Thank you! I've saved that information.",
                    isFromUser: false,
                    isVoice: !isMuted
                )
                messageStore.addMessage(acknowledgment)
                
                // Speak acknowledgment and then load next question
                if !isMuted {
                    let thought = HouseThought(
                        thought: "Thank you! I've saved that information.",
                        emotion: .happy,
                        category: .greeting,
                        confidence: 1.0
                    )
                    // Wait for speech to complete before loading next question
                    try? await stateManager.speak(thought.thought, isMuted: isMuted)
                }
                
                // Load next question after acknowledgment is spoken
                await questionFlow.loadNextQuestion()
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
            
            await MainActor.run {
                isProcessing = false
                scrollToBottom = true
            }
        }
    }
    
    private func generateHouseResponse(for input: String) async {
        // Generate a house thought based on input
        let thought = HouseThought.generateResponse(for: input)
        
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
}

// MARK: - Message Bubble View

struct MessageBubble: View {
    let message: Message
    let onAddressSubmit: ((String) -> Void)?
    
    init(message: Message, onAddressSubmit: ((String) -> Void)? = nil) {
        self.message = message
        self.onAddressSubmit = onAddressSubmit
    }
    
    // Check if this is an address question with pre-populated content
    private var isAddressQuestion: Bool {
        message.content.contains("Is this the right address?") && message.content.contains("\n")
    }
    
    // Extract address from message if it exists
    private var extractedAddress: String? {
        if isAddressQuestion {
            let components = message.content.components(separatedBy: "\n")
            if components.count > 1 {
                return components[1...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
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
                if !message.isFromUser && isAddressQuestion, let address = extractedAddress {
                    // Use special address question view
                    AddressQuestionView(detectedAddress: address) { editedAddress in
                        onAddressSubmit?(editedAddress)
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
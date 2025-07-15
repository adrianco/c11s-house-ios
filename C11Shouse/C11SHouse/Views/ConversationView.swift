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
 * - 2025-07-15: Refactored into smaller components
 *   - Extracted MessageListView for message display
 *   - Extracted ChatInputView for input handling
 *   - Extracted MessageBubbleView for individual messages
 *   - Created ConversationViewModel for business logic
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
    @StateObject private var viewModel: ConversationViewModel
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @Environment(\.presentationMode) var presentationMode
    
    @State private var inputText = ""
    @State private var isMuted = false
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
        
        // Create view model
        let messageStore = MessageStore()
        let recognizer = ConversationRecognizer()
        _messageStore = StateObject(wrappedValue: messageStore)
        _recognizer = StateObject(wrappedValue: recognizer)
        
        let viewModel = ConversationViewModel(
            messageStore: messageStore,
            stateManager: conversationStateManager,
            questionFlow: ServiceContainer.shared.questionFlowCoordinator,
            recognizer: recognizer,
            serviceContainer: ServiceContainer.shared
        )
        _viewModel = StateObject(wrappedValue: viewModel)
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
                
                Text(viewModel.houseName)
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
            MessageListView(
                messageStore: messageStore,
                scrollToBottom: $scrollToBottom,
                onAddressSubmit: handleAddressSubmission
            )
            
            // Input area
            ChatInputView(
                recognizer: recognizer,
                inputText: $inputText,
                isMuted: $isMuted,
                isProcessing: .constant(viewModel.isProcessing),
                pendingVoiceText: $pendingVoiceText,
                showVoiceConfirmation: $showVoiceConfirmation,
                isTextFieldFocused: _isTextFieldFocused,
                onSendText: sendTextMessage,
                onToggleRecording: toggleRecording,
                onConfirmVoice: confirmVoiceMessage
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            print("[ConversationView] onAppear called")
            print("[ConversationView] hasCompletedPhase4Tutorial: \(UserDefaults.standard.bool(forKey: "hasCompletedPhase4Tutorial"))")
            print("[ConversationView] isInPhase4Tutorial: \(UserDefaults.standard.bool(forKey: "isInPhase4Tutorial"))")
            Task {
                await viewModel.setupView()
                // Scroll to bottom after initial setup
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    scrollToBottom = true
                }
            }
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
        .onChange(of: recognizer.currentHouseThought) { oldValue, newValue in
            // When house has a thought (like acknowledgment), display it
            if let thought = newValue, oldValue != newValue {
                // Don't add if it's already part of a question
                if questionFlow.currentQuestion == nil {
                    let message = Message(
                        content: thought.thought,
                        isFromUser: false,
                        isVoice: !isMuted
                    )
                    messageStore.addMessage(message)
                    
                    // Speak if not muted
                    if !isMuted {
                        Task {
                            await stateManager.speak(thought.thought, isMuted: isMuted)
                        }
                    }
                }
            }
        }
        .onChange(of: questionFlow.currentQuestion) { oldValue, newValue in
            // When a new question appears, add it to the chat
            if let question = newValue, oldValue != newValue {
                Task { @MainActor in
                    // First, let handleQuestionChange process the question
                    _ = await questionFlow.handleQuestionChange(oldQuestion: oldValue, newQuestion: newValue, isInitializing: false)
                    
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
                            await stateManager.speak(spokenContent, isMuted: isMuted)
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
            
            // Reload questions after clearing data
            Task {
                print("[ConversationView] Reloading questions after clear")
                await questionFlow.loadNextQuestion()
            }
            print("[ConversationView] Chat cleared and welcome message added")
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
        Task {
            await viewModel.processUserInput(text, isMuted: isMuted)
            scrollToBottom = true
        }
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
        Task {
            await viewModel.processUserInput(text, isMuted: isMuted)
            scrollToBottom = true
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
        Task {
            await viewModel.processUserInput(address, isMuted: isMuted)
            scrollToBottom = true
        }
    }
}
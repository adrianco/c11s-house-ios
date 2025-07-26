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
 * - 2025-07-25: Fixed permission-based mute state initialization
 *   - Added explicit permission check before determining mute state
 *   - Ensures unmuted start when permissions are already granted
 *   - Added logging to track mute state decisions
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI
@preconcurrency import Speech
import Combine

struct ConversationView: View {
    @StateObject private var messageStore = MessageStore()
    @StateObject private var recognizer = ConversationRecognizer()
    @StateObject private var stateManager: ConversationStateManager
    @StateObject private var questionFlow: QuestionFlowCoordinator
    @StateObject private var viewModel: ConversationViewModel
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @Environment(\.presentationMode) var presentationMode
    
    @State private var inputText = ""
    @State private var isMuted = false // Start unmuted by default
    @State private var scrollToBottom = false
    @State private var pendingVoiceText = ""
    @State private var showVoiceConfirmation = false
    @State private var waitingForPermissions = false
    @State private var permissionObserver: AnyCancellable?
    @FocusState private var isTextFieldFocused: Bool
    @State private var hasAppeared = false
    
    private var hasVoicePermissions: Bool {
        serviceContainer.permissionManager.isMicrophoneGranted &&
        serviceContainer.permissionManager.isSpeechRecognitionGranted
    }
    
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
                    if isMuted {
                        // Try to unmute - this will trigger permission requests if needed
                        Task {
                            await tryToUnmute()
                        }
                    } else {
                        // Mute
                        isMuted = true
                        if recognizer.isRecording {
                            recognizer.stopRecording()
                        }
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
                .accessibilityIdentifier(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .accessibilityLabel(isMuted ? "Unmute" : "Mute")
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
        .accessibilityIdentifier("ConversationView")
        .onAppear {
            print("[ConversationView] onAppear called")
            Task {
                await viewModel.setupView()
                
                // Initialize speech recognizer early to set authorization status
                recognizer.initializeSpeechRecognizer()
                
                // Set up permission observers
                setupPermissionObservers()
                
                // Mark view as appeared after setup
                hasAppeared = true
                
                // Force permission check before determining mute state
                serviceContainer.permissionManager.checkCurrentPermissions()
                
                // Check voice permissions status after ensuring they're updated
                if hasVoicePermissions {
                    print("[ConversationView] Permissions granted, starting unmuted")
                    isMuted = false
                } else {
                    // Start muted if no permissions
                    print("[ConversationView] No permissions, starting muted")
                    isMuted = true
                }
                
                // Trigger scroll to bottom after setup
                scrollToBottom = true
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
            // Only process if view has appeared and this is an actual change
            if let question = newValue, oldValue != newValue, hasAppeared {
                Task { @MainActor in
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
                    }
                    
                    // Add question message immediately on main actor
                    let questionMessage = Message(
                        content: messageContent,
                        isFromUser: false,
                        isVoice: !isMuted
                    )
                    messageStore.addMessage(questionMessage)
                    
                    // Check for pre-populated transcript
                    if !stateManager.persistentTranscript.isEmpty {
                        inputText = stateManager.persistentTranscript
                        // Use onChange to focus after text updates
                        isTextFieldFocused = true
                    } else {
                        // Clear the text field for questions without pre-populated answers
                        inputText = ""
                    }
                    
                    // Trigger scroll to bottom
                    scrollToBottom = true
                    
                    // Speak the question if not muted
                    if !isMuted {
                        // Queue speech properly without delays
                        Task {
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
    
    private func setupPermissionObservers() {
        // Monitor microphone permission changes
        permissionObserver = serviceContainer.permissionManager.$microphonePermissionStatus
            .combineLatest(serviceContainer.permissionManager.$speechRecognitionPermissionStatus)
            .receive(on: DispatchQueue.main)
            .sink { [self] micStatus, speechStatus in
                // If we were waiting for permissions and they're now granted, unmute
                if waitingForPermissions &&
                   micStatus == .granted &&
                   speechStatus == .authorized {
                    isMuted = false
                    waitingForPermissions = false
                }
            }
        
        // Also monitor app becoming active in case user changed permissions in Settings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            serviceContainer.permissionManager.checkCurrentPermissions()
            
            // Check if we were waiting for permissions and they're now granted
            if waitingForPermissions && hasVoicePermissions {
                isMuted = false
                waitingForPermissions = false
            }
        }
    }
    
    private func toggleRecording() {
        print("[ConversationView] toggleRecording called")
        print("[ConversationView] recognizer.isRecording: \(recognizer.isRecording)")
        print("[ConversationView] recognizer.authorizationStatus: \(recognizer.authorizationStatus.rawValue)")
        print("[ConversationView] stateManager.isSpeaking: \(stateManager.isSpeaking)")
        
        if recognizer.isRecording {
            recognizer.stopRecording()
        } else {
            // If TTS is still speaking, stop it first
            if stateManager.isSpeaking {
                print("[ConversationView] Stopping TTS before recording")
                stateManager.stopSpeaking()
            }
            
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
    
    private func tryToUnmute() async {
        print("[ConversationView] tryToUnmute called")
        print("[ConversationView] Mic permission: \(serviceContainer.permissionManager.isMicrophoneGranted)")
        print("[ConversationView] Speech permission: \(serviceContainer.permissionManager.isSpeechRecognitionGranted)")
        print("[ConversationView] hasVoicePermissions: \(hasVoicePermissions)")
        
        // First check if we already have permissions
        if hasVoicePermissions {
            print("[ConversationView] Voice permissions already granted, unmuting")
            isMuted = false
            return
        }
        
        // Set up permission observers before requesting permissions
        setupPermissionObservers()
        
        // Mark that we're waiting for permissions so the observer can unmute when granted
        waitingForPermissions = true
        
        // Initialize speech recognizer - this will trigger speech recognition permission if needed
        recognizer.initializeSpeechRecognizer()
        
        // Try to start recording briefly - this will trigger microphone permission if needed
        do {
            try recognizer.startRecording()
            // Immediately stop since we're just triggering permissions
            recognizer.stopRecording()
        } catch {
            // Expected if permissions are denied - this triggers the permission dialog
            // Don't log as error since this is normal flow
        }
        
        // Check again after permission requests
        // Force a refresh of permission status
        serviceContainer.permissionManager.checkCurrentPermissionsExceptHomeKit()
        
        // Use a small delay to ensure the permission status has updated
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("[ConversationView] After permission request - hasVoicePermissions: \(hasVoicePermissions)")
        if hasVoicePermissions {
            print("[ConversationView] Permissions granted, unmuting")
            isMuted = false
            waitingForPermissions = false
        } else {
            print("[ConversationView] Permissions still not granted")
        }
    }
}
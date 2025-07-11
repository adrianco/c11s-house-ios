/*
 * CONTEXT & PURPOSE:
 * OnboardingPersonalizationView implements Phase 3 of the onboarding UX plan.
 * It guides users through setting up their home address, naming their house,
 * and introducing themselves through the conversational interface.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation based on OnboardingUXPlan.md
 *   - Conversational UI for natural interaction
 *   - Auto-detection with manual fallback
 *   - Progressive questions with pre-populated answers
 *   - Smooth transitions to conversation view
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI
import CoreLocation

struct OnboardingPersonalizationView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @StateObject private var conversationState = ViewModelFactory.shared.makeConversationStateManager()
    @StateObject private var questionFlow: QuestionFlowCoordinator
    @State private var isTransitioning = false
    @State private var showConversation = false
    
    let onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _questionFlow = StateObject(wrappedValue: ServiceContainer.shared.questionFlowCoordinator)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !showConversation {
                // Intro Screen
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: 16) {
                        Text("Let's Get Acquainted")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("I'll ask a few quick questions to personalize your experience")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    // Start Conversation Button
                    Button(action: {
                        OnboardingLogger.shared.logButtonTap("start_conversation", phase: "personalization")
                        startConversation()
                    }) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Start Conversation")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "007AFF"), Color(hex: "5856D6")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 50)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            } else {
                // Embedded Conversation View
                EmbeddedConversationView(
                    conversationState: conversationState,
                    questionFlow: questionFlow,
                    onComplete: {
                        // Check if all required questions are answered
                        Task {
                            let allAnswered = await serviceContainer.notesService.areAllRequiredQuestionsAnswered()
                            if allAnswered {
                                await MainActor.run {
                                    onComplete()
                                }
                            }
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showConversation)
        .onAppear {
            OnboardingLogger.shared.logUserAction("view_appeared", phase: "personalization")
            setupQuestionFlow()
        }
    }
    
    private func startConversation() {
        withAnimation {
            showConversation = true
        }
        
        // Start with the first question
        Task {
            await questionFlow.loadNextQuestion()
        }
    }
    
    private func setupQuestionFlow() {
        // Set up dependencies
        questionFlow.conversationStateManager = conversationState
        questionFlow.addressManager = serviceContainer.addressManager
        questionFlow.serviceContainer = serviceContainer
        
        // Set up address suggestion service
        let addressSuggestionService = AddressSuggestionService(
            addressManager: serviceContainer.addressManager,
            locationService: serviceContainer.locationService,
            weatherCoordinator: serviceContainer.weatherCoordinator
        )
        questionFlow.addressSuggestionService = addressSuggestionService
    }
}

// MARK: - Embedded Conversation View

struct EmbeddedConversationView: View {
    @ObservedObject var conversationState: ConversationStateManager
    @ObservedObject var questionFlow: QuestionFlowCoordinator
    @StateObject private var recognizer = ConversationRecognizer()
    @State private var currentQuestionIndex = 0
    @AppStorage("onboardingMuted") private var isMuted = false
    
    let onComplete: () -> Void
    
    private let requiredQuestions = ["Is this the right address?", "What's your home address?", "What should I call this house?", "What's your name?"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Setup Conversation")
                    .font(.headline)
                
                Spacer()
                
                // Question Progress
                if let question = questionFlow.currentQuestion {
                    Text("\(currentQuestionIndex + 1) of \(requiredQuestions.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            
            // Conversation Content
            ScrollView {
                VStack(spacing: 20) {
                    // House Thought
                    if let thought = recognizer.currentHouseThought {
                        HouseThoughtBubble(thought: thought)
                            .padding(.horizontal)
                            .padding(.top, 20)
                    }
                    
                    // Transcript Area
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Response:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(conversationState.persistentTranscript.isEmpty ? "Tap the microphone to speak..." : conversationState.persistentTranscript)
                            .font(.body)
                            .foregroundColor(conversationState.persistentTranscript.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        // Skip Button (only for non-required questions)
                        if let question = questionFlow.currentQuestion, !question.isRequired {
                            Button(action: {
                                OnboardingLogger.shared.logButtonTap("skip_question", phase: "personalization")
                                OnboardingLogger.shared.logUserAction("question_skipped", phase: "personalization", details: [
                                    "question": question.text
                                ])
                                skipQuestion()
                            }) {
                                Text("Skip")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Confirm Button
                        Button(action: {
                            OnboardingLogger.shared.logButtonTap("confirm_answer", phase: "personalization")
                            if let question = questionFlow.currentQuestion {
                                OnboardingLogger.shared.logUserAction("answer_confirmed", phase: "personalization", details: [
                                    "question": question.text,
                                    "answer_length": conversationState.persistentTranscript.count
                                ])
                            }
                            confirmAnswer()
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Confirm")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                conversationState.persistentTranscript.isEmpty ?
                                Color.gray : Color.blue
                            )
                            .cornerRadius(8)
                        }
                        .disabled(conversationState.persistentTranscript.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
            }
            
            // Recording Controls
            VStack(spacing: 0) {
                Divider()
                
                HStack {
                    // Mute Toggle
                    Button(action: { 
                        isMuted.toggle()
                        OnboardingLogger.shared.logFeatureUsage("mute_toggle", phase: "personalization", details: [
                            "muted": isMuted
                        ])
                    }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(isMuted ? .orange : .blue)
                    }
                    
                    Spacer()
                    
                    // Recording Button
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(recognizer.isRecording ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(recognizer.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: recognizer.isRecording)
                    
                    Spacer()
                    
                    // Clear Button
                    Button(action: { 
                        OnboardingLogger.shared.logButtonTap("clear_transcript", phase: "personalization")
                        conversationState.clearTranscript() 
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .disabled(conversationState.persistentTranscript.isEmpty)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
        .onAppear {
            setupConversation()
        }
        .onChange(of: questionFlow.currentQuestion) { oldValue, newValue in
            Task {
                _ = await questionFlow.handleQuestionChange(
                    oldQuestion: oldValue,
                    newQuestion: newValue,
                    isInitializing: false
                )
                updateQuestionIndex()
            }
        }
        .onChange(of: recognizer.transcript) { _, newValue in
            if !newValue.isEmpty {
                conversationState.updateTranscript(with: newValue)
                if let question = questionFlow.currentQuestion {
                    OnboardingLogger.shared.logVoiceInput(
                        phase: "personalization",
                        duration: 0, // Could track actual duration if needed
                        transcript: newValue
                    )
                }
            }
        }
    }
    
    private func setupConversation() {
        // Set up recognizer reference
        questionFlow.conversationRecognizer = recognizer
        
        // Load first question
        Task {
            await questionFlow.loadNextQuestion()
        }
    }
    
    private func toggleRecording() {
        if recognizer.isRecording {
            recognizer.stopRecording()
            OnboardingLogger.shared.logUserAction("recording_stopped", phase: "personalization")
        } else {
            conversationState.startNewRecordingSession()
            recognizer.startRecording()
            OnboardingLogger.shared.logUserAction("recording_started", phase: "personalization")
        }
    }
    
    private func confirmAnswer() {
        Task {
            await questionFlow.saveAnswer()
            
            // Check if we're done
            if questionFlow.hasCompletedAllQuestions {
                onComplete()
            }
        }
    }
    
    private func skipQuestion() {
        Task {
            await questionFlow.loadNextQuestion()
        }
    }
    
    private func updateQuestionIndex() {
        if let question = questionFlow.currentQuestion {
            currentQuestionIndex = requiredQuestions.firstIndex(of: question.text) ?? 0
        }
    }
}

// MARK: - House Thought Bubble

struct HouseThoughtBubble: View {
    let thought: HouseThought
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Emotion Icon
            Text(thought.emotion.emoji)
                .font(.title)
            
            // Thought Bubble
            VStack(alignment: .leading, spacing: 8) {
                Text(thought.thought)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if let suggestion = thought.suggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
            .overlay(
                // Speech bubble tail
                SpeechBubbleTail()
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(width: 20, height: 15)
                    .offset(x: -25, y: 15),
                alignment: .topLeading
            )
        }
    }
}

struct SpeechBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

struct OnboardingPersonalizationView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingPersonalizationView(onComplete: {})
            .environmentObject(ServiceContainer.shared)
    }
}
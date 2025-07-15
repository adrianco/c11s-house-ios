/*
 * CONTEXT & PURPOSE:
 * ConversationViewModel handles the business logic for the conversation interface.
 * It manages user input processing, house responses, note creation, and Phase 4 tutorial.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Extracted from ConversationView for better separation of concerns
 *   - Centralizes conversation logic
 *   - Handles question flow coordination
 *   - Manages note creation workflows
 *   - Controls Phase 4 tutorial state
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI
import Combine

@MainActor
class ConversationViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var houseName = "House Chat"
    
    private let messageStore: MessageStore
    private let stateManager: ConversationStateManager
    private let questionFlow: QuestionFlowCoordinator
    private let serviceContainer: ServiceContainer
    private let recognizer: ConversationRecognizer
    
    init(messageStore: MessageStore,
         stateManager: ConversationStateManager,
         questionFlow: QuestionFlowCoordinator,
         recognizer: ConversationRecognizer,
         serviceContainer: ServiceContainer) {
        self.messageStore = messageStore
        self.stateManager = stateManager
        self.questionFlow = questionFlow
        self.recognizer = recognizer
        self.serviceContainer = serviceContainer
    }
    
    func setupView() async {
        print("[ConversationViewModel] setupView() called")
        
        // Set up recognizer reference
        questionFlow.conversationRecognizer = recognizer
        
        // Set up address suggestion service if not already set
        if questionFlow.addressSuggestionService == nil {
            questionFlow.addressSuggestionService = ServiceContainer.shared.addressSuggestionService
        }
        
        // Load initial state
        await stateManager.loadUserName()
        
        // Load house name
        if let savedHouseName = await serviceContainer.notesService.getHouseName(),
           !savedHouseName.isEmpty {
            houseName = savedHouseName
            print("[ConversationViewModel] Loaded house name: \(houseName)")
        } else {
            print("[ConversationViewModel] No saved house name found")
        }
        
        // Add welcome message if no messages exist
        if messageStore.messages.isEmpty {
            print("[ConversationViewModel] Adding welcome message")
            let welcomeMessage = Message(
                content: "Hello! I'm your house consciousness. How can I help you today?",
                isFromUser: false,
                isVoice: false
            )
            messageStore.addMessage(welcomeMessage)
        } else {
            print("[ConversationViewModel] Found \(messageStore.messages.count) existing messages")
        }
        
        // Pre-fetch location in background if permissions are granted
        Task.detached(priority: .background) {
            let locationService = ServiceContainer.shared.locationService
            await locationService.requestLocationPermission()
        }
        
        // Load any pending questions
        print("[ConversationViewModel] Loading next question...")
        await questionFlow.loadNextQuestion()
        
        // Check if all questions are complete and start Phase 4 tutorial
        print("[ConversationViewModel] hasCompletedAllQuestions: \(questionFlow.hasCompletedAllQuestions)")
        if questionFlow.hasCompletedAllQuestions {
            print("[ConversationViewModel] All questions complete, starting Phase 4 tutorial")
            await startPhase4Tutorial()
        } else {
            print("[ConversationViewModel] Questions still pending, current: \(questionFlow.currentQuestion?.text ?? "none")")
        }
    }
    
    func processUserInput(_ input: String, isMuted: Bool) async {
        print("[ConversationViewModel] processUserInput: '\(input)'")
        isProcessing = true
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Update state manager transcript
        stateManager.persistentTranscript = input
        
        // Check if this answers a current question
        if let currentQuestion = questionFlow.currentQuestion {
            print("[ConversationViewModel] Answering question: \(currentQuestion.text)")
            
            // Check if this is the Phase 4 introduction question
            if currentQuestion.text.contains("Let's start by creating your first room note") {
                print("[ConversationViewModel] This is the Phase 4 intro question, handling specially")
                
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
                    await stateManager.speak(detailsMessage.content, isMuted: isMuted)
                }
            } else {
                // Normal question handling
                await questionFlow.saveAnswer()
                
                // Let the coordinator handle the entire flow
                await questionFlow.loadNextQuestion()
                
                // Check if all questions are complete
                print("[ConversationViewModel] After loading, hasCompletedAllQuestions: \(questionFlow.hasCompletedAllQuestions)")
                if questionFlow.hasCompletedAllQuestions {
                    print("[ConversationViewModel] All questions complete after answer, starting Phase 4")
                    await startPhase4Tutorial()
                }
            }
        } else {
            // Check if we're in Phase 4 tutorial
            if UserDefaults.standard.bool(forKey: "isInPhase4Tutorial") {
                await handlePhase4TutorialInput(input, isMuted: isMuted)
            } else {
                // Check if we're in the middle of creating a note
                let noteCreationState = UserDefaults.standard.string(forKey: "noteCreationState")
                if noteCreationState == "creatingRoomNote" {
                    // User provided room name, now ask for details
                    await handleRoomNoteNameProvided(input, isMuted: isMuted)
                } else if noteCreationState == "awaitingRoomDetails" {
                    // User provided room details, save the note
                    await handleRoomNoteDetailsProvided(input, isMuted: isMuted)
                } else {
                    // Check for note creation commands
                    let lowercased = input.lowercased()
                    if lowercased.contains("new room note") || lowercased.contains("add room note") {
                        await handleRoomNoteCreation(isMuted: isMuted)
                    } else if lowercased.contains("new device note") || lowercased.contains("add device note") {
                        await handleDeviceNoteCreation(isMuted: isMuted)
                    } else {
                        // Generate house response
                        await generateHouseResponse(for: input, isMuted: isMuted)
                    }
                }
            }
        }
    }
    
    private func generateHouseResponse(for input: String, isMuted: Bool) async {
        // Generate a house thought based on input
        let thought = HouseThought.generateResponse(for: input)
        
        // Add house message
        let houseMessage = Message(
            content: thought.thought,
            isFromUser: false,
            isVoice: !isMuted
        )
        messageStore.addMessage(houseMessage)
        
        // Speak if not muted
        if !isMuted {
            await stateManager.speak(thought.thought, isMuted: isMuted)
        }
    }
    
    private func handleRoomNoteCreation(isMuted: Bool) async {
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
            
            let message = Message(
                content: thought.thought,
                isFromUser: false,
                isVoice: !isMuted
            )
            messageStore.addMessage(message)
            
            if !isMuted {
                await stateManager.speak(thought.thought, isMuted: isMuted)
            }
            
            // Mark that we're creating a room note
            UserDefaults.standard.set("creatingRoomNote", forKey: "noteCreationState")
        }
    }
    
    private func handleDeviceNoteCreation(isMuted: Bool) async {
        let thought = HouseThought(
            thought: "I'll help you create a device note. What device or appliance would you like to add a note about?",
            emotion: .curious,
            category: .question,
            confidence: 1.0
        )
        
        let message = Message(
            content: thought.thought,
            isFromUser: false,
            isVoice: !isMuted
        )
        messageStore.addMessage(message)
        
        if !isMuted {
            await stateManager.speak(thought.thought, isMuted: isMuted)
        }
    }
    
    // MARK: - Phase 4 Tutorial
    
    private func startPhase4Tutorial() async {
        print("[ConversationViewModel] startPhase4Tutorial() called - no longer needed, Phase 4 is handled as a required question")
        // This method is kept for backward compatibility but doesn't do anything
        // Phase 4 is now handled as the 4th required question
    }
    
    private func handlePhase4TutorialInput(_ input: String, isMuted: Bool) async {
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
            
            let message = Message(
                content: thought.thought,
                isFromUser: false,
                isVoice: !isMuted
            )
            messageStore.addMessage(message)
            
            if !isMuted {
                await stateManager.speak(thought.thought, isMuted: isMuted)
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
                
                let completionMessage = "Excellent! I've saved that information about the \(roomName). You can add more notes anytime by saying 'new room note' or 'new device note'."
                
                let thought = HouseThought(
                    thought: completionMessage,
                    emotion: .happy,
                    category: .suggestion,
                    confidence: 1.0
                )
                
                let message = Message(
                    content: thought.thought,
                    isFromUser: false,
                    isVoice: !isMuted
                )
                messageStore.addMessage(message)
                
                if !isMuted {
                    await stateManager.speak(thought.thought, isMuted: isMuted)
                }
                
            } catch {
                print("Error saving room note: \(error)")
                // Handle error gracefully
                await generateHouseResponse(for: "I had trouble saving that note. Let me try again.", isMuted: isMuted)
            }
            
        default:
            // Shouldn't happen, but handle gracefully
            UserDefaults.standard.set(false, forKey: "isInPhase4Tutorial")
            await generateHouseResponse(for: input, isMuted: isMuted)
        }
    }
    
    private func handleRoomNoteNameProvided(_ roomName: String, isMuted: Bool) async {
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
        
        let message = Message(
            content: thought.thought,
            isFromUser: false,
            isVoice: !isMuted
        )
        messageStore.addMessage(message)
        
        if !isMuted {
            await stateManager.speak(thought.thought, isMuted: isMuted)
        }
    }
    
    private func handleRoomNoteDetailsProvided(_ details: String, isMuted: Bool) async {
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
                
                let successMessage = "Perfect! I've saved that information about the \(roomName). 🎉 Setup complete! You can now create more notes or ask me questions about your house."
                
                let thought = HouseThought(
                    thought: successMessage,
                    emotion: .happy,
                    category: .celebration,
                    confidence: 1.0
                )
                
                let message = Message(
                    content: successMessage,
                    isFromUser: false,
                    isVoice: !isMuted
                )
                messageStore.addMessage(message)
                
                if !isMuted {
                    await stateManager.speak(thought.thought, isMuted: isMuted)
                }
            } else {
                let successMessage = "Perfect! I've saved that about the \(roomName)."
                
                let thought = HouseThought(
                    thought: successMessage,
                    emotion: .happy,
                    category: .celebration,
                    confidence: 1.0
                )
                
                let message = Message(
                    content: thought.thought,
                    isFromUser: false,
                    isVoice: !isMuted
                )
                messageStore.addMessage(message)
                
                if !isMuted {
                    await stateManager.speak(thought.thought, isMuted: isMuted)
                }
            }
            
        } catch {
            print("Error saving room note: \(error)")
            await generateHouseResponse(for: "I had trouble saving that note. Let me try again.", isMuted: isMuted)
        }
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
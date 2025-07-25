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
 * - 2025-07-25: Fixed conversation flow issues
 *   - Address question now appears immediately, not delayed after HomeKit
 *   - Added handleNoteSelectionResponse for "Would you like me to read any of these?"
 *   - Stores pending note options when showing multiple search results
 *   - Recognizes "yes", numbers, and "first" as selection responses
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
    
    private var hasVoicePermissions: Bool {
        serviceContainer.permissionManager.isMicrophoneGranted &&
        serviceContainer.permissionManager.isSpeechRecognitionGranted
    }
    
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
        
        // Always load the first question (address) immediately
        print("[ConversationViewModel] Loading first question...")
        await questionFlow.loadNextQuestion()
        
        // Then check for HomeKit configuration and add summary message
        await checkAndAnnounceHomeKitConfiguration()
        
        // Check if all questions are complete and start Phase 4 tutorial
        print("[ConversationViewModel] hasCompletedAllQuestions: \(questionFlow.hasCompletedAllQuestions)")
        print("[ConversationViewModel] Questions status - hasCompletedAllQuestions: \(questionFlow.hasCompletedAllQuestions), current: \(questionFlow.currentQuestion?.text ?? "none")")
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
        
        // If no current question and not all complete, try loading next question
        if questionFlow.currentQuestion == nil && !questionFlow.hasCompletedAllQuestions {
            print("[ConversationViewModel] No current question, loading next...")
            await questionFlow.loadNextQuestion()
        }
        
        // Check if this answers a current question
        if let currentQuestion = questionFlow.currentQuestion {
            print("[ConversationViewModel] Answering question: \(currentQuestion.text)")
            
            // Normal question handling
            await questionFlow.saveAnswer()
            
            // Don't call loadNextQuestion here - saveAnswer already does it
            // This prevents duplicate question loading
            
            // Check if all questions are complete
            print("[ConversationViewModel] After saving, hasCompletedAllQuestions: \(questionFlow.hasCompletedAllQuestions)")
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
                } else if lowercased.contains("what") && (lowercased.contains("note") || lowercased.contains("remember")) {
                    // Handle note search queries
                    await searchAndRespondWithNotes(query: input, isMuted: isMuted)
                } else if lowercased.contains("search") && (lowercased.contains("note") || lowercased.contains("room") || lowercased.contains("homekit")) {
                    // Handle explicit search requests
                    await searchAndRespondWithNotes(query: input, isMuted: isMuted)
                } else if (lowercased == "yes" || lowercased.contains("show") || lowercased.contains("read")) && 
                         UserDefaults.standard.bool(forKey: "awaitingNoteSelection") {
                    // Handle response to "Would you like me to read any of these in detail?"
                    await handleNoteSelectionResponse(input, isMuted: isMuted)
                } else if lowercased.contains("tell") && lowercased.contains("about") {
                    // Handle "tell me about" queries
                    await searchAndRespondWithNotes(query: input, isMuted: isMuted)
                } else if lowercased.contains("show") && (lowercased.contains("note") || lowercased.contains("room")) {
                    // Handle "show me" queries
                    await searchAndRespondWithNotes(query: input, isMuted: isMuted)
                } else {
                    // For any other input, check if it might be asking about a note
                    // by searching if any note title contains words from the input
                    if await mightBeAskingAboutNote(input) {
                        await searchAndRespondWithNotes(query: input, isMuted: isMuted)
                    } else {
                        // Generate house response
                        await generateHouseResponse(for: input, isMuted: isMuted)
                    }
                }
            }
        }
    }
    
    private func generateHouseResponse(for input: String, isMuted: Bool) async {
        print("[ConversationViewModel] generateHouseResponse called - isMuted: \(isMuted)")
        // Generate a house thought based on input
        let thought = HouseThought.generateResponse(for: input)
        print("[ConversationViewModel] Generated thought: '\(thought.thought.prefix(50))...'")
        
        // Add house message
        let houseMessage = Message(
            content: thought.thought,
            isFromUser: false,
            isVoice: !isMuted
        )
        messageStore.addMessage(houseMessage)
        
        // Speak if not muted
        print("[ConversationViewModel] About to speak - isMuted: \(isMuted)")
        if !isMuted {
            await stateManager.speak(thought.thought, isMuted: isMuted)
        } else {
            print("[ConversationViewModel] Not speaking - muted")
        }
    }
    
    private func handleRoomNoteCreation(isMuted: Bool) async {
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
            
            let successMessage = "Perfect! I've saved that information about the \(roomName). You can create more notes or ask me questions about your house anytime."
            
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
            
        } catch {
            print("Error saving room note: \(error)")
            await generateHouseResponse(for: "I had trouble saving that note. Let me try again.", isMuted: isMuted)
        }
    }
    
    private func checkAndAnnounceHomeKitConfiguration() async {
        // Check if we've already announced HomeKit
        let homeKitAnnouncedKey = "homeKitConfigurationAnnounced"
        guard !UserDefaults.standard.bool(forKey: homeKitAnnouncedKey) else {
            print("[ConversationViewModel] HomeKit already announced, skipping")
            return
        }
        
        // Check if HomeKit is configured
        let homeKitCoordinator = serviceContainer.homeKitCoordinator
        let hasHomeKit = await homeKitCoordinator.hasHomeKitConfiguration()
        
        if hasHomeKit {
            // Get HomeKit summary from notes
            do {
                let notesStore = try await serviceContainer.notesService.loadNotesStore()
                
                // Find the HomeKit summary note
                if let summaryQuestion = notesStore.questions.first(where: { question in
                    question.text == "HomeKit Configuration Summary"
                }) {
                    if let summaryNote = notesStore.notes[summaryQuestion.id],
                       !summaryNote.answer.isEmpty {
                        
                        // Create a detailed summary message for the conversation
                        let summary = extractDetailedHomeKitSummary(from: summaryNote.answer)
                        
                        // Only add the message if we have meaningful content
                        if !summary.isEmpty && summary.count > 50 {
                            print("[ConversationViewModel] Announcing HomeKit configuration with summary length: \(summary.count)")
                            let homeKitMessage = Message(
                                content: summary,
                                isFromUser: false,
                                isVoice: !stateManager.isSavingAnswer && hasVoicePermissions
                            )
                            messageStore.addMessage(homeKitMessage)
                            
                            // Speak the summary if voice is enabled
                            if !stateManager.isSavingAnswer && hasVoicePermissions {
                                await stateManager.speak(summary, isMuted: false)
                            }
                            
                            // Mark as announced
                            UserDefaults.standard.set(true, forKey: homeKitAnnouncedKey)
                        }
                    }
                }
            } catch {
                print("[ConversationViewModel] Error loading HomeKit notes: \(error)")
            }
        }
    }
    
    private func extractHomeKitSummary(from content: String) -> String {
        // Extract key information from the HomeKit summary
        var summary = ""
        
        // Look for home count
        if let homeMatch = content.range(of: "Found (\\d+) home", options: .regularExpression) {
            let homeCount = String(content[homeMatch])
            summary += homeCount.replacingOccurrences(of: "Found ", with: "")
        }
        
        // Look for room and accessory counts
        if let roomMatch = content.range(of: "(\\d+) rooms", options: .regularExpression) {
            let roomCount = String(content[roomMatch])
            summary += " with \(roomCount)"
        }
        
        if let accessoryMatch = content.range(of: "(\\d+) accessories", options: .regularExpression) {
            let accessoryCount = String(content[accessoryMatch])
            summary += " and \(accessoryCount)"
        }
        
        return summary.isEmpty ? "your home setup" : summary
    }
    
    private func mightBeAskingAboutNote(_ input: String) async -> Bool {
        // Check if the input contains any words that match note titles
        do {
            let notesStore = try await serviceContainer.notesService.loadNotesStore()
            let inputWords = input.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty && $0.count > 2 } // Skip very short words
            
            // Check if any note title contains any of the input words
            for (questionId, _) in notesStore.notes {
                if let question = notesStore.questions.first(where: { $0.id == questionId }) {
                    let titleLower = question.text.lowercased()
                    for word in inputWords {
                        if titleLower.contains(word) {
                            return true
                        }
                    }
                }
            }
        } catch {
            print("[ConversationViewModel] Error checking notes: \(error)")
        }
        return false
    }
    
    private func extractDetailedHomeKitSummary(from content: String) -> String {
        var homeCount = 0
        var roomCount = 0
        var accessoryCount = 0
        var homeName = ""
        
        // Extract counts using regex
        let homesRegex = try? NSRegularExpression(pattern: "Found (\\d+) home", options: [])
        if let match = homesRegex?.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
            if let range = Range(match.range(at: 1), in: content) {
                homeCount = Int(content[range]) ?? 0
            }
        }
        
        let roomsRegex = try? NSRegularExpression(pattern: "Total Rooms: (\\d+)", options: [])
        if let match = roomsRegex?.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
            if let range = Range(match.range(at: 1), in: content) {
                roomCount = Int(content[range]) ?? 0
            }
        }
        
        let accessoriesRegex = try? NSRegularExpression(pattern: "Total Accessories: (\\d+)", options: [])
        if let match = accessoriesRegex?.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
            if let range = Range(match.range(at: 1), in: content) {
                accessoryCount = Int(content[range]) ?? 0
            }
        }
        
        // Extract home name
        let homeNameRegex = try? NSRegularExpression(pattern: "Home: ([^\\n]+)", options: [])
        if let match = homeNameRegex?.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
            if let range = Range(match.range(at: 1), in: content) {
                homeName = String(content[range])
            }
        }
        
        // Build detailed summary
        var summary = "I've discovered your HomeKit configuration! "
        
        if homeCount > 0 {
            summary += "I found \(homeCount) home\(homeCount == 1 ? "" : "s")"
            if !homeName.isEmpty {
                summary += " called '\(homeName)'"
            }
            summary += " with \(roomCount) room\(roomCount == 1 ? "" : "s") and \(accessoryCount) device\(accessoryCount == 1 ? "" : "s"). "
            
            // Add room examples if available
            let roomsRegex = try? NSRegularExpression(pattern: "- ([^\\n]+) \\(\\d+ accessories\\)", options: [])
            let matches = roomsRegex?.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content)) ?? []
            let roomNames = matches.compactMap { match -> String? in
                if let range = Range(match.range(at: 1), in: content) {
                    return String(content[range])
                }
                return nil
            }
            
            if roomNames.count > 0 {
                let exampleRooms = roomNames.prefix(3).joined(separator: ", ")
                summary += "I can see rooms like \(exampleRooms)\(roomNames.count > 3 ? " and more" : ""). "
            }
            
            summary += "You can tap the HomeKit button on the main screen to open the Home app, or ask me about any of your rooms or devices!"
        } else {
            summary += "I can see your HomeKit setup. You can tap the HomeKit button on the main screen to open the Home app anytime."
        }
        
        // Add a prompt to continue with setup
        summary += "\n\nLet me know when you're ready to continue setting up your house profile!"
        
        return summary
    }
    
    private func handleNoteSelectionResponse(_ input: String, isMuted: Bool) async {
        // Clear the awaiting flag
        UserDefaults.standard.set(false, forKey: "awaitingNoteSelection")
        
        // Get stored note options
        guard let noteData = UserDefaults.standard.data(forKey: "pendingNoteOptions"),
              let noteOptions = try? JSONDecoder().decode([[String: String]].self, from: noteData) else {
            await generateHouseResponse(for: "I'm sorry, I don't have any notes to show. Please search again.", isMuted: isMuted)
            return
        }
        
        let lowercased = input.lowercased()
        
        // Check if user wants to see a specific number
        if let number = Int(lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
            if number > 0 && number <= noteOptions.count {
                let selected = noteOptions[number - 1]
                let response = "Here's what I remember about \(selected["questionText"] ?? "that"):\n\n\(selected["answer"] ?? "")"
                
                let message = Message(
                    content: response,
                    isFromUser: false,
                    isVoice: !isMuted
                )
                messageStore.addMessage(message)
                
                if !isMuted {
                    await stateManager.speak(response, isMuted: isMuted)
                }
                return
            }
        }
        
        // If yes without a number, show the first one
        if lowercased == "yes" || lowercased.contains("first") || lowercased.contains("one") {
            if let first = noteOptions.first {
                let response = "Here's what I remember about \(first["questionText"] ?? "that"):\n\n\(first["answer"] ?? "")"
                
                let message = Message(
                    content: response,
                    isFromUser: false,
                    isVoice: !isMuted
                )
                messageStore.addMessage(message)
                
                if !isMuted {
                    await stateManager.speak(response, isMuted: isMuted)
                }
            }
        } else {
            // They said something else, treat it as a new query
            UserDefaults.standard.removeObject(forKey: "pendingNoteOptions")
            await processUserInput(input, isMuted: isMuted)
        }
    }
    
    private func searchAndRespondWithNotes(query: String, isMuted: Bool) async {
        print("[ConversationViewModel] Searching notes for query: \(query)")
        
        do {
            // Load all notes
            let notesStore = try await serviceContainer.notesService.loadNotesStore()
            
            // Extract search terms from the query
            let lowercasedQuery = query.lowercased()
            let searchTerms = lowercasedQuery
                .replacingOccurrences(of: "what", with: "")
                .replacingOccurrences(of: "notes", with: "")
                .replacingOccurrences(of: "note", with: "")
                .replacingOccurrences(of: "remember", with: "")
                .replacingOccurrences(of: "about", with: "")
                .replacingOccurrences(of: "search", with: "")
                .replacingOccurrences(of: "for", with: "")
                .replacingOccurrences(of: "the", with: "")
                .replacingOccurrences(of: "tell", with: "")
                .replacingOccurrences(of: "me", with: "")
                .replacingOccurrences(of: "show", with: "")
                .replacingOccurrences(of: "rooms", with: "room")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ")
                .filter { !$0.isEmpty }
            
            print("[ConversationViewModel] Search terms: \(searchTerms)")
            
            // Debug: Log all available notes
            print("[ConversationViewModel] Available notes:")
            for (questionId, note) in notesStore.notes {
                if let question = notesStore.questions.first(where: { $0.id == questionId }) {
                    print("  - \(question.text)")
                }
            }
            
            // Search for matching notes with scores
            var matchingNotes: [(question: Question, note: Note, score: Int)] = []
            
            for (questionId, note) in notesStore.notes {
                guard let question = notesStore.questions.first(where: { $0.id == questionId }) else { continue }
                
                // Skip empty answers
                guard !note.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                
                // Check if any search term matches the question text or note content
                let questionLower = question.text.lowercased()
                let answerLower = note.answer.lowercased()
                
                // Count how many search terms match
                var matchScore = 0
                for term in searchTerms {
                    if questionLower.contains(term) {
                        matchScore += 2 // Title matches are worth more
                    }
                    if answerLower.contains(term) {
                        matchScore += 1
                    }
                }
                
                // If we have a match, add it with the score
                if matchScore > 0 {
                    matchingNotes.append((question: question, note: note, score: matchScore))
                }
            }
            
            // Sort by score (highest first)
            matchingNotes.sort { $0.score > $1.score }
            
            print("[ConversationViewModel] Found \(matchingNotes.count) matching notes")
            
            // Generate response based on findings
            let response: String
            if matchingNotes.isEmpty {
                response = "I don't have any notes that match your search. You can create new notes by saying 'add room note' or 'add device note'."
            } else if matchingNotes.count == 1 || (matchingNotes.count > 1 && matchingNotes[0].score > matchingNotes[1].score) {
                // Single match or clear best match - show it directly
                let match = matchingNotes[0]
                response = "Here's what I remember about \(match.question.text):\n\n\(match.note.answer)"
            } else {
                // Multiple similar matches - list them
                var notesList = "I found \(matchingNotes.count) notes that might be what you're looking for:\n\n"
                
                // Show top 5 matches
                for (index, match) in matchingNotes.prefix(5).enumerated() {
                    notesList += "\(index + 1). \(match.question.text)\n"
                    // Add first line of the answer as preview
                    let preview = match.note.answer
                        .components(separatedBy: .newlines)
                        .first ?? match.note.answer
                    let truncatedPreview = preview.count > 50 ? String(preview.prefix(50)) + "..." : preview
                    notesList += "   \(truncatedPreview)\n\n"
                }
                
                if matchingNotes.count > 5 {
                    notesList += "... and \(matchingNotes.count - 5) more.\n\n"
                }
                
                notesList += "Would you like me to read any of these in detail?"
                response = notesList
                
                // Store the matching notes for later reference
                UserDefaults.standard.set(true, forKey: "awaitingNoteSelection")
                // Store the note data for selection
                let noteData = matchingNotes.prefix(5).map { match in
                    ["questionText": match.question.text, "answer": match.note.answer]
                }
                if let encoded = try? JSONEncoder().encode(noteData) {
                    UserDefaults.standard.set(encoded, forKey: "pendingNoteOptions")
                }
            }
            
            // Create and send the response
            let message = Message(
                content: response,
                isFromUser: false,
                isVoice: !isMuted
            )
            messageStore.addMessage(message)
            
            if !isMuted {
                await stateManager.speak(response, isMuted: isMuted)
            }
            
        } catch {
            print("[ConversationViewModel] Error searching notes: \(error)")
            await generateHouseResponse(for: "I had trouble searching my notes. Please try again.", isMuted: isMuted)
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
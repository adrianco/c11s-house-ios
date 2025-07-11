/*
 * CONTEXT & PURPOSE:
 * Message model represents a single message in the conversation between the user and the house.
 * It supports both text and voice messages, with persistence and UI display information.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Initial implementation
 *   - Support for user and house messages
 *   - Timestamp for chronological ordering
 *   - isVoice flag to track if message was spoken
 *   - Codable for persistence
 *   - Identifiable for SwiftUI lists
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let isVoice: Bool // Was this message spoken (vs typed)
    
    init(
        id: UUID = UUID(),
        content: String,
        isFromUser: Bool,
        timestamp: Date = Date(),
        isVoice: Bool = false
    ) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.isVoice = isVoice
    }
}

// MARK: - Message Storage

class MessageStore: ObservableObject {
    @Published var messages: [Message] = []
    
    private let storageKey = "conversation_messages"
    private let maxMessages = 500 // Limit storage
    
    init() {
        loadMessages()
    }
    
    func addMessage(_ message: Message) {
        messages.append(message)
        
        // Keep only recent messages
        if messages.count > maxMessages {
            messages = Array(messages.suffix(maxMessages))
        }
        
        saveMessages()
    }
    
    func clearMessages() {
        messages.removeAll()
        saveMessages()
    }
    
    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Message].self, from: data) else {
            return
        }
        messages = decoded
    }
    
    private func saveMessages() {
        guard let encoded = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}
/*
 * CONTEXT & PURPOSE:
 * HouseThought represents a conscious thought from the house's AI system. It encapsulates
 * the house's observations, insights, or suggestions about the current context, providing
 * a personality-driven interface for the house consciousness to communicate with users.
 *
 * DECISION HISTORY:
 * - 2025-07-07: Initial implementation
 *   - Struct-based model for value semantics and SwiftUI compatibility
 *   - Emotion state to reflect house's current feeling
 *   - Thought content as the main message
 *   - Context for understanding what triggered the thought
 *   - Confidence level to indicate certainty
 *   - Timestamp for tracking when thoughts occurred
 *   - Codable for persistence and API communication
 *   - Identifiable for SwiftUI list handling
 *   - Category to classify different types of thoughts
 *   - Optional suggestion for actionable insights
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation

/// Represents a thought or insight from the house consciousness
struct HouseThought: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let thought: String
    let emotion: HouseEmotion
    let category: ThoughtCategory
    let confidence: Double
    let context: String?
    let suggestion: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        thought: String,
        emotion: HouseEmotion = .neutral,
        category: ThoughtCategory = .observation,
        confidence: Double = 1.0,
        context: String? = nil,
        suggestion: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.thought = thought
        self.emotion = emotion
        self.category = category
        self.confidence = max(0.0, min(1.0, confidence))
        self.context = context
        self.suggestion = suggestion
    }
}

/// Emotions that the house consciousness can express
enum HouseEmotion: String, Codable, CaseIterable {
    case happy
    case curious
    case concerned
    case excited
    case neutral
    case confused
    case proud
    case thoughtful
    
    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .curious: return "Curious"
        case .concerned: return "Concerned"
        case .excited: return "Excited"
        case .neutral: return "Neutral"
        case .confused: return "Confused"
        case .proud: return "Proud"
        case .thoughtful: return "Thoughtful"
        }
    }
    
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .curious: return "🤔"
        case .concerned: return "😟"
        case .excited: return "🤗"
        case .neutral: return "😐"
        case .confused: return "😕"
        case .proud: return "😌"
        case .thoughtful: return "🧐"
        }
    }
}

/// Categories for different types of house thoughts
enum ThoughtCategory: String, Codable, CaseIterable {
    case observation
    case suggestion
    case question
    case memory
    case learning
    case greeting
    case warning
    case celebration
    
    var displayName: String {
        switch self {
        case .observation: return "Observation"
        case .suggestion: return "Suggestion"
        case .question: return "Question"
        case .memory: return "Memory"
        case .learning: return "Learning"
        case .greeting: return "Greeting"
        case .warning: return "Warning"
        case .celebration: return "Celebration"
        }
    }
    
    var icon: String {
        switch self {
        case .observation: return "eye"
        case .suggestion: return "lightbulb"
        case .question: return "questionmark.circle"
        case .memory: return "brain"
        case .learning: return "book"
        case .greeting: return "hand.wave"
        case .warning: return "exclamationmark.triangle"
        case .celebration: return "party.popper"
        }
    }
}

// MARK: - Sample House Thoughts

extension HouseThought {
    /// Sample thoughts for preview and testing
    static let samples = [
        HouseThought(
            thought: "I notice you're starting a conversation. I'm here to help manage your home!",
            emotion: .happy,
            category: .greeting,
            confidence: 1.0,
            context: "User opened conversation view"
        ),
        HouseThought(
            thought: "The living room has been quite warm today. Would you like me to adjust the temperature?",
            emotion: .concerned,
            category: .suggestion,
            confidence: 0.85,
            context: "Temperature sensor reading",
            suggestion: "Lower temperature by 2 degrees"
        ),
        HouseThought(
            thought: "I'm learning about your daily routines to better assist you.",
            emotion: .thoughtful,
            category: .learning,
            confidence: 0.9,
            context: "Pattern recognition from usage data"
        )
    ]
}
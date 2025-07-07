/*
 * CONTEXT & PURPOSE:
 * NotesStore.swift defines the data models for the house-related Q&A notes system. It provides
 * structures for questions and their corresponding notes (answers), supporting a persistent
 * knowledge base about the house that can be extended with additional questions over time.
 *
 * DECISION HISTORY:
 * - 2025-07-07: Initial implementation
 *   - Question struct with id, text, category, and order for flexible organization
 *   - Note struct with answer text, timestamps, and optional metadata
 *   - UUID-based identifiers for unique question identification
 *   - Category enum for grouping related questions (personal, house info, maintenance, etc.)
 *   - Codable conformance for easy persistence with UserDefaults or JSON
 *   - Equatable and Hashable for SwiftUI list management
 *   - Optional fields in Note for progressive information capture
 *   - lastModified tracking for change detection
 *   - displayOrder for custom question sequencing
 *   - Built-in predefined questions starting with "What's your name?"
 *   - Extensible design to add more questions dynamically
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  NotesStore.swift
//  C11SHouse
//
//  Data models for house-related Q&A notes system
//

import Foundation

/// Categories for organizing house-related questions
enum QuestionCategory: String, Codable, CaseIterable {
    case personal = "Personal"
    case houseInfo = "House Information"
    case maintenance = "Maintenance"
    case preferences = "Preferences"
    case reminders = "Reminders"
    case other = "Other"
    
    var displayName: String {
        self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .personal: return "person.circle"
        case .houseInfo: return "house"
        case .maintenance: return "wrench.and.screwdriver"
        case .preferences: return "gearshape"
        case .reminders: return "bell"
        case .other: return "questionmark.circle"
        }
    }
}

/// Represents a question that can be asked about the house
struct Question: Codable, Equatable, Hashable, Identifiable {
    /// Unique identifier for the question
    let id: UUID
    
    /// The question text
    let text: String
    
    /// Category for organization
    let category: QuestionCategory
    
    /// Display order (lower numbers appear first)
    let displayOrder: Int
    
    /// Whether this question is required
    let isRequired: Bool
    
    /// Optional hint text to help users answer
    let hint: String?
    
    /// Date when the question was created
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        text: String,
        category: QuestionCategory,
        displayOrder: Int,
        isRequired: Bool = false,
        hint: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.category = category
        self.displayOrder = displayOrder
        self.isRequired = isRequired
        self.hint = hint
        self.createdAt = createdAt
    }
}

/// Represents a note (answer) for a specific question
struct Note: Codable, Equatable, Hashable {
    /// Reference to the question this note answers
    let questionId: UUID
    
    /// The answer/note text
    var answer: String
    
    /// When the note was first created
    let createdAt: Date
    
    /// When the note was last modified
    var lastModified: Date
    
    /// Optional metadata (e.g., voice recording reference, image paths)
    var metadata: [String: String]?
    
    /// Whether this note has been completed/answered
    var isAnswered: Bool {
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(
        questionId: UUID,
        answer: String = "",
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.questionId = questionId
        self.answer = answer
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.metadata = metadata
    }
    
    /// Update the answer and timestamp
    mutating func updateAnswer(_ newAnswer: String) {
        self.answer = newAnswer
        self.lastModified = Date()
    }
    
    /// Add or update metadata
    mutating func setMetadata(key: String, value: String) {
        if metadata == nil {
            metadata = [:]
        }
        metadata?[key] = value
        lastModified = Date()
    }
}

/// Container for all questions and notes
struct NotesStoreData: Codable {
    /// All available questions
    var questions: [Question]
    
    /// All notes (answers) keyed by question ID
    var notes: [UUID: Note]
    
    /// Version for migration support
    let version: Int
    
    init(questions: [Question] = [], notes: [UUID: Note] = [:], version: Int = 1) {
        self.questions = questions
        self.notes = notes
        self.version = version
    }
    
    /// Get all questions sorted by display order
    var sortedQuestions: [Question] {
        questions.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    /// Get questions by category
    func questions(in category: QuestionCategory) -> [Question] {
        questions.filter { $0.category == category }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
    
    /// Get the note for a specific question
    func note(for question: Question) -> Note? {
        notes[question.id]
    }
    
    /// Check if a question has been answered
    func isAnswered(_ question: Question) -> Bool {
        notes[question.id]?.isAnswered ?? false
    }
    
    /// Get completion percentage
    var completionPercentage: Double {
        guard !questions.isEmpty else { return 0 }
        let answeredCount = questions.filter { isAnswered($0) }.count
        return Double(answeredCount) / Double(questions.count) * 100
    }
}

// MARK: - Predefined Questions

extension Question {
    /// The initial set of questions for the house
    static let predefinedQuestions: [Question] = [
        // Personal category - starting with "What's your name?"
        Question(
            text: "What's your name?",
            category: .personal,
            displayOrder: 1,
            isRequired: true,
            hint: "Enter your name or what you'd like the house to call you"
        ),
        
        // Additional questions for future use
        Question(
            text: "What's your preferred wake-up time?",
            category: .preferences,
            displayOrder: 2,
            hint: "Enter your usual wake-up time (e.g., 7:00 AM)"
        ),
        
        Question(
            text: "What's your home address?",
            category: .houseInfo,
            displayOrder: 3,
            hint: "Full street address for delivery and emergency services"
        ),
        
        Question(
            text: "When was your last HVAC maintenance?",
            category: .maintenance,
            displayOrder: 4,
            hint: "Date of last heating/cooling system service"
        ),
        
        Question(
            text: "Any allergies or dietary restrictions?",
            category: .personal,
            displayOrder: 5,
            hint: "Important for meal planning and emergency information"
        )
    ]
}
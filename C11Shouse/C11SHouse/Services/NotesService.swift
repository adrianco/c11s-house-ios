/*
 * CONTEXT & PURPOSE:
 * NotesService is the CENTRAL PERSISTENT MEMORY SYSTEM for the entire app. It serves as the
 * single source of truth for all user data, house preferences, Q&A responses, weather summaries,
 * and any other contextual information the house consciousness needs to remember. This service
 * is designed to be the foundation for AI context and backend synchronization.
 *
 * ARCHITECTURAL ROLE:
 * - Central Memory: All user data and house state is persisted here
 * - AI Context Provider: All notes will be provided as context for AI conversations
 * - Backend Ready: Designed to easily sync with a future backend service
 * - Extensible: New note types can be added without breaking existing functionality
 * - Single Source of Truth: All coordinators and services persist data through NotesService
 *
 * DECISION HISTORY:
 * - 2025-07-07: Initial implementation
 *   - Protocol-based design matching existing service patterns
 *   - UserDefaults for persistence (suitable for small structured data)
 *   - Combine publishers for reactive updates to UI
 *   - Async/await API for consistency with other services
 *   - Automatic initialization with predefined questions
 *   - Thread-safe operations with @MainActor where needed
 *   - JSON encoding for UserDefaults storage
 *   - Graceful migration support via version field
 *   - Error handling with descriptive error types
 *   - Batch update support for efficiency
 *   - Change tracking with lastModified timestamps
 * - 2025-01-09: Documented as central memory system
 *   - Clarified role as the app's persistent memory foundation
 *   - Emphasized importance for AI context and backend sync
 *   - Documented that all coordinators should persist through this service
 *
 * FUTURE UPDATES:
 * - Backend synchronization for cross-device persistence
 * - Additional note types (reminders, maintenance logs, preferences)
 * - AI context optimization (relevance scoring, context windows)
 * - Encrypted storage for sensitive information
 */

//
//  NotesService.swift
//  C11SHouse
//
//  Service layer for managing house Q&A notes
//

import Foundation
import Combine

/// Type alias for backward compatibility
typealias NotesService = NotesServiceProtocol

/// Protocol defining the notes service interface
protocol NotesServiceProtocol {
    /// Publisher for notes store updates
    var notesStorePublisher: AnyPublisher<NotesStoreData, Never> { get }
    
    /// Load all questions and notes
    func loadNotesStore() async throws -> NotesStoreData
    
    /// Save a note (answer) for a question
    func saveNote(_ note: Note) async throws
    
    /// Update an existing note
    func updateNote(_ note: Note) async throws
    
    /// Delete a note for a question
    func deleteNote(for questionId: UUID) async throws
    
    /// Add a new custom question
    func addQuestion(_ question: Question) async throws
    
    /// Delete a question and its associated note
    func deleteQuestion(_ questionId: UUID) async throws
    
    /// Reset to default questions (keeps existing answers)
    func resetToDefaults() async throws
    
    /// Clear all data
    func clearAllData() async throws
}

/// Concrete implementation of NotesService using UserDefaults
class NotesServiceImpl: NotesServiceProtocol {
    
    // MARK: - Constants
    
    private let userDefaultsKey = "com.c11shouse.notesStore"
    private let currentVersion = 1
    
    // MARK: - Properties
    
    private let notesStoreSubject = CurrentValueSubject<NotesStoreData, Never>(NotesStoreData())
    var notesStorePublisher: AnyPublisher<NotesStoreData, Never> {
        notesStoreSubject.eraseToAnyPublisher()
    }
    
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Load initial data
        Task {
            try? await loadAndInitialize()
        }
    }
    
    // MARK: - Public Methods
    
    func loadNotesStore() async throws -> NotesStoreData {
        let store = try await loadFromUserDefaults()
        await MainActor.run {
            notesStoreSubject.send(store)
        }
        return store
    }
    
    func saveNote(_ note: Note) async throws {
        var store = try await loadFromUserDefaults()
        
        // Ensure the question exists
        guard store.questions.contains(where: { $0.id == note.questionId }) else {
            throw NotesError.questionNotFound(note.questionId)
        }
        
        // Save or update the note
        store.notes[note.questionId] = note
        
        try await save(store)
    }
    
    func updateNote(_ note: Note) async throws {
        var store = try await loadFromUserDefaults()
        
        // Ensure the note exists
        guard store.notes[note.questionId] != nil else {
            throw NotesError.noteNotFound(note.questionId)
        }
        
        // Update with new timestamp
        var updatedNote = note
        updatedNote.lastModified = Date()
        store.notes[note.questionId] = updatedNote
        
        try await save(store)
    }
    
    func deleteNote(for questionId: UUID) async throws {
        var store = try await loadFromUserDefaults()
        store.notes.removeValue(forKey: questionId)
        try await save(store)
    }
    
    func addQuestion(_ question: Question) async throws {
        var store = try await loadFromUserDefaults()
        
        // Check for duplicates
        if store.questions.contains(where: { $0.id == question.id }) {
            throw NotesError.duplicateQuestion(question.id)
        }
        
        store.questions.append(question)
        try await save(store)
    }
    
    func deleteQuestion(_ questionId: UUID) async throws {
        var store = try await loadFromUserDefaults()
        
        // Remove the question
        store.questions.removeAll { $0.id == questionId }
        
        // Remove associated note
        store.notes.removeValue(forKey: questionId)
        
        try await save(store)
    }
    
    func resetToDefaults() async throws {
        var store = try await loadFromUserDefaults()
        
        // Keep existing notes for predefined questions
        let existingNotes = store.notes
        
        // Reset questions to predefined set
        store.questions = Question.predefinedQuestions
        
        // Restore notes for questions that still exist
        var newNotes: [UUID: Note] = [:]
        for question in store.questions {
            if let existingNote = existingNotes[question.id] {
                newNotes[question.id] = existingNote
            }
        }
        store.notes = newNotes
        
        try await save(store)
    }
    
    func clearAllData() async throws {
        print("[NotesService] Clearing all data...")
        let emptyStore = NotesStoreData(
            questions: Question.predefinedQuestions,
            notes: [:],
            version: currentVersion
        )
        print("[NotesService] Resetting to \(emptyStore.questions.count) predefined questions")
        try await save(emptyStore)
    }
    
    // MARK: - Private Methods
    
    private func loadAndInitialize() async throws {
        do {
            let store = try await loadFromUserDefaults()
            await MainActor.run {
                notesStoreSubject.send(store)
            }
        } catch {
            // Initialize with default questions on first launch
            let initialStore = NotesStoreData(
                questions: Question.predefinedQuestions,
                notes: [:],
                version: currentVersion
            )
            try await save(initialStore)
        }
    }
    
    private func loadFromUserDefaults() async throws -> NotesStoreData {
        guard let data = userDefaults.data(forKey: userDefaultsKey) else {
            // Return default store if no data exists
            return NotesStoreData(
                questions: Question.predefinedQuestions,
                notes: [:],
                version: currentVersion
            )
        }
        
        do {
            var store = try decoder.decode(NotesStoreData.self, from: data)
            
            // Handle version migration if needed
            if store.version < currentVersion {
                store = try migrateStore(store)
            }
            
            return store
        } catch {
            throw NotesError.decodingFailed(error)
        }
    }
    
    private func save(_ store: NotesStoreData) async throws {
        do {
            let data = try encoder.encode(store)
            userDefaults.set(data, forKey: userDefaultsKey)
            await MainActor.run {
                notesStoreSubject.send(store)
            }
        } catch {
            throw NotesError.encodingFailed(error)
        }
    }
    
    private func migrateStore(_ store: NotesStoreData) throws -> NotesStoreData {
        var migratedQuestions = store.questions
        var migratedNotes = store.notes
        
        // Migrate old house name question to new one
        let oldHouseNameQuestionId = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        
        // Check if we have the old question
        if let oldQuestionIndex = migratedQuestions.firstIndex(where: { $0.text == "What is your house's name?" }) {
            // Find the new question
            if let newQuestion = migratedQuestions.first(where: { $0.text == "What should I call this house?" }) {
                // Transfer the note from old to new if it exists
                if let oldNote = migratedNotes[oldHouseNameQuestionId] {
                    migratedNotes[newQuestion.id] = Note(
                        questionId: newQuestion.id,
                        answer: oldNote.answer,
                        createdAt: oldNote.createdAt,
                        lastModified: oldNote.lastModified,
                        metadata: oldNote.metadata
                    )
                }
                // Remove the old note
                migratedNotes.removeValue(forKey: oldHouseNameQuestionId)
            }
            // Remove the old question
            migratedQuestions.remove(at: oldQuestionIndex)
        }
        
        // Add Phase 4 question if it doesn't exist
        let phase4Text = "Let's start by creating your first room note! What room would you like to add a note about?"
        if !migratedQuestions.contains(where: { $0.text == phase4Text }) {
            // Check if user has completed the first 3 questions
            let requiredQuestions = ["Is this the right address?", "What should I call this house?", "What's your name?"]
            let hasCompletedBasics = requiredQuestions.allSatisfy { questionText in
                if let question = migratedQuestions.first(where: { $0.text == questionText }) {
                    return migratedNotes[question.id]?.isAnswered ?? false
                }
                return false
            }
            
            // Only add Phase 4 question if basics are complete and user hasn't completed phase 4
            if hasCompletedBasics && !UserDefaults.standard.bool(forKey: "hasCompletedPhase4Tutorial") {
                let phase4Question = Question(
                    text: phase4Text,
                    category: .houseInfo,
                    displayOrder: 3,
                    isRequired: true,
                    hint: "Tell me about a room in your house (e.g., 'living room', 'kitchen', 'bedroom')"
                )
                migratedQuestions.append(phase4Question)
            }
        }
        
        return NotesStoreData(
            questions: migratedQuestions,
            notes: migratedNotes,
            version: currentVersion
        )
    }
}

// MARK: - Error Types

enum NotesError: LocalizedError {
    case questionNotFound(UUID)
    case noteNotFound(UUID)
    case duplicateQuestion(UUID)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case migrationFailed(String)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .questionNotFound(let id):
            return "Question with ID \(id) not found"
        case .noteNotFound(let id):
            return "Note for question \(id) not found"
        case .duplicateQuestion(let id):
            return "Question with ID \(id) already exists"
        case .encodingFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to load data: \(error.localizedDescription)"
        case .migrationFailed(let reason):
            return "Data migration failed: \(reason)"
        case .noData:
            return "No saved data found"
        }
    }
}

// MARK: - Convenience Extensions

extension NotesServiceProtocol {
    /// Save or update a note based on whether it exists
    func saveOrUpdateNote(for questionId: UUID, answer: String, metadata: [String: String]? = nil) async throws {
        let store = try await loadNotesStore()
        
        if var existingNote = store.notes[questionId] {
            // Update existing note
            existingNote.updateAnswer(answer)
            if let metadata = metadata {
                for (key, value) in metadata {
                    existingNote.setMetadata(key: key, value: value)
                }
            }
            try await updateNote(existingNote)
        } else {
            // Create new note
            let newNote = Note(
                questionId: questionId,
                answer: answer,
                metadata: metadata
            )
            try await saveNote(newNote)
        }
    }
    
    /// Get a specific note by question ID
    func getNote(for questionId: UUID) async throws -> Note? {
        let store = try await loadNotesStore()
        return store.notes[questionId]
    }
    
    /// Get all unanswered questions
    func getUnansweredQuestions() async throws -> [Question] {
        let store = try await loadNotesStore()
        return store.sortedQuestions.filter { !store.isAnswered($0) }
    }
}


// MARK: - Weather and House Name Extensions

extension NotesServiceProtocol {
    /// Save current weather summary as a note
    /// Note: This is primarily used by WeatherCoordinator. Direct usage should be avoided.
    func saveWeatherSummary(_ weather: Weather) async {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let weatherSummary = """
        🌤️ Weather Update - \(formatter.string(from: weather.lastUpdated))
        
        Current Conditions:
        • Temperature: \(weather.temperature.formatted) (feels like \(weather.feelsLike.formatted))
        • Condition: \(weather.condition.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
        • Humidity: \(Int(weather.humidity * 100))%
        • Wind Speed: \(String(format: "%.1f", weather.windSpeed)) m/s
        • UV Index: \(weather.uvIndex)
        • Pressure: \(String(format: "%.0f", weather.pressure)) hPa
        • Visibility: \(String(format: "%.1f", weather.visibility / 1000)) km
        
        Today's Forecast:
        """
        
        var fullSummary = weatherSummary
        
        // Add daily forecast
        if let todayForecast = weather.forecast.first {
            fullSummary += "\n• High: \(todayForecast.highTemperature.formatted)"
            fullSummary += "\n• Low: \(todayForecast.lowTemperature.formatted)"
            fullSummary += "\n• Chance of precipitation: \(Int(todayForecast.precipitationChance * 100))%"
        }
        
        // Create a weather question if it doesn't exist
        let weatherQuestionId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        let weatherQuestion = Question(
            id: weatherQuestionId,
            text: "Current Weather Summary",
            category: .other,
            displayOrder: 999,
            isRequired: false,
            hint: "Automatically updated weather information"
        )
        
        // Save the weather summary
        do {
            try await addQuestion(weatherQuestion)
        } catch {
            // Question might already exist, that's okay
        }
        
        try? await saveOrUpdateNote(
            for: weatherQuestionId,
            answer: fullSummary,
            metadata: [
                "type": "weather_summary",
                "timestamp": ISO8601DateFormatter().string(from: weather.lastUpdated)
            ]
        )
    }
    
    /// Generate and save house name from address
    func saveHouseName(_ name: String) async {
        // Find the house name question from predefined questions
        let notesStore = try? await loadNotesStore()
        if let houseNameQuestion = notesStore?.questions.first(where: { $0.text == "What should I call this house?" }) {
            try? await saveOrUpdateNote(
                for: houseNameQuestion.id,
                answer: name,
                metadata: [
                    "type": "house_name",
                    "updated_via_conversation": "true"
                ]
            )
        }
    }
    
    /// Get saved house name
    func getHouseName() async -> String? {
        // Find the house name question from predefined questions
        let notesStore = try? await loadNotesStore()
        if let houseNameQuestion = notesStore?.questions.first(where: { $0.text == "What should I call this house?" }),
           let note = notesStore?.notes[houseNameQuestion.id],
           !note.answer.isEmpty {
            return note.answer
        }
        return nil
    }
    
    /// Save a custom note (for room notes, device notes, etc.)
    func saveCustomNote(title: String, content: String, category: String) async {
        // Create a unique question for this custom note
        let customQuestion = Question(
            text: title,
            category: .other,
            displayOrder: 1000 + Int.random(in: 0...999), // High display order for custom notes
            isRequired: false,
            hint: "Custom \(category) note"
        )
        
        // Try to add the question
        do {
            try await addQuestion(customQuestion)
            
            // Save the note content
            try await saveOrUpdateNote(
                for: customQuestion.id,
                answer: content,
                metadata: [
                    "type": "custom_\(category)",
                    "category": category,
                    "created_via": "tutorial"
                ]
            )
        } catch {
            // If question already exists (unlikely with UUID), try updating
            if let existingQuestion = try? await loadNotesStore().questions.first(where: { $0.text == title }) {
                try? await saveOrUpdateNote(
                    for: existingQuestion.id,
                    answer: content,
                    metadata: [
                        "type": "custom_\(category)",
                        "category": category,
                        "updated_via": "tutorial"
                    ]
                )
            }
        }
    }
}
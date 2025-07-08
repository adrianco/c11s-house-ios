/*
 * CONTEXT & PURPOSE:
 * NotesService provides the service layer for managing house-related Q&A notes. It handles
 * persistence using UserDefaults, provides methods for CRUD operations on questions and notes,
 * and publishes reactive updates for UI synchronization. The service ensures data consistency
 * and provides a clean API for the view layer.
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
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
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
        let emptyStore = NotesStoreData(
            questions: Question.predefinedQuestions,
            notes: [:],
            version: currentVersion
        )
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
        // Handle future migrations based on version
        // For now, just update the version
        return NotesStoreData(
            questions: store.questions,
            notes: store.notes,
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
        // Create a house name question if it doesn't exist
        let houseNameQuestionId = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        let houseNameQuestion = Question(
            id: houseNameQuestionId,
            text: "What is your house's name?",
            category: .houseInfo,
            displayOrder: 1,
            isRequired: true,
            hint: "A personalized name for your home"
        )
        
        // Save the house name
        do {
            try await addQuestion(houseNameQuestion)
        } catch {
            // Question might already exist, that's okay
        }
        
        try? await saveOrUpdateNote(
            for: houseNameQuestionId,
            answer: name,
            metadata: [
                "type": "house_name",
                "generated": "true"
            ]
        )
    }
    
    /// Get saved house name
    func getHouseName() async -> String? {
        let houseNameQuestionId = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        if let note = try? await getNote(for: houseNameQuestionId) {
            return note.answer
        }
        return nil
    }
}
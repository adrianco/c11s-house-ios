/*
 * CONTEXT & PURPOSE:
 * Centralized mock implementations for test classes to avoid duplicate definitions
 * and resolve ambiguous type lookups. All test mocks are defined here once.
 *
 * DECISION HISTORY:
 * - 2025-01-10: Created to resolve ambiguous mock class definitions
 *   - Centralized all mock implementations
 *   - Added proper protocol conformance
 *   - Included necessary imports
 */

import Foundation
import Combine
import CoreLocation
@testable import C11SHouse

// MARK: - Location Service Mocks

class MockLocationService: LocationServiceProtocol {
    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> {
        currentLocationSubject.eraseToAnyPublisher()
    }
    
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }
    
    private let currentLocationSubject = CurrentValueSubject<CLLocation?, Never>(nil)
    private let authorizationStatusSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.notDetermined)
    
    var requestLocationPermissionCalled = false
    var getCurrentLocationCalled = false
    var lookupAddressCalled = false
    var confirmAddressCalled = false
    
    var getCurrentLocationResult: Result<CLLocation, Error> = .failure(LocationError.locationUnavailable)
    var lookupAddressResult: Result<Address, Error> = .failure(LocationError.geocodingFailed)
    
    func requestLocationPermission() async {
        requestLocationPermissionCalled = true
        authorizationStatusSubject.send(.authorizedWhenInUse)
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        getCurrentLocationCalled = true
        switch getCurrentLocationResult {
        case .success(let location):
            currentLocationSubject.send(location)
            return location
        case .failure(let error):
            throw error
        }
    }
    
    func lookupAddress(for location: CLLocation) async throws -> Address {
        lookupAddressCalled = true
        switch lookupAddressResult {
        case .success(let address):
            return address
        case .failure(let error):
            throw error
        }
    }
    
    func confirmAddress(_ address: Address) async throws {
        confirmAddressCalled = true
    }
    
    func setAuthorizationStatus(_ status: CLAuthorizationStatus) {
        authorizationStatusSubject.send(status)
    }
}

// MARK: - TTS Service Mocks

class MockTTSService: TTSService {
    var isSpeaking: Bool = false
    
    var isSpeakingPublisher: AnyPublisher<Bool, Never> {
        isSpeakingSubject.eraseToAnyPublisher()
    }
    
    var speechProgressPublisher: AnyPublisher<Float, Never> {
        speechProgressSubject.eraseToAnyPublisher()
    }
    
    private let isSpeakingSubject = CurrentValueSubject<Bool, Never>(false)
    private let speechProgressSubject = CurrentValueSubject<Float, Never>(0.0)
    
    var speakCalled = false
    var lastSpokenText: String?
    var speakError: Error?
    
    func speak(_ text: String, language: String?) async throws {
        speakCalled = true
        lastSpokenText = text
        
        if let error = speakError {
            throw error
        }
        
        isSpeaking = true
        isSpeakingSubject.send(true)
        
        // Simulate speech progress
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        speechProgressSubject.send(0.5)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        speechProgressSubject.send(1.0)
        
        isSpeaking = false
        isSpeakingSubject.send(false)
    }
    
    func stopSpeaking() {
        isSpeaking = false
        isSpeakingSubject.send(false)
    }
    
    func pauseSpeaking() {
        // No-op for tests
    }
    
    func continueSpeaking() {
        // No-op for tests
    }
    
    func setRate(_ rate: Float) {
        // No-op for tests
    }
    
    func setPitch(_ pitch: Float) {
        // No-op for tests
    }
}

// MARK: - Notes Service Mocks

class MockNotesService: NotesServiceProtocol {
    var notesStorePublisher: AnyPublisher<NotesStore, Never> {
        notesStoreSubject.eraseToAnyPublisher()
    }
    
    private let notesStoreSubject = CurrentValueSubject<NotesStore, Never>(NotesStore(questions: [], notes: [:]))
    
    var savedNotes: [Note] = []
    var loadNotesStoreCalled = false
    var saveHouseNameCalled = false
    var lastSavedHouseName: String?
    
    var mockNotesStore = NotesStore(questions: [], notes: [:])
    var mockHouseName: String?
    
    func loadNotesStore() async throws -> NotesStore {
        loadNotesStoreCalled = true
        return mockNotesStore
    }
    
    func saveNote(_ note: Note) async throws {
        savedNotes.append(note)
        var currentStore = mockNotesStore
        currentStore.notes[note.questionId] = note
        mockNotesStore = currentStore
        notesStoreSubject.send(mockNotesStore)
    }
    
    func getNote(for questionId: UUID) async throws -> Note? {
        return mockNotesStore.notes[questionId]
    }
    
    func updateNote(_ note: Note) async throws {
        if let index = savedNotes.firstIndex(where: { $0.questionId == note.questionId }) {
            savedNotes[index] = note
        }
        var currentStore = mockNotesStore
        currentStore.notes[note.questionId] = note
        mockNotesStore = currentStore
        notesStoreSubject.send(mockNotesStore)
    }
    
    func deleteNote(questionId: UUID) async throws {
        savedNotes.removeAll { $0.questionId == questionId }
        var currentStore = mockNotesStore
        currentStore.notes.removeValue(forKey: questionId)
        mockNotesStore = currentStore
        notesStoreSubject.send(mockNotesStore)
    }
    
    func exportNotes() async throws -> Data {
        return try JSONEncoder().encode(mockNotesStore)
    }
    
    func importNotes(from data: Data) async throws {
        let imported = try JSONDecoder().decode(NotesStore.self, from: data)
        mockNotesStore = imported
        notesStoreSubject.send(mockNotesStore)
    }
    
    func getHouseName() async -> String? {
        return mockHouseName
    }
    
    func saveHouseName(_ name: String) async {
        saveHouseNameCalled = true
        lastSavedHouseName = name
        mockHouseName = name
    }
    
    func saveOrUpdateNote(for questionId: UUID, answer: String, metadata: [String: String]?) async throws {
        let note = Note(
            questionId: questionId,
            answer: answer,
            timestamp: Date(),
            metadata: metadata
        )
        try await saveNote(note)
    }
}

// MARK: - Weather Service Mocks

class MockWeatherKitService: WeatherKitServiceProtocol {
    var weatherPublisher: AnyPublisher<Weather?, Never> {
        weatherSubject.eraseToAnyPublisher()
    }
    
    private let weatherSubject = CurrentValueSubject<Weather?, Never>(nil)
    
    var fetchWeatherCalled = false
    var mockWeather: Weather?
    var shouldThrowError = false
    
    func fetchWeather(for coordinate: Coordinate) async throws -> Weather {
        fetchWeatherCalled = true
        
        if shouldThrowError {
            throw WeatherError.serviceUnavailable
        }
        
        let weather = mockWeather ?? Weather(
            temperature: Temperature(value: 20, unit: .celsius),
            condition: .clear,
            humidity: 0.5,
            windSpeed: 10,
            feelsLike: Temperature(value: 18, unit: .celsius),
            uvIndex: 5,
            pressure: 1013,
            visibility: 10000,
            dewPoint: 12,
            forecast: [],
            hourlyForecast: [],
            lastUpdated: Date()
        )
        
        weatherSubject.send(weather)
        return weather
    }
}

// MARK: - Conversation Recognizer Mock

protocol ConversationRecognizerProtocol {
    func setQuestionThought(_ question: String) async
    func setThankYouThought() async
    func clearHouseThought() async
}

class MockConversationRecognizer: ConversationRecognizerProtocol {
    var setQuestionThoughtCalled = false
    var lastQuestionThought: String?
    
    var setThankYouThoughtCalled = false
    var clearHouseThoughtCalled = false
    
    func setQuestionThought(_ question: String) async {
        setQuestionThoughtCalled = true
        lastQuestionThought = question
    }
    
    func setThankYouThought() async {
        setThankYouThoughtCalled = true
    }
    
    func clearHouseThought() async {
        clearHouseThoughtCalled = true
    }
}

// MARK: - Address Manager Mock

class MockAddressManager: AddressManager {
    var detectCurrentAddressCalled = false
    var mockDetectedAddress: Address?
    var parseAddressCalled = false
    var saveAddressCalled = false
    
    override func detectCurrentAddress() async throws -> Address {
        detectCurrentAddressCalled = true
        if let address = mockDetectedAddress {
            return address
        }
        throw LocationError.geocodingFailed
    }
    
    override func parseAddress(_ text: String) -> Address? {
        parseAddressCalled = true
        // Simple mock implementation
        if text.contains(",") {
            return Address(
                street: "123 Mock St",
                city: "Mock City",
                state: "MC",
                postalCode: "12345",
                country: "USA",
                coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194)
            )
        }
        return nil
    }
    
    override func saveAddress(_ address: Address) async throws {
        saveAddressCalled = true
    }
}

// MARK: - Permission Manager Mock

class MockPermissionManager: PermissionManagerProtocol {
    var mockLocationStatus: PermissionStatus = .notDetermined
    var mockMicrophoneStatus: PermissionStatus = .notDetermined
    var mockSpeechStatus: PermissionStatus = .notDetermined
    
    func checkLocationPermission() async -> PermissionStatus {
        return mockLocationStatus
    }
    
    func requestLocationPermission() async -> PermissionStatus {
        mockLocationStatus = .authorized
        return mockLocationStatus
    }
    
    func checkMicrophonePermission() async -> PermissionStatus {
        return mockMicrophoneStatus
    }
    
    func requestMicrophonePermission() async -> PermissionStatus {
        mockMicrophoneStatus = .authorized
        return mockMicrophoneStatus
    }
    
    func checkSpeechRecognitionPermission() async -> PermissionStatus {
        return mockSpeechStatus
    }
    
    func requestSpeechRecognitionPermission() async -> PermissionStatus {
        mockSpeechStatus = .authorized
        return mockSpeechStatus
    }
}

// MARK: - Service Container Mock

class MockServiceContainer: ServiceContainer {
    // Override any specific services needed for tests
}

// MARK: - Location Error Extension

enum LocationError: LocalizedError {
    case notAuthorized
    case locationUnavailable
    case geocodingFailed
    case incompleteAddress
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location services not authorized"
        case .locationUnavailable:
            return "Location unavailable"
        case .geocodingFailed:
            return "Geocoding failed"
        case .incompleteAddress:
            return "Incomplete address"
        }
    }
}

// MARK: - Weather Error Extension

enum WeatherError: LocalizedError {
    case serviceUnavailable
    case invalidLocation
    case sandboxRestriction
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Weather service unavailable"
        case .invalidLocation:
            return "Invalid location"
        case .sandboxRestriction:
            return "Weather service not available in simulator"
        }
    }
}
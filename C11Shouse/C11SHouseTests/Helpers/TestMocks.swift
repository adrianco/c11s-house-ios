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
import AVFoundation
import Speech
@testable import C11SHouse

// MARK: - Supporting Types

enum PermissionType {
    case microphone
    case speechRecognition
}

enum WeatherServiceError: Error {
    case networkError
    case dataUnavailable
}

// MARK: - Location Service Mocks

class MockLocationService: LocationServiceProtocol {
    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> {
        currentLocationSubject.eraseToAnyPublisher()
    }
    
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }
    
    var locationPublisher: AnyPublisher<CLLocation?, Never> {
        currentLocationSubject.eraseToAnyPublisher()
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
    
    func setVolume(_ volume: Float) {
        // No-op for tests
    }
    
    func setVoice(_ voiceIdentifier: String?) {
        // No-op for tests
    }
}

// MARK: - Notes Service Mocks

class SharedMockNotesService: NotesServiceProtocol {
    var notesStorePublisher: AnyPublisher<NotesStoreData, Never> {
        notesStoreSubject.eraseToAnyPublisher()
    }
    
    internal let notesStoreSubject = CurrentValueSubject<NotesStoreData, Never>(NotesStoreData(
        questions: Question.predefinedQuestions,
        notes: [:],
        version: 1
    ))
    
    var mockNotesStore: NotesStoreData
    var savedNotes: [Note] = []
    var loadNotesStoreCalled = false
    var saveHouseNameCalled = false
    var lastSavedHouseName: String?
    var mockHouseName: String?
    
    init() {
        self.mockNotesStore = NotesStoreData(
            questions: Question.predefinedQuestions,
            notes: [:],
            version: 1
        )
    }
    
    func loadNotesStore() async throws -> NotesStoreData {
        loadNotesStoreCalled = true
        return mockNotesStore
    }
    
    func saveNote(_ note: Note) async throws {
        savedNotes.append(note)
        mockNotesStore.notes[note.questionId] = note
        await MainActor.run {
            notesStoreSubject.send(mockNotesStore)
        }
    }
    
    func updateNote(_ note: Note) async throws {
        if let index = savedNotes.firstIndex(where: { $0.questionId == note.questionId }) {
            savedNotes[index] = note
        }
        mockNotesStore.notes[note.questionId] = note
        
        // Check if this is a house name question and update mockHouseName
        if let question = mockNotesStore.questions.first(where: { $0.id == note.questionId && $0.text == "What should I call this house?" }) {
            mockHouseName = note.answer
            print("[MockNotesService] Updated mockHouseName to: \(note.answer)")
        }
        
        await MainActor.run {
            notesStoreSubject.send(mockNotesStore)
        }
    }
    
    func deleteNote(for questionId: UUID) async throws {
        savedNotes.removeAll { $0.questionId == questionId }
        mockNotesStore.notes.removeValue(forKey: questionId)
        await MainActor.run {
            notesStoreSubject.send(mockNotesStore)
        }
    }
    
    func addQuestion(_ question: Question) async throws {
        mockNotesStore.questions.append(question)
        await MainActor.run {
            notesStoreSubject.send(mockNotesStore)
        }
    }
    
    func deleteQuestion(_ questionId: UUID) async throws {
        mockNotesStore.questions.removeAll { $0.id == questionId }
        mockNotesStore.notes.removeValue(forKey: questionId)
        await MainActor.run {
            notesStoreSubject.send(mockNotesStore)
        }
    }
    
    func resetToDefaults() async throws {
        mockNotesStore = NotesStoreData(
            questions: Question.predefinedQuestions,
            notes: [:],
            version: 1
        )
        await MainActor.run {
            notesStoreSubject.send(mockNotesStore)
        }
    }
    
    func clearAllData() async throws {
        mockNotesStore.notes.removeAll()
        await MainActor.run {
            notesStoreSubject.send(mockNotesStore)
        }
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
            metadata: metadata
        )
        try await saveNote(note)
    }
}

// MARK: - Weather Service Mocks

class MockWeatherKitService: WeatherServiceProtocol {
    var weatherUpdatePublisher: AnyPublisher<C11SHouse.Weather, Never> {
        weatherUpdateSubject.eraseToAnyPublisher()
    }
    
    private let weatherUpdateSubject = PassthroughSubject<C11SHouse.Weather, Never>()
    
    var fetchWeatherCalled = false
    var mockWeather: C11SHouse.Weather?
    var shouldThrowError = false
    var responseDelay: TimeInterval = 0
    
    func fetchWeather(for coordinate: Coordinate) async throws -> C11SHouse.Weather {
        fetchWeatherCalled = true
        
        // Simulate network delay if specified
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw WeatherServiceError.networkError
        }
        
        let weather = mockWeather ?? C11SHouse.Weather(
            temperature: C11SHouse.Temperature(value: 20, unit: .celsius),
            condition: .clear,
            humidity: 0.5,
            windSpeed: 10,
            feelsLike: C11SHouse.Temperature(value: 18, unit: .celsius),
            uvIndex: 5,
            pressure: 1013,
            visibility: 10000,
            dewPoint: 12,
            forecast: [],
            hourlyForecast: [],
            lastUpdated: Date()
        )
        
        weatherUpdateSubject.send(weather)
        return weather
    }
    
    func fetchWeatherForAddress(_ address: Address) async throws -> C11SHouse.Weather {
        return try await fetchWeather(for: address.coordinate ?? Coordinate(latitude: 0, longitude: 0))
    }
    
    // Additional method for compatibility with other tests
    func fetchWeather(latitude: Double, longitude: Double) async throws -> C11SHouse.Weather {
        let coordinate = Coordinate(latitude: latitude, longitude: longitude)
        return try await fetchWeather(for: coordinate)
    }
}

// MARK: - Conversation Recognizer Mock

// Remove duplicate protocol definition - use the one from main codebase

class MockConversationRecognizerService: NSObject {
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

class SharedMockAddressManager: AddressManager {
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

// MARK: - Permission Status

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

// MARK: - Permission Manager Mock

class MockPermissionManager: ObservableObject {
    @Published var microphonePermissionStatus: AVAudioSession.RecordPermission = .denied
    @Published var speechRecognitionPermissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var allPermissionsGranted: Bool = false
    @Published var permissionError: String?
    
    // Mock location status for tests
    var mockLocationStatus: CLAuthorizationStatus = .notDetermined
    
    // Aliases for test compatibility
    var mockMicrophoneStatus: AVAudioSession.RecordPermission {
        get { microphonePermissionStatus }
        set { microphonePermissionStatus = newValue }
    }
    
    var mockSpeechRecognitionStatus: SFSpeechRecognizerAuthorizationStatus {
        get { speechRecognitionPermissionStatus }
        set { speechRecognitionPermissionStatus = newValue }
    }
    
    func requestAllPermissions() async {
        microphonePermissionStatus = .granted
        speechRecognitionPermissionStatus = .authorized
        allPermissionsGranted = true
    }
    
    func requestMicrophonePermission() async {
        microphonePermissionStatus = .granted
        updateAllPermissionsStatus()
    }
    
    func requestSpeechRecognitionPermission() async {
        speechRecognitionPermissionStatus = .authorized
        updateAllPermissionsStatus()
    }
    
    func isPermissionGranted(_ permission: PermissionType) -> Bool {
        switch permission {
        case .microphone:
            return microphonePermissionStatus == .granted
        case .speechRecognition:
            return speechRecognitionPermissionStatus == .authorized
        }
    }
    
    func requestLocationPermission() async {
        mockLocationStatus = .authorizedWhenInUse
        updateAllPermissionsStatus()
    }
    
    func checkLocationPermission() -> CLAuthorizationStatus {
        return mockLocationStatus
    }
    
    // Computed properties for OnboardingPermissionsView
    var isMicrophoneGranted: Bool {
        microphonePermissionStatus == .granted
    }
    
    var isSpeechRecognitionGranted: Bool {
        speechRecognitionPermissionStatus == .authorized
    }
    
    var hasLocationPermission: Bool {
        mockLocationStatus == .authorizedWhenInUse || mockLocationStatus == .authorizedAlways
    }
    
    var microphoneAuthorizationStatus: PermissionStatus {
        switch microphonePermissionStatus {
        case .granted: return .granted
        case .denied: return .denied
        default: return .notDetermined
        }
    }
    
    var speechRecognitionAuthorizationStatus: PermissionStatus {
        switch speechRecognitionPermissionStatus {
        case .authorized: return .granted
        case .denied: return .denied
        default: return .notDetermined
        }
    }
    
    var locationAuthorizationStatus: PermissionStatus {
        switch mockLocationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }
    
    var microphoneStatusDescription: String {
        switch microphonePermissionStatus {
        case .granted:
            return "Microphone access granted"
        case .denied:
            return "Microphone access denied. Please enable in Settings."
        case .undetermined:
            return "Microphone permission not yet requested"
        @unknown default:
            return "Unknown microphone permission status"
        }
    }
    
    func openAppSettings() {
        // Mock implementation
    }
    
    private func updateAllPermissionsStatus() {
        allPermissionsGranted = microphonePermissionStatus == .granted && speechRecognitionPermissionStatus == .authorized
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
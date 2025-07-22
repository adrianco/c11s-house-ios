/*
 * CONTEXT & PURPOSE:
 * AddressManagerTests validates the AddressManager implementation which consolidates
 * all address-related logic including parsing, validation, house name generation,
 * and coordination with location services. Tests ensure proper address detection,
 * parsing, persistence, and error handling.
 *
 * DECISION HISTORY:
 * - 2025-01-10: Initial test implementation
 *   - Mock NotesService and LocationService for isolation
 *   - Test address detection with location permissions
 *   - Test address parsing with various formats
 *   - Test house name generation logic
 *   - Test persistence to multiple storage locations
 *   - Test error handling for permissions and failures
 *   - Async/await test patterns throughout
 *   - Integration with AddressParser utility
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import CoreLocation
import Combine
@testable import C11SHouse

// MARK: - Mock NotesService Extension for AddressManagerTests

extension SharedMockNotesService {
    // Helper methods for AddressManagerTests
    func getCurrentQuestion() async -> Question? {
        return mockNotesStore.questionsNeedingReview().first
    }
    
    func getNextUnansweredQuestion() async -> Question? {
        return mockNotesStore.questions.first { question in
            mockNotesStore.notes[question.id] == nil
        }
    }
    
    func getNote(for questionId: UUID) async throws -> Note? {
        return mockNotesStore.notes[questionId]
    }
    
    func getNote(forQuestionText questionText: String) async -> Note? {
        if let question = mockNotesStore.questions.first(where: { $0.text == questionText }) {
            return mockNotesStore.notes[question.id]
        }
        return nil
    }
    
    func getUnansweredQuestions() async throws -> [Question] {
        return mockNotesStore.questions.filter { question in
            mockNotesStore.notes[question.id] == nil
        }
    }
    
    func exportData() async throws -> Data {
        return try JSONEncoder().encode(mockNotesStore)
    }
    
    func importData(_ data: Data) async throws {
        mockNotesStore = try JSONDecoder().decode(NotesStoreData.self, from: data)
        notesStoreSubject.send(mockNotesStore)
    }
    
    func saveWeatherSummary(_ weather: Weather) async {
        // Not implemented for tests
    }
}

// MARK: - Test-specific MockNotesService

class MockNotesServiceWithTracking: SharedMockNotesService {
    var saveNoteCallCount = 0
    var saveOrUpdateNoteCallCount = 0
    var shouldThrowError = false
    var errorToThrow: Error?
    
    override func loadNotesStore() async throws -> NotesStoreData {
        print("[MockNotesServiceWithTracking] loadNotesStore called")
        if shouldThrowError {
            throw errorToThrow ?? NotesError.decodingFailed(NSError(domain: "test", code: 1))
        }
        let notesStore = try await super.loadNotesStore()
        print("[MockNotesServiceWithTracking] Returning notes store with \(notesStore.questions.count) questions")
        for question in notesStore.questions {
            print("[MockNotesServiceWithTracking] Question: \(question.text)")
        }
        return notesStore
    }
    
    override func saveNote(_ note: Note) async throws {
        print("[MockNotesServiceWithTracking] saveNote called with questionId: \(note.questionId), answer: \(note.answer)")
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        saveNoteCallCount += 1
        print("[MockNotesServiceWithTracking] Incremented saveNoteCallCount to: \(saveNoteCallCount)")
        try await super.saveNote(note)
    }
    
    override func updateNote(_ note: Note) async throws {
        print("[MockNotesServiceWithTracking] updateNote called with questionId: \(note.questionId), answer: \(note.answer)")
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        try await super.updateNote(note)
    }
    
    // Override the parent class implementation
    override func saveOrUpdateNote(for questionId: UUID, answer: String, metadata: [String: String]? = nil) async throws {
        print("[MockNotesServiceWithTracking] saveOrUpdateNote called with questionId: \(questionId), answer: \(answer)")
        saveOrUpdateNoteCallCount += 1
        print("[MockNotesServiceWithTracking] Incremented saveOrUpdateNoteCallCount to: \(saveOrUpdateNoteCallCount)")
        
        if shouldThrowError {
            throw errorToThrow ?? NSError(domain: "test", code: 1)
        }
        
        // Check if note exists to decide between save and update
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
            let note = Note(
                questionId: questionId,
                answer: answer,
                metadata: metadata
            )
            try await saveNote(note)
        }
    }
}

// MARK: - Mock Location Service

class MockLocationServiceForAddressManager: LocationServiceProtocol {
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse {
        didSet {
            authorizationStatusSubject.send(authorizationStatus)
        }
    }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }
    
    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> {
        CurrentValueSubject<CLLocation?, Never>(mockLocation).eraseToAnyPublisher()
    }
    
    var locationPublisher: AnyPublisher<CLLocation?, Never> {
        CurrentValueSubject<CLLocation?, Never>(mockLocation).eraseToAnyPublisher()
    }
    
    private let authorizationStatusSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.authorizedWhenInUse)
    
    var requestLocationPermissionCallCount = 0
    var getCurrentLocationCallCount = 0
    var lookupAddressCallCount = 0
    var confirmAddressCallCount = 0
    
    var shouldThrowLocationError = false
    var shouldThrowLookupError = false
    var mockLocation: CLLocation?
    var mockAddress: Address?
    
    init() {
        // Initialize with the default authorization status
        authorizationStatusSubject.send(authorizationStatus)
    }
    
    func requestLocationPermission() async {
        requestLocationPermissionCallCount += 1
        authorizationStatusSubject.send(authorizationStatus)
    }
    
    func requestLocationPermission() async -> CLAuthorizationStatus {
        requestLocationPermissionCallCount += 1
        authorizationStatusSubject.send(authorizationStatus)
        return authorizationStatus
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        getCurrentLocationCallCount += 1
        if shouldThrowLocationError {
            throw LocationError.notAuthorized
        }
        return mockLocation ?? CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    
    func lookupAddress(for location: CLLocation) async throws -> Address {
        lookupAddressCallCount += 1
        if shouldThrowLookupError {
            throw LocationError.geocodingFailed
        }
        return mockAddress ?? Address(
            street: "1 Market Street",
            city: "San Francisco",
            state: "CA",
            postalCode: "94105",
            country: "USA",
            coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        )
    }
    
    func confirmAddress(_ address: Address) async throws {
        confirmAddressCallCount += 1
    }
}

// MARK: - AddressManagerTests

class AddressManagerTests: XCTestCase {
    var sut: AddressManager!
    var mockNotesService: MockNotesServiceWithTracking!
    var mockLocationService: MockLocationServiceForAddressManager!
    
    override func setUp() {
        super.setUp()
        mockNotesService = MockNotesServiceWithTracking()
        mockLocationService = MockLocationServiceForAddressManager()
        
        // Clear any leftover UserDefaults data from old code
        UserDefaults.standard.removeObject(forKey: "confirmedHomeAddress")
        UserDefaults.standard.removeObject(forKey: "detectedHomeAddress")
        
        // Ensure MockNotesService has predefined questions
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: Question.predefinedQuestions,
            notes: [:],
            version: 1
        )
        
        // Explicitly reset error flags and call counts to ensure clean state
        mockNotesService.shouldThrowError = false
        mockNotesService.errorToThrow = nil
        mockNotesService.saveNoteCallCount = 0
        mockNotesService.saveOrUpdateNoteCallCount = 0
        
        sut = AddressManager(
            notesService: mockNotesService,
            locationService: mockLocationService
        )
    }
    
    override func tearDown() {
        // Clear UserDefaults to ensure clean state for next test
        UserDefaults.standard.removeObject(forKey: "confirmedHomeAddress")
        UserDefaults.standard.removeObject(forKey: "detectedHomeAddress")
        UserDefaults.standard.synchronize()
        
        sut = nil
        mockNotesService = nil
        mockLocationService = nil
        super.tearDown()
    }
    
    // MARK: - detectCurrentAddress Tests
    
    func testDetectCurrentAddressWithPermission() async throws {
        // Given: Location permission is granted
        mockLocationService.authorizationStatus = .authorizedWhenInUse
        let expectedLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        mockLocationService.mockLocation = expectedLocation
        mockLocationService.mockAddress = Address(
            street: "123 Broadway",
            city: "New York",
            state: "NY",
            postalCode: "10007",
            country: "USA",
            coordinate: Coordinate(latitude: expectedLocation.coordinate.latitude, longitude: expectedLocation.coordinate.longitude)
        )
        
        // When: Detecting current address
        let address = try await sut.detectCurrentAddress()
        
        // Then: Should successfully detect address
        XCTAssertEqual(address.street, "123 Broadway")
        XCTAssertEqual(address.city, "New York")
        XCTAssertEqual(address.state, "NY")
        XCTAssertEqual(address.postalCode, "10007")
        XCTAssertEqual(address.coordinate.latitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(address.coordinate.longitude, -74.0060, accuracy: 0.0001)
        
        // Verify service calls
        XCTAssertEqual(mockLocationService.getCurrentLocationCallCount, 1)
        XCTAssertEqual(mockLocationService.lookupAddressCallCount, 1)
        
        // Verify published property
        XCTAssertNotNil(sut.detectedAddress)
        XCTAssertEqual(sut.detectedAddress?.street, "123 Broadway")
        XCTAssertFalse(sut.isDetectingAddress)
    }
    
    func testDetectCurrentAddressWithoutPermission() async {
        // Given: Location permission is denied
        mockLocationService.authorizationStatus = .denied
        
        // When/Then: Should throw permission error
        do {
            _ = try await sut.detectCurrentAddress()
            XCTFail("Expected error to be thrown")
        } catch AddressError.locationPermissionDenied {
            // Success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
        
        // Wait for the flag to be reset asynchronously
        let expectation = XCTestExpectation(description: "isDetectingAddress should be false")
        let cancellable = sut.$isDetectingAddress.sink { isDetecting in
            if !isDetecting {
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        XCTAssertFalse(sut.isDetectingAddress)
    }
    
    func testDetectCurrentAddressWithNotDeterminedPermission() async {
        // Given: Location permission is not determined
        mockLocationService.authorizationStatus = .notDetermined
        
        // When/Then: Should throw permission error
        do {
            _ = try await sut.detectCurrentAddress()
            XCTFail("Expected error to be thrown")
        } catch AddressError.locationPermissionDenied {
            // Success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testDetectCurrentAddressHandlesLocationError() async throws {
        // Given: Location service will fail
        mockLocationService.authorizationStatus = .authorizedAlways
        mockLocationService.shouldThrowLocationError = true
        
        // When/Then: Should propagate error
        do {
            _ = try await sut.detectCurrentAddress()
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error propagated
        }
        
        // Wait for the flag to be reset asynchronously
        let expectation = XCTestExpectation(description: "isDetectingAddress should be false")
        let cancellable = sut.$isDetectingAddress.sink { isDetecting in
            if !isDetecting {
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        XCTAssertFalse(sut.isDetectingAddress)
    }
    
    func testDetectCurrentAddressHandlesGeocodeError() async throws {
        // Given: Geocoding will fail
        mockLocationService.authorizationStatus = .authorizedWhenInUse
        mockLocationService.shouldThrowLookupError = true
        
        // When/Then: Should propagate error
        do {
            _ = try await sut.detectCurrentAddress()
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error propagated
        }
        
        // Wait for the flag to be reset asynchronously
        let expectation = XCTestExpectation(description: "isDetectingAddress should be false")
        let cancellable = sut.$isDetectingAddress.sink { isDetecting in
            if !isDetecting {
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        XCTAssertFalse(sut.isDetectingAddress)
    }
    
    func testDetectCurrentAddressSetsIsDetectingFlag() async throws {
        // Given: Setup for successful detection
        mockLocationService.authorizationStatus = .authorizedWhenInUse
        
        // Create expectation for isDetecting changes
        let expectation = expectation(description: "isDetecting changes")
        expectation.expectedFulfillmentCount = 2 // true then false
        
        var detectionStates: [Bool] = []
        let cancellable = sut.$isDetectingAddress
            .dropFirst() // Skip initial value
            .sink { isDetecting in
                detectionStates.append(isDetecting)
                expectation.fulfill()
            }
        
        // When: Detecting address
        _ = try await sut.detectCurrentAddress()
        
        // Then: Should toggle isDetecting
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(detectionStates, [true, false])
        
        cancellable.cancel()
    }
    
    // MARK: - parseAddress Tests
    
    func testParseAddressWithDetectedCoordinates() {
        // Given: Previously detected address with coordinates
        sut.detectedAddress = Address(
            street: "456 Oak St",
            city: "Portland",
            state: "OR",
            postalCode: "97201",
            country: "USA",
            coordinate: Coordinate(latitude: 45.5152, longitude: -122.6784)
        )
        
        // When: Parsing new address text
        let parsed = sut.parseAddress("789 Pine Street, Seattle, WA 98101")
        
        // Then: Should parse with detected coordinates
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.street, "789 Pine Street")
        XCTAssertEqual(parsed?.city, "Seattle")
        XCTAssertEqual(parsed?.state, "WA")
        XCTAssertEqual(parsed?.postalCode, "98101")
        XCTAssertEqual(parsed?.coordinate.latitude ?? 0, 45.5152, accuracy: 0.0001)
        XCTAssertEqual(parsed?.coordinate.longitude ?? 0, -122.6784, accuracy: 0.0001)
    }
    
    func testParseAddressWithoutDetectedCoordinates() {
        // Given: No previously detected address
        sut.detectedAddress = nil
        
        // When: Parsing address text
        let parsed = sut.parseAddress("123 Main St, Springfield, IL 62701")
        
        // Then: Should parse without coordinates
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.street, "123 Main St")
        XCTAssertEqual(parsed?.city, "Springfield")
        XCTAssertEqual(parsed?.state, "IL")
        XCTAssertEqual(parsed?.postalCode, "62701")
        XCTAssertEqual(parsed?.coordinate.latitude, 0.0)
        XCTAssertEqual(parsed?.coordinate.longitude, 0.0)
    }
    
    func testParseAddressWithInvalidFormat() {
        // When: Parsing invalid address
        let parsed = sut.parseAddress("Invalid address format")
        
        // Then: Should return nil
        XCTAssertNil(parsed)
    }
    
    // MARK: - generateHouseName Tests
    
    func testGenerateHouseNameFromFullAddress() {
        // When: Generating house name from full address
        let houseName = sut.generateHouseName(from: "123 Maple Street, Springfield, IL 62701")
        
        // Then: Should extract street name
        XCTAssertEqual(houseName, "Maple House")
    }
    
    func testGenerateHouseNameFromStreetOnly() {
        // When: Generating house name from street
        let houseName = sut.generateHouseNameFromStreet("Oak Avenue")
        
        // Then: Should generate appropriate name
        XCTAssertEqual(houseName, "Oak House")
    }
    
    func testGenerateHouseNameHandlesVariousFormats() {
        // Test various street formats
        XCTAssertEqual(sut.generateHouseNameFromStreet("123 Main St"), "Main House")
        XCTAssertEqual(sut.generateHouseNameFromStreet("Elm Boulevard"), "Elm House")
        XCTAssertEqual(sut.generateHouseNameFromStreet("456 Park Lane"), "Park House")
        XCTAssertEqual(sut.generateHouseNameFromStreet("Cherry Tree Road"), "Cherry Tree House")
    }
    
    // MARK: - saveAddress Tests
    
    func testSaveAddressToAllStorageLocations() async throws {
        // Given: Address to save
        let address = Address(
            street: "789 Elm Street",
            city: "Chicago",
            state: "IL",
            postalCode: "60601",
            country: "USA",
            coordinate: Coordinate(latitude: 41.8781, longitude: -87.6298)
        )
        
        // When: Saving address
        try await sut.saveAddress(address)
        
        // Then: Should NOT save to UserDefaults (addresses only persisted via NotesService)
        let savedData = UserDefaults.standard.data(forKey: "confirmedHomeAddress")
        XCTAssertNil(savedData, "Address should not be saved to UserDefaults")
        
        // Then: Should save to LocationService
        XCTAssertEqual(mockLocationService.confirmAddressCallCount, 1)
        
        // Then: Should save to NotesService
        if let addressQuestion = mockNotesService.mockNotesStore.questions.first(where: {
            $0.text == "Is this the right address?" || $0.text == "What's your home address?"
        }),
           let note = mockNotesService.mockNotesStore.notes[addressQuestion.id] {
            XCTAssertEqual(note.answer, address.fullAddress)
            XCTAssertEqual(note.metadata?["updated_via_conversation"], "true")
            XCTAssertEqual(note.metadata?["latitude"], "41.8781")
            XCTAssertEqual(note.metadata?["longitude"], "-87.6298")
        } else {
            XCTFail("Address not saved to notes")
        }
    }
    
    func testSaveAddressGeneratesHouseNameIfNeeded() async throws {
        // Given: Address to save and no existing house name
        let address = Address(
            street: "999 Birch Lane",
            city: "Portland",
            state: "OR",
            postalCode: "97201",
            country: "USA",
            coordinate: Coordinate(latitude: 45.5152, longitude: -122.6784)
        )
        
        // When: Saving address
        try await sut.saveAddress(address)
        
        // Then: Should generate and save house name
        if let houseNameQuestion = mockNotesService.mockNotesStore.questions.first(where: {
            $0.text == "What should I call this house?"
        }),
           let note = mockNotesService.mockNotesStore.notes[houseNameQuestion.id] {
            XCTAssertEqual(note.answer, "Birch House")
            XCTAssertEqual(note.metadata?["generated_from_address"], "true")
        } else {
            XCTFail("House name not generated")
        }
    }
    
    func testSaveAddressDoesNotOverwriteExistingHouseName() async throws {
        // Given: Existing house name
        if let houseNameQuestion = mockNotesService.mockNotesStore.questions.first(where: {
            $0.text == "What should I call this house?"
        }) {
            mockNotesService.mockNotesStore.notes[houseNameQuestion.id] = Note(
                questionId: houseNameQuestion.id,
                answer: "My Custom House Name"
            )
        }
        
        let address = Address(
            street: "111 Cedar Ave",
            city: "Seattle",
            state: "WA",
            postalCode: "98101",
            country: "USA",
            coordinate: Coordinate(latitude: 47.6062, longitude: -122.3321)
        )
        
        // When: Saving address
        try await sut.saveAddress(address)
        
        // Then: Should not overwrite existing house name
        if let houseNameQuestion = mockNotesService.mockNotesStore.questions.first(where: {
            $0.text == "What should I call this house?"
        }),
           let note = mockNotesService.mockNotesStore.notes[houseNameQuestion.id] {
            XCTAssertEqual(note.answer, "My Custom House Name")
        }
    }
    
    // MARK: - loadSavedAddress Tests
    
    func testLoadSavedAddressWhenExists() async {
        // Given: Address saved in NotesService
        let addressQuestion = Question(
            text: "Is this the right address?",
            category: .houseInfo,
            displayOrder: 0,
            isRequired: true
        )
        var notesStore = mockNotesService.mockNotesStore
        notesStore.questions = [addressQuestion]
        notesStore.notes[addressQuestion.id] = Note(
            questionId: addressQuestion.id,
            answer: "321 Saved Street, Boston, MA 02101",
            createdAt: Date(),
            lastModified: Date()
        )
        mockNotesService.mockNotesStore = notesStore
        
        // When: Loading saved address
        let loaded = await sut.loadSavedAddress()
        
        // Then: Should load correctly
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.street, "321 Saved Street")
        XCTAssertEqual(loaded?.city, "Boston")
    }
    
    func testLoadSavedAddressWhenNotExists() async {
        // Given: No saved address in NotesService
        // mockNotesService.mockNotesStore already has empty notes
        
        // When: Loading saved address
        let loaded = await sut.loadSavedAddress()
        
        // Then: Should return nil
        XCTAssertNil(loaded)
    }
    
    func testLoadSavedAddressWithCorruptData() async {
        // Given: Invalid address answer in NotesService
        let addressQuestion = Question(
            text: "Is this the right address?",
            category: .houseInfo,
            displayOrder: 0,
            isRequired: true
        )
        var notesStore = mockNotesService.mockNotesStore
        notesStore.questions = [addressQuestion]
        notesStore.notes[addressQuestion.id] = Note(
            questionId: addressQuestion.id,
            answer: "invalid address data",
            createdAt: Date(),
            lastModified: Date()
        )
        mockNotesService.mockNotesStore = notesStore
        
        // When: Loading saved address
        let loaded = await sut.loadSavedAddress()
        
        // Then: Should return nil (unparseable address)
        XCTAssertNil(loaded)
    }
    
    // MARK: - saveAddressToNotes Tests
    
    func testSaveAddressToNotesBasicFunctionality() async throws {
        // Given: A valid address
        let address = Address(
            street: "123 Test Street",
            city: "Test City",
            state: "TC",
            postalCode: "12345",
            country: "USA",
            coordinate: Coordinate(latitude: 40.7128, longitude: -74.0060)
        )
        
        // When: Saving address to notes
        await sut.saveAddressToNotes(address)
        
        // Then: Should call saveNote for both address and house name
        print("Debug test: saveNoteCallCount = \(mockNotesService.saveNoteCallCount)")
        print("Debug test: mockNotesService instance = \(ObjectIdentifier(mockNotesService))")
        
        // Check that notes were actually saved
        let notesStore = try await mockNotesService.loadNotesStore()
        print("Debug test: notes count = \(notesStore.notes.count)")
        
        // Expected: 2 calls (address + house name)
        // Since saveOrUpdateNote is a protocol extension, it calls saveNote internally
        XCTAssertEqual(mockNotesService.saveNoteCallCount, 2, "Expected 2 calls to saveNote")
    }
    
    func testSaveAddressToNotesHandlesError() async {
        // Given: NotesService will fail
        mockNotesService.shouldThrowError = true
        let address = Address(
            street: "Error Street",
            city: "Error City",
            state: "ER",
            postalCode: "00000",
            country: "USA",
            coordinate: Coordinate(latitude: 0, longitude: 0)
        )
        
        // When: Saving address to notes
        await sut.saveAddressToNotes(address)
        
        // Then: Should handle gracefully (no crash)
        // Error is printed but not thrown
    }
    
    // MARK: - Error Type Tests
    
    func testAddressErrorDescriptions() {
        XCTAssertEqual(
            AddressError.locationPermissionDenied.errorDescription,
            "Location permission is required to detect your address"
        )
        
        XCTAssertEqual(
            AddressError.invalidAddressFormat.errorDescription,
            "Invalid address format"
        )
        
        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        XCTAssertEqual(
            AddressError.saveFailed(testError).errorDescription,
            "Failed to save address: Test error"
        )
    }
    
    // MARK: - Integration Tests
    
    func testFullAddressFlowIntegration() async throws {
        // Test complete address detection and save flow
        
        // 1. Setup location service with realistic data
        mockLocationService.authorizationStatus = .authorizedWhenInUse
        let location = CLLocation(latitude: 34.0522, longitude: -118.2437)
        mockLocationService.mockLocation = location
        mockLocationService.mockAddress = Address(
            street: "100 Universal City Plaza",
            city: "Los Angeles",
            state: "CA",
            postalCode: "91608",
            country: "USA",
            coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        )
        
        // 2. Detect current address
        let detectedAddress = try await sut.detectCurrentAddress()
        XCTAssertEqual(detectedAddress.street, "100 Universal City Plaza")
        XCTAssertNotNil(sut.detectedAddress)
        
        // 3. Parse user input (maybe they corrected it)
        let userInput = "100 Universal City Plaza, Universal City, CA 91608"
        let parsedAddress = sut.parseAddress(userInput)
        XCTAssertNotNil(parsedAddress)
        XCTAssertEqual(parsedAddress?.city, "Universal City") // User corrected city
        
        // 4. Generate house name
        let houseName = sut.generateHouseName(from: userInput)
        XCTAssertEqual(houseName, "Universal City House")
        
        // 5. Save the address
        print("Debug: saveNoteCallCount before saveAddress = \(mockNotesService.saveNoteCallCount)")
        try await sut.saveAddress(parsedAddress!)
        print("Debug: saveNoteCallCount after saveAddress = \(mockNotesService.saveNoteCallCount)")
        
        // 6. Verify storage locations updated (NOT UserDefaults)
        XCTAssertNil(UserDefaults.standard.data(forKey: "confirmedHomeAddress"), "Should not save to UserDefaults")
        XCTAssertEqual(mockLocationService.confirmAddressCallCount, 1)
        
        // Check if the questions exist in the mock service
        let notesStore = try await mockNotesService.loadNotesStore()
        let addressQuestion = notesStore.questions.first(where: { 
            $0.text == "Is this the right address?" || $0.text == "What's your home address?" 
        })
        let houseNameQuestion = notesStore.questions.first(where: { 
            $0.text == "What should I call this house?" 
        })
        
        XCTAssertNotNil(addressQuestion, "Address question should exist")
        XCTAssertNotNil(houseNameQuestion, "House name question should exist")
        
        // Debug: Print the state of the mock service
        print("Debug: saveNoteCallCount = \(mockNotesService.saveNoteCallCount)")
        print("Debug: saveOrUpdateNoteCallCount = \(mockNotesService.saveOrUpdateNoteCallCount)")
        print("Debug: shouldThrowError = \(mockNotesService.shouldThrowError)")
        print("Debug: questions count = \(notesStore.questions.count)")
        print("Debug: notes count = \(notesStore.notes.count)")
        
        // We expect 2 calls: one for address, one for house name (if house name not already answered)
        // Since saveOrUpdateNote is a protocol extension method, it calls saveNote internally
        // So we need to check saveNoteCallCount instead
        XCTAssertEqual(mockNotesService.saveNoteCallCount, 2, "Expected 2 calls to saveNote (address + house name)")
        
        // 7. Load saved address
        let loadedAddress = await sut.loadSavedAddress()
        XCTAssertNotNil(loadedAddress)
        XCTAssertEqual(loadedAddress?.street, "100 Universal City Plaza")
    }
}
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
    var mockNotesService: MockNotesService!
    var mockLocationService: MockLocationServiceForAddressManager!
    
    override func setUp() {
        super.setUp()
        mockNotesService = MockNotesService()
        mockLocationService = MockLocationServiceForAddressManager()
        sut = AddressManager(
            notesService: mockNotesService,
            locationService: mockLocationService
        )
    }
    
    override func tearDown() {
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "confirmedHomeAddress")
        
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
        try await Task.sleep(nanoseconds: 1000000) // 1ms
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
        try await Task.sleep(nanoseconds: 1000000) // 1ms
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
        try await Task.sleep(nanoseconds: 1000000) // 1ms
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
        
        // Then: Should save to UserDefaults
        let savedData = UserDefaults.standard.data(forKey: "confirmedHomeAddress")
        XCTAssertNotNil(savedData)
        let decodedAddress = try JSONDecoder().decode(Address.self, from: savedData!)
        XCTAssertEqual(decodedAddress.street, "789 Elm Street")
        
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
    
    func testLoadSavedAddressWhenExists() {
        // Given: Saved address in UserDefaults
        let savedAddress = Address(
            street: "321 Saved Street",
            city: "Boston",
            state: "MA",
            postalCode: "02101",
            country: "USA",
            coordinate: Coordinate(latitude: 42.3601, longitude: -71.0589)
        )
        let encodedData = try! JSONEncoder().encode(savedAddress)
        UserDefaults.standard.set(encodedData, forKey: "confirmedHomeAddress")
        
        // When: Loading saved address
        let loaded = sut.loadSavedAddress()
        
        // Then: Should load correctly
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.street, "321 Saved Street")
        XCTAssertEqual(loaded?.city, "Boston")
        XCTAssertEqual(loaded?.coordinate.latitude ?? 0, 42.3601, accuracy: 0.0001)
    }
    
    func testLoadSavedAddressWhenNotExists() {
        // Given: No saved address
        UserDefaults.standard.removeObject(forKey: "confirmedHomeAddress")
        
        // When: Loading saved address
        let loaded = sut.loadSavedAddress()
        
        // Then: Should return nil
        XCTAssertNil(loaded)
    }
    
    func testLoadSavedAddressWithCorruptData() {
        // Given: Corrupt data in UserDefaults
        UserDefaults.standard.set("corrupt data", forKey: "confirmedHomeAddress")
        
        // When: Loading saved address
        let loaded = sut.loadSavedAddress()
        
        // Then: Should return nil
        XCTAssertNil(loaded)
    }
    
    // MARK: - saveAddressToNotes Tests
    
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
        try await sut.saveAddress(parsedAddress!)
        
        // 6. Verify all storage locations updated
        XCTAssertNotNil(UserDefaults.standard.data(forKey: "confirmedHomeAddress"))
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
        
        // We expect 2 calls: one for address, one for house name (if house name not already answered)
        // But since the house name question starts with no answer, it should be saved
        XCTAssertEqual(mockNotesService.saveOrUpdateNoteCallCount, 2) // Address + house name
        
        // 7. Load saved address
        let loadedAddress = sut.loadSavedAddress()
        XCTAssertNotNil(loadedAddress)
        XCTAssertEqual(loadedAddress?.street, "100 Universal City Plaza")
    }
}
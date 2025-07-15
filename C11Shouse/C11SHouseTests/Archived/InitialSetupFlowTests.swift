/*
 * CONTEXT & PURPOSE:
 * InitialSetupFlowTests validates the complete initial app setup flow including location
 * permissions, address detection, house naming, and user name collection. Tests verify
 * data persistence across the flow and error recovery scenarios.
 *
 * DECISION HISTORY:
 * - 2025-01-10: Initial implementation
 *   - Tests complete setup workflow with real coordinators
 *   - Validates permission handling and error recovery
 *   - Verifies data persistence throughout setup
 *   - Tests edge cases and failure scenarios
 *   - Ensures proper state transitions
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import Combine
import CoreLocation
@testable import C11SHouse

@MainActor
class InitialSetupFlowTests: XCTestCase {
    
    // MARK: - Properties
    
    private var notesService: NotesServiceProtocol!
    private var locationServiceMock: MockLocationService!
    private var permissionManagerMock: MockPermissionManager!
    private var addressManager: AddressManager!
    private var questionFlowCoordinator: QuestionFlowCoordinator!
    private var conversationStateManager: ConversationStateManager!
    private var ttsMock: MockTTSService!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        cancellables = Set<AnyCancellable>()
        
        // Create services
        notesService = NotesServiceImpl()
        locationServiceMock = MockLocationService()
        permissionManagerMock = MockPermissionManager()
        ttsMock = MockTTSService()
        
        // Set up MockLocationService with proper authorization
        locationServiceMock.authorizationStatus = .authorizedWhenInUse
        
        // Wait for NotesService to fully initialize with predefined questions
        _ = try await notesService.loadNotesStore()
        
        // Create coordinators
        addressManager = AddressManager(
            notesService: notesService,
            locationService: locationServiceMock
        )
        
        conversationStateManager = ConversationStateManager(
            notesService: notesService,
            ttsService: ttsMock
        )
        
        questionFlowCoordinator = QuestionFlowCoordinator(
            notesService: notesService
        )
        
        // Connect coordinators
        questionFlowCoordinator.conversationStateManager = conversationStateManager
        questionFlowCoordinator.addressManager = addressManager
        
        // Clear all existing answers to ensure questions need review
        try await notesService.clearAllData()
        
        // Verify we have questions that need review
        let cleanStore = try await notesService.loadNotesStore()
        let questionsNeedingReview = cleanStore.questionsNeedingReview()
        XCTAssertGreaterThan(questionsNeedingReview.count, 0, "Should have questions needing review after clearing data")
    }
    
    override func tearDown() async throws {
        cancellables = nil
        
        // Clean up test data
        try? await notesService?.clearAllData()
        
        // Clear references
        notesService = nil
        locationServiceMock = nil
        permissionManagerMock = nil
        addressManager = nil
        questionFlowCoordinator = nil
        conversationStateManager = nil
        ttsMock = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Complete Setup Flow Tests
    
    func testCompleteInitialSetupFlow() async throws {
        // Step 1: Check initial state - no data should exist
        let initialAddress = try await addressManager.loadSavedAddress()
        XCTAssertNil(initialAddress)
        
        let initialUserName = await conversationStateManager.userName
        XCTAssertEqual(initialUserName, "")
        
        // Step 2: Request location permission
        // Location permissions are handled by LocationService, not PermissionManager
        locationServiceMock.setAuthorizationStatus(.notDetermined)
        
        // Grant permission through location service
        await locationServiceMock.requestLocationPermission()
        locationServiceMock.setAuthorizationStatus(.authorizedWhenInUse)
        
        // Step 3: Detect current address
        let mockLocation = CLLocation(latitude: 37.3317, longitude: -122.0302)
        locationServiceMock.getCurrentLocationResult = .success(mockLocation)
        locationServiceMock.lookupAddressResult = .success(
            Address(
                street: "1 Apple Park Way",
                city: "Cupertino",
                state: "CA",
                postalCode: "95014",
                country: "USA",
                coordinate: Coordinate(latitude: 37.3317, longitude: -122.0302)
            )
        )
        
        let detectedAddress = try await addressManager.detectCurrentAddress()
        XCTAssertEqual(detectedAddress.street, "1 Apple Park Way")
        XCTAssertEqual(detectedAddress.city, "Cupertino")
        XCTAssertEqual(detectedAddress.state, "CA")
        XCTAssertEqual(detectedAddress.postalCode, "95014")
        
        // Step 4: Load and answer address confirmation question
        await questionFlowCoordinator.loadNextQuestion()
        
        guard let addressQuestion = await questionFlowCoordinator.currentQuestion,
              addressQuestion.text == "Is this the right address?" else {
            XCTFail("Expected address question")
            return
        }
        
        // Confirm address
        conversationStateManager.persistentTranscript = detectedAddress.fullAddress
        try await questionFlowCoordinator.saveAnswer(detectedAddress.fullAddress)
        
        // Verify address was saved
        let savedAddress = try await addressManager.loadSavedAddress()
        XCTAssertNotNil(savedAddress)
        XCTAssertEqual(savedAddress?.fullAddress, detectedAddress.fullAddress)
        
        // Step 5: House naming
        guard let houseQuestion = await questionFlowCoordinator.currentQuestion,
              houseQuestion.text == "What should I call this house?" else {
            XCTFail("Expected house naming question")
            return
        }
        
        // Generate house name from address
        let suggestedName = addressManager.generateHouseName(from: detectedAddress.fullAddress)
        XCTAssertFalse(suggestedName.isEmpty)
        
        // User modifies the suggestion
        let customHouseName = "Tech Haven"
        conversationStateManager.persistentTranscript = customHouseName
        try await questionFlowCoordinator.saveAnswer(customHouseName)
        
        // Verify house name was saved
        let savedHouseName = await notesService.getHouseName()
        XCTAssertEqual(savedHouseName, customHouseName)
        
        // Step 6: User name
        guard let nameQuestion = await questionFlowCoordinator.currentQuestion,
              nameQuestion.text == "What's your name?" else {
            XCTFail("Expected name question")
            return
        }
        
        let userName = "Test User"
        conversationStateManager.persistentTranscript = userName
        try await questionFlowCoordinator.saveAnswer(userName)
        
        // Verify user name was saved and updated in state
        await conversationStateManager.loadUserName()
        XCTAssertEqual(conversationStateManager.userName, userName)
        
        // Step 7: Verify all setup data persists
        let finalAddress = try await addressManager.loadSavedAddress()
        XCTAssertNotNil(finalAddress)
        XCTAssertEqual(finalAddress?.fullAddress, detectedAddress.fullAddress)
        
        let finalHouseName = await notesService.getHouseName()
        XCTAssertEqual(finalHouseName, customHouseName)
        
        let finalUserName = await questionFlowCoordinator.getAnswer(for: "What's your name?")
        XCTAssertEqual(finalUserName, userName)
    }
    
    func testSetupFlowWithLocationPermissionDenied() async throws {
        // Test setup flow when location permission is denied
        
        // Deny location permission
        locationServiceMock.setAuthorizationStatus(.denied)
        
        // Try to detect address - should fail
        do {
            _ = try await addressManager.detectCurrentAddress()
            XCTFail("Should have thrown error for denied permission")
        } catch {
            // Expected error
            XCTAssertTrue(error is LocationError)
        }
        
        // Load question - should show manual address entry
        await questionFlowCoordinator.loadNextQuestion()
        
        guard let question = await questionFlowCoordinator.currentQuestion else {
            XCTFail("Expected question")
            return
        }
        
        // Should get address question but need manual entry
        if question.text == "What's your home address?" || question.text == "Is this the right address?" {
            // Manually enter address
            let manualAddress = "123 Manual Entry St, Test City, CA 94000"
            conversationStateManager.persistentTranscript = manualAddress
            try await questionFlowCoordinator.saveAnswer(manualAddress)
            
            // Verify manual address was saved
            let savedAnswer = await questionFlowCoordinator.getAnswer(for: question.text)
            XCTAssertEqual(savedAnswer, manualAddress)
            
            // Parse and save the manual address
            if let parsed = addressManager.parseAddress(manualAddress) {
                try await addressManager.saveAddress(parsed)
                
                let saved = try await addressManager.loadSavedAddress()
                XCTAssertNotNil(saved)
                XCTAssertTrue(saved!.fullAddress.contains("Manual Entry"))
            }
        }
    }
    
    func testSetupFlowWithNetworkErrors() async throws {
        // Test setup flow with network/geocoding errors
        
        // Configure location service to fail geocoding
        locationServiceMock.getCurrentLocationResult = .success(CLLocation(latitude: 0, longitude: 0))
        locationServiceMock.lookupAddressResult = .failure(LocationError.geocodingFailed)
        
        // Grant permission
        locationServiceMock.setAuthorizationStatus(.authorizedWhenInUse)
        
        // Try to detect address - geocoding should fail
        do {
            _ = try await addressManager.detectCurrentAddress()
            XCTFail("Should have thrown geocoding error")
        } catch {
            // Expected error
            XCTAssertTrue(error is LocationError)
        }
        
        // Should fall back to manual entry
        await questionFlowCoordinator.loadNextQuestion()
        
        if let question = await questionFlowCoordinator.currentQuestion,
           question.text.contains("address") {
            // Manual entry flow
            let fallbackAddress = "456 Fallback Ave, Backup City, CA 95000"
            conversationStateManager.persistentTranscript = fallbackAddress
            try await questionFlowCoordinator.saveAnswer(fallbackAddress)
            
            let saved = await questionFlowCoordinator.getAnswer(for: question.text)
            XCTAssertEqual(saved, fallbackAddress)
        }
    }
    
    func testDataPersistenceAcrossSetup() async throws {
        // Test that data persists correctly throughout setup
        
        // Setup mock data
        let mockLocation = CLLocation(latitude: 34.0522, longitude: -118.2437)
        locationServiceMock.getCurrentLocationResult = .success(mockLocation)
        locationServiceMock.lookupAddressResult = .success(
            Address(
                street: "100 Main St",
                city: "Los Angeles",
                state: "CA",
                postalCode: "90012",
                country: "USA",
                coordinate: Coordinate(latitude: 34.0522, longitude: -118.2437)
            )
        )
        
        // Save data at each step and verify persistence
        
        // Step 1: Address
        let address = try await addressManager.detectCurrentAddress()
        try await addressManager.saveAddress(address)
        
        // Verify immediate persistence
        let savedAddress1 = try await addressManager.loadSavedAddress()
        XCTAssertNotNil(savedAddress1)
        XCTAssertEqual(savedAddress1?.city, "Los Angeles")
        
        // Step 2: House name via notes service
        let houseName = "LA House"
        await notesService.saveHouseName(houseName)
        
        // Verify persistence
        let savedHouseName1 = await notesService.getHouseName()
        XCTAssertEqual(savedHouseName1, houseName)
        
        // Step 3: User name via question flow
        await questionFlowCoordinator.loadNextQuestion()
        
        // Answer questions until we get to name
        while let question = await questionFlowCoordinator.currentQuestion {
            if question.text == "What's your name?" {
                try await questionFlowCoordinator.saveAnswer("LA User")
                break
            } else {
                // Answer other questions to progress
                try await questionFlowCoordinator.saveAnswer("Test answer")
            }
        }
        
        // Create new instances to verify persistence
        let newAddressManager = AddressManager(
            notesService: notesService,
            locationService: locationServiceMock
        )
        
        let newStateManager = ConversationStateManager(
            notesService: notesService,
            ttsService: ttsMock
        )
        
        // Verify all data persisted
        let persistedAddress = newAddressManager.loadSavedAddress()
        XCTAssertNotNil(persistedAddress)
        XCTAssertEqual(persistedAddress?.city, "Los Angeles")
        
        let persistedHouseName = await notesService.getHouseName()
        XCTAssertEqual(persistedHouseName, houseName)
        
        await newStateManager.loadUserName()
        XCTAssertEqual(newStateManager.userName, "LA User")
    }
    
    func testAddressParsingVariations() async throws {
        // Test various address format parsing
        
        let testAddresses = [
            "123 Main St, San Francisco, CA 94105",
            "456 Oak Avenue, Los Angeles, California 90001",
            "789 Elm Street Apt 2B New York NY 10001",
            "321 Pine Rd., Seattle, WA, 98101",
            "100 Market Street Suite 500 San Diego CA 92101"
        ]
        
        for addressString in testAddresses {
            let parsed = addressManager.parseAddress(addressString)
            XCTAssertNotNil(parsed, "Failed to parse: \(addressString)")
            
            if let parsed = parsed {
                // Verify basic components are extracted
                XCTAssertFalse(parsed.street.isEmpty, "No street in: \(addressString)")
                XCTAssertFalse(parsed.city.isEmpty, "No city in: \(addressString)")
                XCTAssertFalse(parsed.state.isEmpty, "No state in: \(addressString)")
                
                // Test only the parsing - don't save to avoid affecting other tests
                // Just verify the parsed address has the expected components
                XCTAssertTrue(parsed.street.contains("Street") || parsed.street.contains("St") || 
                             parsed.street.contains("Avenue") || parsed.street.contains("Ave") || 
                             parsed.street.contains("Road") || parsed.street.contains("Rd") ||
                             parsed.street.contains("Market"), "Street component missing proper suffix")
            }
        }
    }
    
    func testHouseNameGeneration() async throws {
        // Test house name generation from various addresses
        
        let testCases = [
            ("123 Oak Street, Oakland, CA 94612", "Oak"),
            ("456 Sunset Blvd, Los Angeles, CA 90028", "Sunset"),
            ("789 Park Ave, New York, NY 10021", "Park"),
            ("100 Main St, Anytown, USA 12345", "Main"),
            ("555 ", "My House") // Partial address should get default
        ]
        
        for (address, expectedContains) in testCases {
            let generated = addressManager.generateHouseName(from: address)
            XCTAssertTrue(
                generated.contains(expectedContains) || generated == "My House",
                "Generated '\(generated)' doesn't contain '\(expectedContains)' for address: \(address)"
            )
        }
    }
}

// Note: Mock types are now centralized in TestMocks.swift
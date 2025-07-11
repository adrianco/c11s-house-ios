/*
 * CONTEXT & PURPOSE:
 * Tests for AddressSuggestionService to verify address detection, house name generation,
 * and weather integration functionality.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Initial implementation
 *   - Tests address detection and suggestion
 *   - Tests house name generation from various street types
 *   - Tests weather fetch trigger after address confirmation
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import CoreLocation
import Combine
@testable import C11SHouse

@MainActor
class AddressSuggestionServiceTests: XCTestCase {
    
    var sut: AddressSuggestionService!
    var mockAddressManager: MockAddressManagerForSuggestion!
    var mockLocationService: MockLocationService!
    var mockWeatherCoordinator: MockWeatherCoordinator!
    
    override func setUp() async throws {
        try await super.setUp()
        mockAddressManager = MockAddressManagerForSuggestion()
        mockLocationService = MockLocationService()
        mockWeatherCoordinator = MockWeatherCoordinator()
        
        sut = AddressSuggestionService(
            addressManager: mockAddressManager,
            locationService: mockLocationService,
            weatherCoordinator: mockWeatherCoordinator
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        mockAddressManager = nil
        mockLocationService = nil
        mockWeatherCoordinator = nil
        try await super.tearDown()
    }
    
    // MARK: - Address Suggestion Tests
    
    func testSuggestCurrentAddress_Success() async throws {
        // Given
        let expectedAddress = Address(
            street: "123 Main Street",
            city: "San Francisco",
            state: "CA",
            postalCode: "94105",
            country: "United States",
            coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194)
        )
        mockAddressManager.mockDetectedAddress = expectedAddress
        
        // When
        let suggestedAddress = try await sut.suggestCurrentAddress()
        
        // Then
        XCTAssertEqual(suggestedAddress, expectedAddress.fullAddress)
        XCTAssertTrue(mockAddressManager.detectCurrentAddressCalled)
    }
    
    // MARK: - House Name Generation Tests
    
    func testGenerateHouseNameSuggestions_StreetType() {
        // Test various street types
        let testCases = [
            ("123 Oak Street", ["Oak House", "Casa Oak", "Oak Home"]),
            ("456 Elm Avenue", ["Elm Manor", "Elm Estate", "Elm Home"]),
            ("789 Pine Road", ["Pine Lodge", "Pine Den", "Pine Home"]),
            ("321 Maple Lane", ["Maple Cottage", "Casa Maple", "Maple Home"]),
            ("654 Cedar Drive", ["Cedar Villa", "Casa Cedar", "Cedar Home"]),
            ("987 Birch Court", ["Birch Haven", "Casa Birch", "Birch Home"])
        ]
        
        for (address, expectedSuggestions) in testCases {
            let suggestions = sut.generateHouseNameSuggestions(from: address)
            
            // Should contain at least one expected suggestion
            let containsExpected = expectedSuggestions.contains { expected in
                suggestions.contains(expected)
            }
            XCTAssertTrue(containsExpected, "Expected one of \(expectedSuggestions) in \(suggestions) for address: \(address)")
        }
    }
    
    func testGenerateHouseNameSuggestions_NoStreetType() {
        // Given an address without a recognized street type
        let address = "123 Main"
        
        // When
        let suggestions = sut.generateHouseNameSuggestions(from: address)
        
        // Then
        XCTAssertTrue(suggestions.contains("Main House") || suggestions.contains("Casa Main"))
        XCTAssertTrue(suggestions.count >= 2)
    }
    
    // MARK: - Weather Integration Tests
    
    func testFetchWeatherForConfirmedAddress() async {
        // Given
        let address = Address(
            street: "123 Main Street",
            city: "San Francisco",
            state: "CA",
            postalCode: "94105",
            country: "United States",
            coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194)
        )
        
        // When
        await sut.fetchWeatherForConfirmedAddress(address)
        
        // Then
        XCTAssertTrue(mockWeatherCoordinator.fetchWeatherCalled)
        XCTAssertEqual(mockWeatherCoordinator.lastFetchedAddress?.fullAddress, address.fullAddress)
    }
    
    // MARK: - House Thought Generation Tests
    
    func testCreateAddressConfirmationResponse() {
        // Given
        let detectedAddress = "123 Main Street, San Francisco, CA 94105"
        
        // When
        let thought = sut.createAddressConfirmationResponse(detectedAddress)
        
        // Then
        XCTAssertEqual(thought.thought, "I've detected your location. Is this the right address?\n\n\(detectedAddress)")
        XCTAssertEqual(thought.emotion, .curious)
        XCTAssertEqual(thought.category, .question)
        XCTAssertEqual(thought.confidence, 0.9)
        XCTAssertEqual(thought.context, "Address Detection")
        XCTAssertNil(thought.suggestion)
    }
}

// MARK: - Mock Classes

class MockAddressManagerForSuggestion: AddressManager {
    var mockDetectedAddress: Address?
    var detectCurrentAddressCalled = false
    
    init() {
        let mockNotesService = SharedMockNotesService()
        let mockLocationService = MockLocationService()
        super.init(
            notesService: mockNotesService,
            locationService: mockLocationService
        )
    }
    
    override func detectCurrentAddress() async throws -> Address {
        detectCurrentAddressCalled = true
        guard let address = mockDetectedAddress else {
            throw AddressError.invalidAddressFormat
        }
        return address
    }
}

@MainActor
class MockWeatherCoordinator: WeatherCoordinator {
    var fetchWeatherCalled = false
    var lastFetchedAddress: Address?
    
    init() {
        let mockWeatherService = MockWeatherKitService()
        let mockNotesService = SharedMockNotesService()
        let mockLocationService = MockLocationService()
        super.init(
            weatherService: mockWeatherService,
            notesService: mockNotesService,
            locationService: mockLocationService
        )
    }
    
    override func fetchWeather(for address: Address) async throws -> Weather {
        fetchWeatherCalled = true
        lastFetchedAddress = address
        
        return Weather(
            temperature: Temperature(value: 72, unit: .fahrenheit),
            condition: .clear,
            humidity: 0.65,
            windSpeed: 10,
            feelsLike: Temperature(value: 70, unit: .fahrenheit),
            uvIndex: 5,
            pressure: 1013,
            visibility: 10000,
            dewPoint: 15,
            forecast: [],
            hourlyForecast: [],
            lastUpdated: Date()
        )
    }
}
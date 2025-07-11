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
@testable import C11SHouse

class AddressSuggestionServiceTests: XCTestCase {
    
    var sut: AddressSuggestionService!
    var mockAddressManager: MockAddressManager!
    var mockLocationService: MockLocationService!
    var mockWeatherCoordinator: MockWeatherCoordinator!
    
    override func setUp() {
        super.setUp()
        mockAddressManager = MockAddressManager()
        mockLocationService = MockLocationService()
        mockWeatherCoordinator = MockWeatherCoordinator()
        
        sut = AddressSuggestionService(
            addressManager: mockAddressManager,
            locationService: mockLocationService,
            weatherCoordinator: mockWeatherCoordinator
        )
    }
    
    override func tearDown() {
        sut = nil
        mockAddressManager = nil
        mockLocationService = nil
        mockWeatherCoordinator = nil
        super.tearDown()
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
            ("123 Oak Street", ["Oak House", "Casa Oak"]),
            ("456 Maple Avenue", ["Maple Manor", "Maple Estate"]),
            ("789 Pine Road", ["Pine Lodge", "Pine Den"]),
            ("321 Elm Lane", ["Elm Cottage"]),
            ("654 Cedar Drive", ["Cedar Villa"]),
            ("987 Birch Court", ["Birch Haven"]),
            ("159 Willow Place", ["Willow Residence"]),
            ("753 Ash Way", ["Ash Retreat"]),
            ("852 Cherry Circle", ["Cherry Nest"]),
            ("951 Palm Boulevard", ["Palm Estate"])
        ]
        
        for (address, expectedSuggestions) in testCases {
            let suggestions = sut.generateHouseNameSuggestions(from: address)
            
            for expected in expectedSuggestions {
                XCTAssertTrue(suggestions.contains(expected), 
                             "Expected '\(expected)' in suggestions for '\(address)'")
            }
        }
    }
    
    func testGenerateHouseNameSuggestions_NoStreetType() {
        // Given an address without a recognized street type
        let address = "123 Technology Campus"
        
        // When
        let suggestions = sut.generateHouseNameSuggestions(from: address)
        
        // Then
        XCTAssertTrue(suggestions.contains("Technology House") || 
                     suggestions.contains("Casa Technology") ||
                     suggestions.contains("Technology Home"))
        XCTAssertTrue(suggestions.contains("My Smart Home"))
        XCTAssertTrue(suggestions.contains("The Connected House"))
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
        XCTAssertEqual(thought.thought, "I've detected your location. Is this the right address?")
        XCTAssertEqual(thought.emotion, .curious)
        XCTAssertEqual(thought.category, .question)
        XCTAssertEqual(thought.suggestion, "You can edit the address if needed")
    }
    
    func testCreateHouseNameSuggestionResponse() {
        // Given
        let suggestions = ["Oak House", "Casa Oak", "My Smart Home"]
        
        // When
        let thought = sut.createHouseNameSuggestionResponse(suggestions)
        
        // Then
        XCTAssertEqual(thought.thought, "What should I call this house?")
        XCTAssertEqual(thought.emotion, .excited)
        XCTAssertEqual(thought.category, .question)
        XCTAssertTrue(thought.suggestion?.contains("Oak House") ?? false)
        XCTAssertTrue(thought.suggestion?.contains("Casa Oak") ?? false)
    }
}

// MARK: - Mock Classes

class MockAddressManager: AddressManager {
    var mockDetectedAddress: Address?
    var detectCurrentAddressCalled = false
    
    init() {
        super.init(
            notesService: MockNotesService(),
            locationService: MockLocationService()
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

class MockWeatherCoordinator: WeatherCoordinator {
    var fetchWeatherCalled = false
    var lastFetchedAddress: Address?
    
    init() {
        super.init(
            weatherService: MockWeatherService(),
            notesService: MockNotesService(),
            locationService: MockLocationService()
        )
    }
    
    override func fetchWeather(for address: Address) async throws -> Weather {
        fetchWeatherCalled = true
        lastFetchedAddress = address
        
        // Return mock weather
        return Weather(
            temperature: Temperature(value: 72, unit: .fahrenheit),
            condition: .partlyCloudy,
            humidity: 65,
            windSpeed: 10,
            feelsLike: Temperature(value: 70, unit: .fahrenheit),
            uvIndex: 5,
            pressure: 1013,
            visibility: 10,
            dewPoint: 55,
            forecast: [],
            hourlyForecast: [],
            lastUpdated: Date()
        )
    }
}

class MockWeatherService: WeatherServiceProtocol {
    func fetchWeather(for coordinate: Coordinate) async throws -> Weather {
        return Weather(
            temperature: Temperature(value: 72, unit: .fahrenheit),
            condition: .partlyCloudy,
            humidity: 65,
            windSpeed: 10,
            feelsLike: Temperature(value: 70, unit: .fahrenheit),
            uvIndex: 5,
            pressure: 1013,
            visibility: 10,
            dewPoint: 55,
            forecast: [],
            hourlyForecast: [],
            lastUpdated: Date()
        )
    }
    
    func fetchWeatherForAddress(_ address: Address) async throws -> Weather {
        return try await fetchWeather(for: address.coordinate)
    }
    
    var weatherUpdatePublisher: AnyPublisher<Weather, Never> {
        Empty().eraseToAnyPublisher()
    }
}
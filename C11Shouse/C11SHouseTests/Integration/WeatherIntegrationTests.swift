/*
 * CONTEXT & PURPOSE:
 * WeatherIntegrationTests validates the complete weather feature integration from location
 * services through weather data fetching, emotion determination, and UI updates. Tests use
 * real coordinators with mocked external APIs.
 *
 * DECISION HISTORY:
 * - 2025-01-10: Initial implementation
 *   - Tests complete weather workflow with real coordinators
 *   - Mocks WeatherKit API responses
 *   - Validates emotion determination logic
 *   - Tests error scenarios and recovery
 *   - Verifies UI state updates
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import Combine
import CoreLocation
import WeatherKit
@testable import C11SHouse

@MainActor
class WeatherIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var weatherCoordinator: WeatherCoordinator!
    private var locationManagerMock: MockLocationManager!
    private var weatherServiceMock: MockWeatherKitService!
    private var notesService: NotesServiceImpl!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        cancellables = Set<AnyCancellable>()
        
        // Create services
        notesService = NotesServiceImpl()
        locationManagerMock = MockLocationManager()
        weatherServiceMock = MockWeatherKitService()
        
        // Create weather coordinator with mocked services
        weatherCoordinator = WeatherCoordinator(
            weatherService: weatherServiceMock,
            notesService: notesService,
            locationService: MockLocationService()
        )
        
        // Clear any existing data
        try await notesService.clearAllData()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        try await notesService.clearAllData()
        try await super.tearDown()
    }
    
    // MARK: - Complete Weather Flow Tests
    
    func testCompleteWeatherFlow() async throws {
        // Test the complete flow from location to emotion determination
        
        // Step 1: Setup location
        let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationManagerMock.currentLocation = mockLocation
        
        // Step 2: Setup weather data
        let mockWeather = C11SHouse.Weather(
            temperature: Temperature(value: 68.0, unit: .fahrenheit),
            condition: .clear,
            humidity: 0.65,
            windSpeed: 8.0,
            feelsLike: Temperature(value: 66.0, unit: .fahrenheit),
            uvIndex: 5,
            pressure: 30.15,
            visibility: 10.0,
            dewPoint: 55.0,
            forecast: [],
            hourlyForecast: [],
            lastUpdated: Date()
        )
        weatherServiceMock.mockWeather = mockWeather
        
        // Step 3: Fetch weather
        let expectation = expectation(description: "Weather update")
        var receivedWeather: C11SHouse.Weather?
        var receivedEmotion: HouseEmotion?
        
        weatherCoordinator.$currentWeather
            .dropFirst()
            .sink { weather in
                receivedWeather = weather
            }
            .store(in: &cancellables)
        
        weatherCoordinator.$weatherBasedEmotion
            .dropFirst()
            .sink { emotion in
                receivedEmotion = emotion
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await weatherCoordinator.fetchWeatherForCurrentLocation()
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Step 4: Verify weather data
        XCTAssertNotNil(receivedWeather)
        XCTAssertEqual(receivedWeather?.temperature.value, 68.0)
        XCTAssertEqual(receivedWeather?.condition, .clear)
        
        // Step 5: Verify emotion determination
        XCTAssertNotNil(receivedEmotion)
        // Based on the weather conditions (68°F, clear, moderate humidity), should be happy
        XCTAssertEqual(receivedEmotion, .happy)
        
        // Step 6: Verify loading states
        XCTAssertFalse(weatherCoordinator.isLoadingWeather)
        XCTAssertNil(weatherCoordinator.weatherError)
    }
    
    func testWeatherEmotionMapping() async throws {
        // Test various weather conditions and their emotion mappings
        
        locationManagerMock.currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        let testCases: [(C11SHouse.Weather, HouseEmotion)] = [
            // Happy conditions - pleasant temperature, clear skies
            (createWeather(temp: 72, condition: WeatherCondition.clear, humidity: 0.5, uvIndex: 4, windSpeed: 5), .happy),
            
            // Excited conditions - cool, partly cloudy, breezy
            (createWeather(temp: 65, condition: WeatherCondition.partlyCloudy, humidity: 0.4, uvIndex: 6, windSpeed: 15), .excited),
            
            // Neutral conditions - mild, cloudy
            (createWeather(temp: 60, condition: WeatherCondition.cloudy, humidity: 0.7, uvIndex: 2, windSpeed: 3), .neutral),
            
            // Thoughtful conditions - rainy, dark
            (createWeather(temp: 50, condition: WeatherCondition.rain, humidity: 0.85, uvIndex: 0, windSpeed: 20), .thoughtful),
            
            // Content conditions - cold, snowy
            (createWeather(temp: 35, condition: WeatherCondition.snow, humidity: 0.9, uvIndex: 0, windSpeed: 10), .content),
            
            // Tired conditions - extreme heat
            (createWeather(temp: 100, condition: WeatherCondition.hot, humidity: 0.3, uvIndex: 11, windSpeed: 25), .tired),
            
            // Happy conditions - mild night (assuming coordinator checks time)
            (createWeather(temp: 68, condition: WeatherCondition.clear, humidity: 0.6, uvIndex: 0, windSpeed: 2), .happy)
        ]
        
        for (weather, expectedEmotion) in testCases {
            // Update weather service mock
            weatherServiceMock.mockWeather = weather
            
            // Fetch weather
            await weatherCoordinator.fetchWeatherForCurrentLocation()
            
            // Verify emotion
            let actualEmotion = weatherCoordinator.weatherBasedEmotion
            XCTAssertEqual(
                actualEmotion,
                expectedEmotion,
                "Weather with temp \(weather.temperature.value)°F and condition \(weather.condition) should produce \(expectedEmotion) emotion, but got \(String(describing: actualEmotion))"
            )
        }
    }
    
    func testWeatherUpdateWithLocationError() async throws {
        // Test weather update when location is unavailable
        
        locationManagerMock.currentLocation = nil
        
        await weatherCoordinator.fetchWeatherForCurrentLocation()
        
        // Verify error state
        XCTAssertNil(weatherCoordinator.currentWeather)
        XCTAssertNotNil(weatherCoordinator.weatherError)
        XCTAssertNil(weatherCoordinator.weatherBasedEmotion)
        XCTAssertFalse(weatherCoordinator.isLoadingWeather)
    }
    
    func testWeatherUpdateWithAPIError() async throws {
        // Test weather update when weather API fails
        
        // Location works
        locationManagerMock.currentLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        // Weather API fails
        weatherServiceMock.shouldThrowError = true
        
        await weatherCoordinator.fetchWeatherForCurrentLocation()
        
        // Verify error handling
        XCTAssertNil(weatherCoordinator.currentWeather)
        XCTAssertNotNil(weatherCoordinator.weatherError)
        XCTAssertNil(weatherCoordinator.weatherBasedEmotion)
        XCTAssertFalse(weatherCoordinator.isLoadingWeather)
    }
    
    func testWeatherForSpecificAddress() async throws {
        // Test fetching weather for a specific address
        
        let address = Address(
            street: "1 Apple Park Way",
            city: "Cupertino",
            state: "CA",
            postalCode: "95014",
            country: "USA",
            coordinate: Coordinate(latitude: 37.3349, longitude: -122.0090)
        )
        
        let mockWeather = createWeather(temp: 75, condition: WeatherCondition.partlyCloudy, humidity: 0.45)
        weatherServiceMock.mockWeather = mockWeather
        
        let weather = try await weatherCoordinator.fetchWeather(for: address)
        
        // Verify weather was fetched
        XCTAssertEqual(weather.temperature.value, 75.0)
        XCTAssertEqual(weather.condition, .partlyCloudy)
        
        // Verify coordinator state was updated
        XCTAssertNotNil(weatherCoordinator.currentWeather)
        XCTAssertNotNil(weatherCoordinator.weatherBasedEmotion)
    }
    
    func testWeatherSummaryPersistence() async throws {
        // Test that weather summaries are saved to notes
        
        locationManagerMock.currentLocation = CLLocation(latitude: 34.0522, longitude: -118.2437)
        
        let mockWeather = createWeather(
            temp: 78,
            condition: WeatherCondition.sunShowers,
            humidity: 0.55,
            uvIndex: 7,
            windSpeed: 12
        )
        weatherServiceMock.mockWeather = mockWeather
        
        // Fetch weather
        await weatherCoordinator.fetchWeatherForCurrentLocation()
        
        // Wait a bit for async save
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Check if weather summary was saved to notes
        let notesStore = try await notesService.loadNotesStore()
        let weatherNotes = notesStore.notes.values.filter { note in
            note.metadata?["type"] == "weather_summary" ||
            notesStore.questions.contains { $0.id == note.questionId && $0.text.lowercased().contains("weather") }
        }
        
        // Should have at least one weather-related note
        XCTAssertFalse(weatherNotes.isEmpty, "Weather summary should be saved to notes")
    }
    
    func testLoadingStates() async throws {
        // Test loading state transitions
        
        var loadingStates: [Bool] = []
        
        weatherCoordinator.$isLoadingWeather
            .sink { isLoading in
                loadingStates.append(isLoading)
            }
            .store(in: &cancellables)
        
        // Setup successful response
        locationManagerMock.currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        weatherServiceMock.mockWeather = createWeather(temp: 70, condition: WeatherCondition.clear)
        
        // Add delay to weather service to observe loading state
        weatherServiceMock.responseDelay = 0.1
        
        await weatherCoordinator.fetchWeatherForCurrentLocation()
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify loading states
        XCTAssertGreaterThanOrEqual(loadingStates.count, 2)
        XCTAssertFalse(loadingStates[0]) // Initial state
        XCTAssertTrue(loadingStates[1])  // Loading started
        XCTAssertFalse(loadingStates.last!) // Loading ended
    }
    
    // MARK: - Helper Methods
    
    private func createWeather(
        temp: Double,
        condition: C11SHouse.WeatherCondition,
        humidity: Double = 0.5,
        uvIndex: Int = 5,
        windSpeed: Double = 10
    ) -> C11SHouse.Weather {
        return C11SHouse.Weather(
            temperature: Temperature(value: temp, unit: .fahrenheit),
            condition: condition,
            humidity: humidity,
            windSpeed: windSpeed,
            feelsLike: Temperature(value: temp - 2, unit: .fahrenheit),
            uvIndex: uvIndex,
            pressure: 30.0,
            visibility: 10.0,
            dewPoint: temp - 15,
            forecast: [],
            hourlyForecast: [],
            lastUpdated: Date()
        )
    }
}

// MARK: - Mock Services

class MockLocationManager: ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    
    func requestLocationPermission() async {
        // Mock implementation
    }
    
    func startLocationUpdates() {
        // Mock implementation
    }
    
    func stopLocationUpdates() {
        // Mock implementation
    }
}

// MockWeatherService is now defined in TestMocks.swift as MockWeatherKitService

// WeatherServiceProtocol and WeatherServiceError are now defined in TestMocks.swift

// Note: Address model is now imported from main app
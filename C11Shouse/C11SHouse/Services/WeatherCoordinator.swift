/*
 * CONTEXT & PURPOSE:
 * WeatherCoordinator manages weather-related business logic, including fetching weather data,
 * determining house emotions based on weather conditions, and persisting weather summaries
 * to NotesService. It acts as an intermediary between WeatherService and the rest of the app,
 * providing a clean API for weather-related functionality.
 *
 * DECISION HISTORY:
 * - 2025-01-09: Initial implementation
 *   - Extracted weather logic from ContentViewModel
 *   - Coordinates between WeatherService and NotesService
 *   - Handles weather-based emotion determination
 *   - Persists weather summaries as notes for AI context
 *   - ObservableObject for SwiftUI integration
 *   - Async/await API for modern concurrency
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation
import Combine

/// Coordinates weather-related functionality and persists data to NotesService
@MainActor
class WeatherCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentWeather: Weather?
    @Published var isLoadingWeather = false
    @Published var weatherError: Error?
    @Published var weatherBasedEmotion: HouseEmotion?
    
    // MARK: - Private Properties
    
    private let weatherService: WeatherServiceProtocol
    private let notesService: NotesServiceProtocol
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(weatherService: WeatherServiceProtocol, notesService: NotesServiceProtocol, locationManager: LocationManager) {
        self.weatherService = weatherService
        self.notesService = notesService
        self.locationManager = locationManager
    }
    
    // MARK: - Public Methods
    
    /// Fetch weather for the current location
    func fetchWeatherForCurrentLocation() async {
        isLoadingWeather = true
        weatherError = nil
        
        defer { isLoadingWeather = false }
        
        do {
            // Get current coordinates
            guard let location = locationManager.currentLocation else {
                throw WeatherError.locationUnavailable
            }
            
            // Fetch weather
            let weather = try await weatherService.fetchWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            currentWeather = weather
            
            // Determine emotion based on weather
            weatherBasedEmotion = determineEmotion(for: weather)
            
            // Save weather summary to notes
            await saveWeatherSummary(weather)
            
        } catch {
            weatherError = error
            print("Failed to fetch weather: \(error)")
        }
    }
    
    /// Fetch weather for a specific address
    func fetchWeather(for address: Address) async throws -> Weather {
        isLoadingWeather = true
        weatherError = nil
        
        defer { isLoadingWeather = false }
        
        let weather = try await weatherService.fetchWeather(
            latitude: address.coordinates.latitude,
            longitude: address.coordinates.longitude
        )
        
        currentWeather = weather
        weatherBasedEmotion = determineEmotion(for: weather)
        
        // Save weather summary to notes
        await saveWeatherSummary(weather, for: address)
        
        return weather
    }
    
    /// Clear weather data
    func clearWeatherData() {
        currentWeather = nil
        weatherError = nil
        weatherBasedEmotion = nil
    }
    
    // MARK: - Private Methods
    
    /// Determine house emotion based on weather conditions
    private func determineEmotion(for weather: Weather) -> HouseEmotion {
        switch weather.condition {
        case .sunny, .partlyCloudy:
            return .happy
        case .cloudy, .overcast:
            return .neutral
        case .rainy, .drizzle:
            return .thoughtful
        case .thunderstorm:
            return .anxious
        case .snowy:
            return .peaceful
        case .foggy, .mist:
            return .curious
        case .windy:
            return .energetic
        case .unknown:
            return .confused
        }
    }
    
    /// Save weather summary as a note
    private func saveWeatherSummary(_ weather: Weather, for address: Address? = nil) async {
        let locationText = if let address = address {
            "\(address.street), \(address.city)"
        } else {
            "current location"
        }
        
        let summary = """
        Weather at \(locationText):
        Temperature: \(weather.temperature.formatted)
        Condition: \(weather.condition.description)
        Humidity: \(weather.humidity)%
        Wind: \(weather.windSpeed) km/h from \(weather.windDirection)
        Last updated: \(Date().formatted())
        """
        
        // Create or update a weather note
        let weatherQuestionId = "weather_summary"
        
        do {
            // Check if weather question exists, if not create it
            let notesStore = try await notesService.loadNotesStore()
            if !notesStore.questions.contains(where: { $0.id == weatherQuestionId }) {
                // Create weather question
                let weatherQuestion = Question(
                    id: weatherQuestionId,
                    text: "Current Weather Summary",
                    category: .environment,
                    isRequired: false,
                    order: 999, // Put at the end
                    metadata: ["type": "weather_summary", "auto_generated": "true"]
                )
                
                var updatedQuestions = notesStore.questions
                updatedQuestions.append(weatherQuestion)
                
                try await notesService.updateQuestions(updatedQuestions)
            }
            
            // Save weather summary as answer
            try await notesService.saveOrUpdateNote(
                for: weatherQuestionId,
                answer: summary,
                metadata: [
                    "temperature": "\(weather.temperature.value)",
                    "condition": weather.condition.rawValue,
                    "humidity": "\(weather.humidity)",
                    "wind_speed": "\(weather.windSpeed)",
                    "wind_direction": weather.windDirection,
                    "last_updated": ISO8601DateFormatter().string(from: Date())
                ]
            )
        } catch {
            print("Failed to save weather summary: \(error)")
        }
    }
}

// MARK: - Weather Error

enum WeatherError: LocalizedError {
    case locationUnavailable
    
    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Current location is not available"
        }
    }
}
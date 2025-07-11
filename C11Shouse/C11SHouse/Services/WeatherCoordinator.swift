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
    private let locationService: LocationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(weatherService: WeatherServiceProtocol, notesService: NotesServiceProtocol, locationService: LocationServiceProtocol) {
        self.weatherService = weatherService
        self.notesService = notesService
        self.locationService = locationService
    }
    
    // MARK: - Public Methods
    
    /// Fetch weather for the current location
    func fetchWeatherForCurrentLocation() async {
        isLoadingWeather = true
        weatherError = nil
        
        defer { isLoadingWeather = false }
        
        do {
            // Get current location
            let location = try await locationService.getCurrentLocation()
            let coordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            
            // Fetch weather
            let weather = try await weatherService.fetchWeather(for: coordinate)
            
            currentWeather = weather
            
            // Determine emotion based on weather
            weatherBasedEmotion = determineEmotion(for: weather)
            
            // Save weather summary to notes
            await saveWeatherSummary(weather)
            
        } catch {
            weatherError = error
            print("Failed to fetch weather: \(error)")
            
            // Save error to notes for tracking
            await saveWeatherError(error)
        }
    }
    
    /// Fetch weather for a specific address
    func fetchWeather(for address: Address) async throws -> Weather {
        isLoadingWeather = true
        weatherError = nil
        
        defer { isLoadingWeather = false }
        
        do {
            let weather = try await weatherService.fetchWeather(for: address.coordinate)
            
            currentWeather = weather
            weatherBasedEmotion = determineEmotion(for: weather)
            
            // Save weather summary to notes
            await saveWeatherSummary(weather, for: address)
            
            return weather
        } catch {
            weatherError = error
            
            // Save error to notes for tracking
            await saveWeatherError(error, for: address)
            
            // Re-throw the error
            throw error
        }
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
        case .clear, .mostlyClear, .partlyCloudy:
            return .happy
        case .cloudy, .mostlyCloudy:
            return .neutral
        case .rain, .drizzle, .heavyRain:
            return .thoughtful
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return .worried
        case .snow, .flurries, .heavySnow:
            return .content
        case .foggy, .haze, .smoky:
            return .curious
        case .windy, .breezy:
            return .excited
        default:
            return .neutral
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
        Condition: \(weather.condition.rawValue)
        Humidity: \(Int(weather.humidity * 100))%
        Wind: \(Int(weather.windSpeed)) km/h
        Last updated: \(Date().formatted())
        """
        
        // Update or create weather status note
        await updateWeatherStatusNote(summary)
    }
    
    /// Save weather error as a note
    private func saveWeatherError(_ error: Error, for address: Address? = nil) async {
        let locationText = if let address = address {
            "\(address.street), \(address.city)"
        } else {
            "current location"
        }
        
        let errorDetails: String
        let errorType: String
        
        // Check specific error types
        if let weatherError = error as? WeatherError {
            switch weatherError {
            case .sandboxRestriction:
                errorType = "Sandbox Restriction"
                errorDetails = "WeatherKit is not available in the simulator. This works correctly on real devices."
            case .invalidLocation:
                errorType = "Invalid Location"
                errorDetails = "The location coordinates are invalid for weather data."
            case .networkError(let underlyingError):
                errorType = "Network Error"
                errorDetails = underlyingError.localizedDescription
            }
        } else if (error as NSError).domain.contains("weatherkit") {
            errorType = "WeatherKit Error"
            errorDetails = """
            Domain: \((error as NSError).domain)
            Code: \((error as NSError).code)
            Description: \(error.localizedDescription)
            """
        } else {
            errorType = "Unknown Error"
            errorDetails = error.localizedDescription
        }
        
        let errorSummary = """
        Weather Error at \(locationText):
        Type: \(errorType)
        Details: \(errorDetails)
        Time: \(Date().formatted())
        
        Note: This error has been logged. Weather features may be limited until this is resolved.
        """
        
        // Update or create weather status note with error
        await updateWeatherStatusNote(errorSummary)
    }
    
    /// Update or create a single weather status note
    private func updateWeatherStatusNote(_ content: String) async {
        do {
            let notesStore = try await notesService.loadNotesStore()
            
            // Look for existing weather status question/key
            if let existingQuestion = notesStore.questions.first(where: { $0.text == "Weather Status" }) {
                // Update existing note
                try await notesService.saveOrUpdateNote(
                    for: existingQuestion.id,
                    answer: content,
                    metadata: ["type": "status", "category": "Status", "lastUpdated": Date().ISO8601Format()]
                )
            } else {
                // Create new weather status entry (not a conversation question)
                let weatherStatusKey = Question(
                    text: "Weather Status",
                    category: .other,
                    displayOrder: 9999, // Very high so it's never shown in conversation
                    isRequired: false,
                    hint: "Automatic weather status tracking"
                )
                
                try await notesService.addQuestion(weatherStatusKey)
                try await notesService.saveOrUpdateNote(
                    for: weatherStatusKey.id,
                    answer: content,
                    metadata: ["type": "status", "category": "Status", "lastUpdated": Date().ISO8601Format()]
                )
            }
        } catch {
            print("Failed to update weather status note: \(error)")
        }
    }
}

// MARK: - Weather Coordinator Error

enum WeatherCoordinatorError: LocalizedError {
    case locationUnavailable
    
    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Current location is not available"
        }
    }
}
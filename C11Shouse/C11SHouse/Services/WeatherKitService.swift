/*
 * CONTEXT & PURPOSE:
 * WeatherKitService provides weather data using Apple's WeatherKit framework. It fetches
 * current conditions, forecasts, and weather metrics, converting WeatherKit's native types
 * to our app's Weather model for consistent data handling across the application.
 *
 * DECISION HISTORY:
 * - 2025-07-08: Initial implementation
 *   - Uses WeatherKit for native iOS weather integration
 *   - No API keys required, uses Apple Developer account
 *   - Converts WeatherKit types to app models for abstraction
 *   - PassthroughSubject for weather updates
 *   - Comprehensive weather data including UV, pressure, visibility
 *   - 7-day and 24-hour forecasts included
 *   - @MainActor for thread-safe UI updates
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation
import WeatherKit
import CoreLocation
import Combine

// MARK: - Weather Service Errors

enum WeatherError: LocalizedError {
    case sandboxRestriction
    case invalidLocation
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .sandboxRestriction:
            return "Weather service is not available in the simulator. Please run on a real device."
        case .invalidLocation:
            return "Invalid location for weather data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Protocol

protocol WeatherServiceProtocol {
    func fetchWeather(for coordinate: Coordinate) async throws -> Weather
    func fetchWeatherForAddress(_ address: Address) async throws -> Weather
    var weatherUpdatePublisher: AnyPublisher<Weather, Never> { get }
}

// MARK: - Implementation

class WeatherKitServiceImpl: WeatherServiceProtocol {
    private let weatherService = WeatherService.shared
    private let weatherUpdateSubject = PassthroughSubject<Weather, Never>()
    
    var weatherUpdatePublisher: AnyPublisher<Weather, Never> {
        weatherUpdateSubject.eraseToAnyPublisher()
    }
    
    func fetchWeather(for coordinate: Coordinate) async throws -> Weather {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        do {
            // Fetch current weather and forecasts from WeatherKit
            // Note: WeatherKit may fail in simulator with sandbox errors
            // It works correctly on real devices with proper entitlements
            let weather = try await weatherService.weather(for: location)
            
            // Convert WeatherKit data to our Weather model
            let currentWeather = weather.currentWeather
            let dailyForecast = weather.dailyForecast
            let hourlyForecast = weather.hourlyForecast
            
            let weatherData = Weather(
                temperature: Temperature(from: currentWeather.temperature),
                condition: WeatherCondition(from: currentWeather.condition),
                humidity: currentWeather.humidity,
                windSpeed: currentWeather.wind.speed.value,
                feelsLike: Temperature(from: currentWeather.apparentTemperature),
                uvIndex: currentWeather.uvIndex.value,
                pressure: currentWeather.pressure.value,
                visibility: currentWeather.visibility.value,
                dewPoint: currentWeather.dewPoint.value,
                forecast: Array(dailyForecast.forecast.prefix(7).map { DailyForecast(from: $0) }),
                hourlyForecast: Array(hourlyForecast.forecast.prefix(24).map { HourlyForecast(from: $0) }),
                lastUpdated: Date()
            )
            
            // Publish update
            weatherUpdateSubject.send(weatherData)
            
            return weatherData
        } catch {
            // Log the full error for debugging
            print("WeatherKit Error Details:")
            print("- Error: \(error)")
            print("- Localized: \(error.localizedDescription)")
            print("- Domain: \((error as NSError).domain)")
            print("- Code: \((error as NSError).code)")
            
            // Check if this is a sandbox restriction error
            if error.localizedDescription.contains("Sandbox restriction") || 
               error.localizedDescription.contains("com.apple.weatherkit.authservice") {
                // This shouldn't happen on physical devices
                print("WARNING: WeatherKit sandbox error on physical device!")
                print("This usually indicates:")
                print("1. Bundle ID mismatch with provisioning profile")
                print("2. WeatherKit not properly configured in App ID")
                print("3. Provisioning profile needs regeneration")
                throw WeatherError.sandboxRestriction
            } else {
                // Re-throw other errors
                throw error
            }
        }
    }
    
    func fetchWeatherForAddress(_ address: Address) async throws -> Weather {
        let coordinate = address.coordinate
        return try await fetchWeather(for: coordinate)
    }
}
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
            return "Weather service authorization failed. Check WeatherKit configuration in App ID."
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
    
    init() {
        print("[WeatherKitService] 🌦️ Initializing WeatherKit service")
        print("[WeatherKitService] Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        
        // Check if we're running on a real device
        #if targetEnvironment(simulator)
        print("[WeatherKitService] ⚠️ Running in Simulator - WeatherKit may have limitations")
        #else
        print("[WeatherKitService] ✅ Running on real device")
        #endif
        
        // Log entitlements
        if let path = Bundle.main.path(forResource: "C11SHouse", ofType: "entitlements") {
            print("[WeatherKitService] Entitlements file found at: \(path)")
        } else {
            print("[WeatherKitService] ⚠️ Entitlements file not found in bundle")
        }
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
            print("🌦️ WeatherKit Error Details:")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📍 Location: \(coordinate.latitude), \(coordinate.longitude)")
            print("❌ Error: \(error)")
            print("📝 Localized: \(error.localizedDescription)")
            print("🏷️ Domain: \((error as NSError).domain)")
            print("🔢 Code: \((error as NSError).code)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            // Check if this is an authorization error
            if error.localizedDescription.contains("Sandbox restriction") || 
               error.localizedDescription.contains("com.apple.weatherkit.authservice") {
                print("⚠️ WeatherKit Configuration Issue Detected!")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("This error indicates WeatherKit is not properly configured.")
                print("")
                print("To fix this issue:")
                print("1. Verify Bundle ID matches: \(Bundle.main.bundleIdentifier ?? "Unknown")")
                print("2. Check WeatherKit is enabled in your App ID configuration")
                print("3. Ensure provisioning profile includes WeatherKit capability")
                print("4. Regenerate provisioning profile if needed")
                print("")
                print("Note: WeatherKit requires:")
                print("- Active Apple Developer account")
                print("- WeatherKit capability enabled in App ID")
                print("- Valid provisioning profile with WeatherKit")
                print("- Proper entitlements in the app")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
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
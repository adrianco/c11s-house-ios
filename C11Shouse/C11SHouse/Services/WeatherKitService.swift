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

// MARK: - Protocol

protocol WeatherServiceProtocol {
    func fetchWeather(for coordinate: Coordinate) async throws -> Weather
    func fetchWeatherForAddress(_ address: Address) async throws -> Weather
    var weatherUpdatePublisher: AnyPublisher<Weather, Never> { get }
}

// MARK: - Implementation

@MainActor
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
        
        // Fetch current weather and forecasts from WeatherKit
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
    }
    
    func fetchWeatherForAddress(_ address: Address) async throws -> Weather {
        let coordinate = address.coordinate
        return try await fetchWeather(for: coordinate)
    }
}
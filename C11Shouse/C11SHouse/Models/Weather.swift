/*
 * CONTEXT & PURPOSE:
 * Weather models represent weather data from WeatherKit, providing a comprehensive
 * structure for current conditions, forecasts, and weather-related information. These
 * models bridge between WeatherKit's native types and our app's data structures.
 *
 * DECISION HISTORY:
 * - 2025-07-08: Initial implementation
 *   - Comprehensive weather condition enum matching WeatherKit conditions
 *   - Temperature wrapper for unit conversion and formatting
 *   - Daily and hourly forecast models for predictions
 *   - All weather metrics included (UV, pressure, visibility, etc.)
 *   - SF Symbols mapping for each weather condition
 *   - Codable for persistence in notes
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation
import WeatherKit
import SwiftUI

// MARK: - Main Weather Model

struct Weather: Codable {
    let temperature: Temperature
    let condition: WeatherCondition
    let humidity: Double
    let windSpeed: Double
    let feelsLike: Temperature
    let uvIndex: Int
    let pressure: Double
    let visibility: Double
    let dewPoint: Double
    let forecast: [DailyForecast]
    let hourlyForecast: [HourlyForecast]
    let lastUpdated: Date
}

// MARK: - Temperature

struct Temperature: Codable {
    let value: Double
    let unit: Foundation.UnitTemperature
    
    var formatted: String {
        let measurement = Measurement(value: value, unit: unit)
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: measurement)
    }
    
    init(value: Double, unit: Foundation.UnitTemperature) {
        self.value = value
        self.unit = unit
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case value
        case unit
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(Double.self, forKey: .value)
        let unitString = try container.decode(String.self, forKey: .unit)
        switch unitString {
        case "celsius":
            unit = .celsius
        case "fahrenheit":
            unit = .fahrenheit
        default:
            unit = .celsius
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        let unitString = unit == .celsius ? "celsius" : "fahrenheit"
        try container.encode(unitString, forKey: .unit)
    }
    
    init(from measurement: Measurement<UnitTemperature>) {
        self.value = measurement.value
        self.unit = measurement.unit == .celsius ? .celsius : .fahrenheit
    }
}

// MARK: - Weather Conditions

enum WeatherCondition: String, Codable {
    case blowingDust
    case clear
    case cloudy
    case foggy
    case haze
    case mostlyClear
    case mostlyCloudy
    case partlyCloudy
    case smoky
    case breezy
    case windy
    case drizzle
    case heavyRain
    case rain
    case flurries
    case heavySnow
    case sleet
    case snow
    case blizzard
    case blowingSnow
    case freezingDrizzle
    case freezingRain
    case frigid
    case hail
    case hot
    case isolatedThunderstorms
    case scatteredThunderstorms
    case strongStorms
    case thunderstorms
    case tropicalStorm
    case hurricane
    case sunShowers
    case wintryMix
    
    init(from weatherCondition: WeatherKit.WeatherCondition) {
        switch weatherCondition {
        case .blowingDust: self = .blowingDust
        case .clear: self = .clear
        case .cloudy: self = .cloudy
        case .foggy: self = .foggy
        case .haze: self = .haze
        case .mostlyClear: self = .mostlyClear
        case .mostlyCloudy: self = .mostlyCloudy
        case .partlyCloudy: self = .partlyCloudy
        case .smoky: self = .smoky
        case .breezy: self = .breezy
        case .windy: self = .windy
        case .drizzle: self = .drizzle
        case .heavyRain: self = .heavyRain
        case .rain: self = .rain
        case .sunShowers: self = .sunShowers
        case .wintryMix: self = .wintryMix
        case .flurries: self = .flurries
        case .heavySnow: self = .heavySnow
        case .sleet: self = .sleet
        case .snow: self = .snow
        case .blizzard: self = .blizzard
        case .blowingSnow: self = .blowingSnow
        case .freezingDrizzle: self = .freezingDrizzle
        case .freezingRain: self = .freezingRain
        case .frigid: self = .frigid
        case .hail: self = .hail
        case .hot: self = .hot
        case .isolatedThunderstorms: self = .isolatedThunderstorms
        case .scatteredThunderstorms: self = .scatteredThunderstorms
        case .strongStorms: self = .strongStorms
        case .thunderstorms: self = .thunderstorms
        case .tropicalStorm: self = .tropicalStorm
        case .hurricane: self = .hurricane
        @unknown default: self = .clear
        }
    }
    
    var icon: String {
        switch self {
        case .clear, .mostlyClear: 
            return "sun.max.fill"
        case .cloudy, .mostlyCloudy: 
            return "cloud.fill"
        case .partlyCloudy: 
            return "cloud.sun.fill"
        case .rain, .drizzle: 
            return "cloud.rain.fill"
        case .sunShowers:
            return "cloud.sun.rain.fill"
        case .heavyRain: 
            return "cloud.heavyrain.fill"
        case .snow, .flurries, .heavySnow: 
            return "cloud.snow.fill"
        case .blizzard, .blowingSnow: 
            return "wind.snow"
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return "cloud.bolt.rain.fill"
        case .foggy: 
            return "cloud.fog.fill"
        case .haze, .smoky: 
            return "sun.haze.fill"
        case .windy, .breezy: 
            return "wind"
        case .sleet, .freezingRain, .freezingDrizzle: 
            return "cloud.sleet.fill"
        case .wintryMix:
            return "cloud.sleet.fill"
        case .hail: 
            return "cloud.hail.fill"
        case .hot: 
            return "thermometer.sun.fill"
        case .frigid: 
            return "thermometer.snowflake"
        case .tropicalStorm, .hurricane: 
            return "hurricane"
        case .blowingDust: 
            return "sun.dust.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .clear, .mostlyClear:
            return .yellow
        case .cloudy, .mostlyCloudy, .partlyCloudy:
            return .gray
        case .rain, .drizzle, .heavyRain, .sunShowers:
            return .blue
        case .snow, .flurries, .heavySnow, .blizzard, .blowingSnow:
            return .white
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return .purple
        case .foggy, .haze, .smoky:
            return .gray
        case .windy, .breezy:
            return .mint
        case .sleet, .freezingRain, .freezingDrizzle, .wintryMix:
            return .cyan
        case .hail:
            return .white
        case .hot:
            return .red
        case .frigid:
            return .blue
        case .tropicalStorm, .hurricane:
            return .red
        case .blowingDust:
            return .brown
        }
    }
}

// MARK: - Forecast Models

struct DailyForecast: Codable {
    let date: Date
    let highTemperature: Temperature
    let lowTemperature: Temperature
    let condition: WeatherCondition
    let precipitationChance: Double
    
    init(from dayWeather: DayWeather) {
        self.date = dayWeather.date
        self.highTemperature = Temperature(from: dayWeather.highTemperature)
        self.lowTemperature = Temperature(from: dayWeather.lowTemperature)
        self.condition = WeatherCondition(from: dayWeather.condition)
        self.precipitationChance = dayWeather.precipitationChance
    }
}

struct HourlyForecast: Codable {
    let date: Date
    let temperature: Temperature
    let condition: WeatherCondition
    let precipitationChance: Double
    
    init(from hourWeather: HourWeather) {
        self.date = hourWeather.date
        self.temperature = Temperature(from: hourWeather.temperature)
        self.condition = WeatherCondition(from: hourWeather.condition)
        self.precipitationChance = hourWeather.precipitationChance
    }
}
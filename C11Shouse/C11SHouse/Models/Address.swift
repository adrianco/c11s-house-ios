/*
 * CONTEXT & PURPOSE:
 * Address model represents a physical address with geocoding information. It provides
 * a structured way to store and work with location data, including coordinates, street
 * address components, and formatting utilities for display and storage.
 *
 * DECISION HISTORY:
 * - 2025-07-08: Initial implementation
 *   - Codable for persistence and API communication
 *   - Equatable for comparison and change detection
 *   - Coordinate as nested type for cleaner API
 *   - fullAddress computed property for easy display
 *   - All fields required (non-optional) for data consistency
 *   - Designed to work with CLGeocoder results
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation

struct Address: Codable, Equatable {
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let coordinate: Coordinate
    
    var fullAddress: String {
        "\(street), \(city), \(state) \(postalCode)"
    }
}

struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}
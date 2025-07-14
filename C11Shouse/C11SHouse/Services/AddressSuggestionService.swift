/*
 * CONTEXT & PURPOSE:
 * AddressSuggestionService provides intelligent address suggestions during onboarding.
 * It uses location detection to pre-populate addresses and generates creative house names
 * based on street names. This creates a magical user experience where the app seems to
 * already know what the user wants.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Initial implementation
 *   - Pre-populates detected address for user confirmation
 *   - Generates creative house name suggestions based on street
 *   - Works with ConversationStateManager to populate transcript
 *   - Integrates with weather service after address confirmation
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation
import CoreLocation

/// Service for providing intelligent address suggestions
class AddressSuggestionService {
    
    private let addressManager: AddressManager
    private let locationService: LocationServiceProtocol
    private let weatherCoordinator: WeatherCoordinator
    
    // Common street type mappings for creative house names
    private let streetTypeNames: [String: String] = [
        "Street": "House",
        "St": "House",
        "Avenue": "Manor",
        "Ave": "Manor",
        "Road": "Lodge",
        "Rd": "Lodge",
        "Lane": "Cottage",
        "Ln": "Cottage",
        "Drive": "Villa",
        "Dr": "Villa",
        "Court": "Haven",
        "Ct": "Haven",
        "Place": "Residence",
        "Pl": "Residence",
        "Way": "Retreat",
        "Circle": "Nest",
        "Cir": "Nest",
        "Boulevard": "Estate",
        "Blvd": "Estate"
    ]
    
    init(addressManager: AddressManager, 
         locationService: LocationServiceProtocol,
         weatherCoordinator: WeatherCoordinator) {
        self.addressManager = addressManager
        self.locationService = locationService
        self.weatherCoordinator = weatherCoordinator
    }
    
    /// Detect and suggest current address
    func suggestCurrentAddress() async throws -> String {
        let address = try await addressManager.detectCurrentAddress()
        return address.fullAddress
    }
    
    /// Generate creative house name suggestions based on address
    func generateHouseNameSuggestions(from address: String) -> [String] {
        var suggestions: [String] = []
        
        // Extract street name and type
        let components = address.components(separatedBy: " ")
        
        // Look for street type keywords
        for (index, component) in components.enumerated() {
            if let nameType = streetTypeNames[component] {
                // Get the word before the street type
                if index > 0 {
                    let streetName = components[index - 1]
                    let baseName = streetName.replacingOccurrences(of: ",", with: "")
                    
                    // Primary suggestion
                    suggestions.append("\(baseName) \(nameType)")
                    
                    // Alternative suggestions
                    if nameType == "House" {
                        suggestions.append("Casa \(baseName)")
                    }
                    if nameType == "Manor" {
                        suggestions.append("\(baseName) Estate")
                    }
                    if nameType == "Lodge" {
                        suggestions.append("\(baseName) Den")
                    }
                }
            }
        }
        
        // If no street type found, use generic suggestions
        if suggestions.isEmpty {
            if let firstStreetWord = extractStreetName(from: address) {
                suggestions.append("\(firstStreetWord) House")
                suggestions.append("Casa \(firstStreetWord)")
                suggestions.append("\(firstStreetWord) Home")
            }
        }
        
        // Ensure we have at least one suggestion
        if suggestions.isEmpty {
            suggestions.append("My Smart Home")
        }
        
        // Remove duplicates while preserving order (street-based names first)
        var seen = Set<String>()
        var uniqueSuggestions: [String] = []
        for suggestion in suggestions {
            if !seen.contains(suggestion) {
                seen.insert(suggestion)
                uniqueSuggestions.append(suggestion)
            }
        }
        
        // Add generic options only if we have room
        if uniqueSuggestions.count < 3 {
            for generic in ["My Smart Home", "The Connected House"] {
                if !seen.contains(generic) && uniqueSuggestions.count < 3 {
                    uniqueSuggestions.append(generic)
                }
            }
        }
        
        return Array(uniqueSuggestions.prefix(3))
    }
    
    /// Extract the main street name from an address
    private func extractStreetName(from address: String) -> String? {
        // Remove numbers and common prefixes
        let components = address.components(separatedBy: " ")
        for component in components {
            // Skip numbers and short words
            if !component.allSatisfy({ $0.isNumber }) && component.count > 2 {
                // Skip common words
                let skipWords = ["North", "South", "East", "West", "N", "S", "E", "W"]
                if !skipWords.contains(component) {
                    return component.replacingOccurrences(of: ",", with: "")
                }
            }
        }
        return nil
    }
    
    /// Trigger weather fetch after address confirmation
    func fetchWeatherForConfirmedAddress(_ address: Address) async {
        print("[AddressSuggestionService] Starting weather fetch for confirmed address")
        print("[AddressSuggestionService] Address: \(address.fullAddress)")
        print("[AddressSuggestionService] Coordinates: \(address.coordinate.latitude), \(address.coordinate.longitude)")
        print("[AddressSuggestionService] Timestamp: \(Date())")
        
        // Ensure weather question exists before fetching
        print("[AddressSuggestionService] Ensuring weather question exists in notes store")
        await weatherCoordinator.ensureWeatherQuestionExists()
        
        // Add a small delay to ensure notes are saved
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("[AddressSuggestionService] Initiating weather fetch")
        do {
            let weather = try await weatherCoordinator.fetchWeather(for: address)
            print("[AddressSuggestionService] ✅ Weather fetch successful")
            print("[AddressSuggestionService] Condition: \(weather.condition)")
            print("[AddressSuggestionService] Temperature: \(weather.temperature.value)°\(weather.temperature.unit)")
            print("[AddressSuggestionService] Humidity: \(Int(weather.humidity * 100))%")
            print("[AddressSuggestionService] Wind: \(Int(weather.windSpeed)) km/h")
        } catch {
            print("[AddressSuggestionService] ❌ Weather fetch failed")
            print("[AddressSuggestionService] Error type: \(type(of: error))")
            print("[AddressSuggestionService] Error: \(error)")
            
            // Log specific error details
            if let weatherError = error as? WeatherError {
                switch weatherError {
                case .sandboxRestriction:
                    print("[AddressSuggestionService] ⚠️ WeatherKit configuration issue detected")
                    print("[AddressSuggestionService] Check: 1) Bundle ID matches provisioning profile")
                    print("[AddressSuggestionService] Check: 2) WeatherKit capability is enabled in App ID")
                    print("[AddressSuggestionService] Check: 3) Provisioning profile includes WeatherKit")
                case .invalidLocation:
                    print("[AddressSuggestionService] ⚠️ Invalid location coordinates")
                case .networkError(let underlyingError):
                    print("[AddressSuggestionService] ⚠️ Network error: \(underlyingError)")
                }
            }
        }
    }
    
    /// Create a pre-populated response for address confirmation
    func createAddressConfirmationResponse(_ detectedAddress: String) -> HouseThought {
        return HouseThought(
            thought: "I've detected your location. Is this the right address?\n\n\(detectedAddress)",
            emotion: .curious,
            category: .question,
            confidence: 0.9,
            context: "Address Detection",
            suggestion: nil  // Remove the edit suggestion since it's confusing
        )
    }
    
    /// Create a house name suggestion response
    func createHouseNameSuggestionResponse(_ suggestions: [String]) -> HouseThought {
        // Use the first suggestion as the primary one
        let primarySuggestion = suggestions.first ?? "My House"
        return HouseThought(
            thought: "What should I call this house?\n\n\(primarySuggestion)",
            emotion: .excited,
            category: .question,
            confidence: 1.0,
            context: "House Naming",
            suggestion: nil  // Don't use suggestion field to keep it simple
        )
    }
}
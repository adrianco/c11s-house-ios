/*
 * CONTEXT & PURPOSE:
 * AddressParser consolidates all address string parsing and manipulation logic
 * into a single utility class. This eliminates duplicate code and provides
 * consistent address handling throughout the application.
 *
 * DECISION HISTORY:
 * - 2025-01-10: Initial implementation
 *   - Extracted duplicate logic from AddressManager and NotesView
 *   - Provides static methods for parsing address strings
 *   - Handles house name generation from street names
 *   - Centralizes street suffix detection and removal
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation

/// Utility class for parsing and manipulating address strings
enum AddressParser {
    
    // MARK: - Constants
    
    /// Common street suffixes and their abbreviations
    private static let streetSuffixPattern = #"\b(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Place|Pl|Way|Circle|Cir|Terrace|Ter|Parkway|Pkwy|Plaza)\.?\b"#
    
    // MARK: - Address Parsing
    
    /// Parse an address string into components
    /// - Parameter addressText: The full address string (e.g., "123 Main St, City, State 12345")
    /// - Returns: A tuple containing parsed components, or nil if parsing fails
    static func parseComponents(from addressText: String) -> (street: String, city: String, state: String, postalCode: String, country: String)? {
        let components = addressText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Try comma-separated parsing first
        if components.count >= 3 {
            let street = components[0]
            let city = components[1]
            
            // Parse state and postal code from third component
            let stateZipComponents = components[2].components(separatedBy: " ")
            let state = stateZipComponents.first ?? ""
            let postalCode = stateZipComponents.count > 1 ? stateZipComponents[1] : ""
            
            // Country is optional, default to United States
            let country = components.count > 3 ? components[3] : "United States"
            
            return (street: street, city: city, state: state, postalCode: postalCode, country: country)
        }
        
        // Try space-separated parsing for addresses without commas
        // Pattern: "123 Main Street [Apt/Suite info] City State ZipCode"
        let words = addressText.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").filter { !$0.isEmpty }
        
        guard words.count >= 4 else { return nil }
        
        // Find the zip code (5 digits, optionally followed by dash and 4 more digits)
        let zipRegex = #"^\d{5}(-\d{4})?$"#
        var zipIndex = -1
        var postalCode = ""
        
        for (index, word) in words.enumerated().reversed() {
            if word.range(of: zipRegex, options: .regularExpression) != nil {
                zipIndex = index
                postalCode = word
                break
            }
        }
        
        guard zipIndex > 2 else { return nil } // Need at least street, city, state before zip
        
        // State is the word before zip code
        let state = words[zipIndex - 1]
        
        // City could be multiple words, find it by looking for common apartment/suite keywords
        var cityStartIndex = -1
        let apartmentKeywords = ["apt", "apartment", "suite", "unit", "ste", "#"]
        
        for (index, word) in words.enumerated() {
            if apartmentKeywords.contains(word.lowercased()) {
                cityStartIndex = index + 2 // Skip apartment keyword and number
                break
            }
        }
        
        // If no apartment info found, assume city starts after street name
        if cityStartIndex == -1 {
            // Look for street suffix to find end of street
            for (index, word) in words.enumerated() {
                if word.lowercased().range(of: #"^(street|st|avenue|ave|road|rd|boulevard|blvd|lane|ln|drive|dr|court|ct|place|pl|way|circle|cir|terrace|ter|parkway|pkwy|plaza)\.?$"#, options: .regularExpression) != nil {
                    cityStartIndex = index + 1
                    break
                }
            }
        }
        
        guard cityStartIndex > 0 && cityStartIndex < zipIndex - 1 else { return nil }
        
        // Extract components
        let street = words[0..<cityStartIndex].joined(separator: " ")
        let city = words[cityStartIndex..<zipIndex - 1].joined(separator: " ")
        
        return (street: street, city: city, state: state, postalCode: postalCode, country: "United States")
    }
    
    /// Parse an address string into an Address object
    /// - Parameters:
    ///   - addressText: The full address string
    ///   - coordinate: Optional coordinate to include in the Address
    /// - Returns: An Address object, or nil if parsing fails
    static func parseAddress(_ addressText: String, coordinate: Coordinate? = nil) -> Address? {
        guard let components = parseComponents(from: addressText) else { return nil }
        
        return Address(
            street: components.street,
            city: components.city,
            state: components.state,
            postalCode: components.postalCode,
            country: components.country,
            coordinate: coordinate ?? Coordinate(latitude: 0, longitude: 0)
        )
    }
    
    // MARK: - Street Name Extraction
    
    /// Extract the street name from a full street address
    /// - Parameter street: The full street address (e.g., "123 Main Street")
    /// - Returns: The cleaned street name without numbers or suffixes
    static func extractStreetName(from street: String) -> String {
        let cleanedStreet = street
            // Remove house numbers
            .replacingOccurrences(of: #"\d+"#, with: "", options: .regularExpression)
            // Remove street suffixes
            .replacingOccurrences(of: streetSuffixPattern,
                                with: "",
                                options: [.regularExpression, .caseInsensitive])
            // Clean up whitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedStreet
    }
    
    /// Extract just the street component from a full address string
    /// - Parameter addressText: The full address string
    /// - Returns: The street component, or the full text if no comma is found
    static func extractStreetComponent(from addressText: String) -> String {
        return addressText
            .components(separatedBy: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? addressText
    }
    
    // MARK: - House Name Generation
    
    /// Generate a house name from a street address
    /// - Parameter street: The street address
    /// - Returns: A suggested house name
    static func generateHouseName(from street: String) -> String {
        let streetName = extractStreetName(from: street)
        
        if !streetName.isEmpty {
            return "\(streetName) House"
        }
        
        return "My House"
    }
    
    /// Generate a house name from a full address string
    /// - Parameter addressText: The full address string
    /// - Returns: A suggested house name
    static func generateHouseNameFromAddress(_ addressText: String) -> String {
        let street = extractStreetComponent(from: addressText)
        return generateHouseName(from: street)
    }
}
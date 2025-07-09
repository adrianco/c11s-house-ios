/*
 * CONTEXT & PURPOSE:
 * AddressManager consolidates all address-related logic including parsing, validation,
 * house name generation, and coordination with location services. It provides a single
 * source of truth for address operations while persisting data through NotesService.
 *
 * DECISION HISTORY:
 * - 2025-01-09: Initial implementation
 *   - Extracted from ConversationView and ContentViewModel
 *   - Consolidates duplicate address parsing logic
 *   - Handles house name generation from street names
 *   - Coordinates with LocationService for detection
 *   - Persists to NotesService for unified memory
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation
import CoreLocation

@MainActor
class AddressManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var detectedAddress: Address?
    @Published var isDetectingAddress = false
    
    // MARK: - Private Properties
    
    private let notesService: NotesServiceProtocol
    private let locationService: LocationServiceProtocol
    
    // MARK: - Initialization
    
    init(notesService: NotesServiceProtocol, locationService: LocationServiceProtocol) {
        self.notesService = notesService
        self.locationService = locationService
    }
    
    // MARK: - Public Methods
    
    /// Detect current address using location services
    func detectCurrentAddress() async throws -> Address {
        isDetectingAddress = true
        defer { isDetectingAddress = false }
        
        // Check location permission
        let status = await locationService.authorizationStatusPublisher.values.first { _ in true } ?? .notDetermined
        
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw AddressError.locationPermissionDenied
        }
        
        // Get current location
        let location = try await locationService.getCurrentLocation()
        
        // Look up address
        let address = try await locationService.lookupAddress(for: location)
        
        detectedAddress = address
        return address
    }
    
    /// Parse address text into Address object
    func parseAddress(_ addressText: String) -> Address? {
        let components = addressText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard components.count >= 3 else { return nil }
        
        let street = components[0]
        let city = components[1]
        let stateZip = components[2].components(separatedBy: " ")
        let state = stateZip.first ?? ""
        let postalCode = stateZip.count > 1 ? stateZip[1] : ""
        
        // Try to get coordinates if we have a detected address
        let coordinate = detectedAddress?.coordinate ?? Coordinate(latitude: 0, longitude: 0)
        
        return Address(
            street: street,
            city: city,
            state: state,
            postalCode: postalCode,
            country: components.count > 3 ? components[3] : "United States",
            coordinate: coordinate
        )
    }
    
    /// Generate house name suggestion from address
    func generateHouseName(from addressText: String) -> String {
        // Parse the address to extract street name
        let components = addressText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        if let street = components.first {
            return generateHouseNameFromStreet(street)
        }
        
        // If we can't extract a street name, return a generic suggestion
        return "My House"
    }
    
    /// Generate house name from street component
    func generateHouseNameFromStreet(_ street: String) -> String {
        let streetName = street
            .replacingOccurrences(of: #"\d+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\b(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Place|Pl|Way|Circle|Cir|Terrace|Ter|Parkway|Pkwy)\.?\b"#, 
                                with: "", 
                                options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !streetName.isEmpty {
            return "\(streetName) House"
        }
        
        return "My House"
    }
    
    /// Save address to persistent storage
    func saveAddress(_ address: Address) async throws {
        // Save to UserDefaults for quick access
        if let encoded = try? JSONEncoder().encode(address) {
            UserDefaults.standard.set(encoded, forKey: "confirmedHomeAddress")
        }
        
        // Save to LocationService
        try await locationService.confirmAddress(address)
        
        // Save to NotesService
        await saveAddressToNotes(address)
    }
    
    /// Save address as a note answer
    func saveAddressToNotes(_ address: Address) async {
        do {
            let notesStore = try await notesService.loadNotesStore()
            
            // Find the address question (supporting both old and new text)
            if let addressQuestion = notesStore.questions.first(where: { 
                $0.text == "Is this the right address?" || $0.text == "What's your home address?" 
            }) {
                try await notesService.saveOrUpdateNote(
                    for: addressQuestion.id,
                    answer: address.fullAddress,
                    metadata: [
                        "updated_via_conversation": "true",
                        "latitude": "\(address.coordinate.latitude)",
                        "longitude": "\(address.coordinate.longitude)"
                    ]
                )
            }
            
            // Also save the house name if we can generate it
            if let houseNameQuestion = notesStore.questions.first(where: { 
                $0.text == "What should I call this house?" 
            }) {
                // Only save if not already answered
                if notesStore.notes[houseNameQuestion.id] == nil {
                    let houseName = generateHouseNameFromStreet(address.street)
                    try await notesService.saveOrUpdateNote(
                        for: houseNameQuestion.id,
                        answer: houseName,
                        metadata: ["generated_from_address": "true"]
                    )
                }
            }
        } catch {
            print("Error saving address to notes: \(error)")
        }
    }
    
    /// Load saved address from storage
    func loadSavedAddress() -> Address? {
        guard let addressData = UserDefaults.standard.data(forKey: "confirmedHomeAddress"),
              let address = try? JSONDecoder().decode(Address.self, from: addressData) else {
            return nil
        }
        return address
    }
}

// MARK: - Error Types

enum AddressError: LocalizedError {
    case locationPermissionDenied
    case invalidAddressFormat
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "Location permission is required to detect your address"
        case .invalidAddressFormat:
            return "Invalid address format"
        case .saveFailed(let error):
            return "Failed to save address: \(error.localizedDescription)"
        }
    }
}
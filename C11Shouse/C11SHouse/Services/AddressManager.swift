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
        await MainActor.run {
            isDetectingAddress = true
        }
        defer {
            Task { @MainActor in
                isDetectingAddress = false
            }
        }
        
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
        // Try to get coordinates if we have a detected address
        let coordinate = detectedAddress?.coordinate
        return AddressParser.parseAddress(addressText, coordinate: coordinate)
    }
    
    /// Generate house name suggestion from address
    func generateHouseName(from addressText: String) -> String {
        return AddressParser.generateHouseNameFromAddress(addressText)
    }
    
    /// Generate house name from street component
    func generateHouseNameFromStreet(_ street: String) -> String {
        return AddressParser.generateHouseName(from: street)
    }
    
    /// Store detected address without marking question as answered
    func storeDetectedAddress(_ address: Address) async {
        // Only store in memory - do not persist to UserDefaults
        // Address should only be persisted through NotesService
        
        // Store in detectedAddress property
        await MainActor.run {
            detectedAddress = address
        }
        
        print("[AddressManager] Stored detected address in memory (not marked as answered): \(address.fullAddress)")
    }
    
    /// Save address to persistent storage
    func saveAddress(_ address: Address) async throws {
        // Do not save to UserDefaults - only persist through NotesService
        
        // Save to LocationService
        try await locationService.confirmAddress(address)
        
        // Save to NotesService (this is the only persistent storage)
        await saveAddressToNotes(address)
        
        // Update in-memory property
        await MainActor.run {
            detectedAddress = address
        }
        
        print("[AddressManager] User confirmed address, now saving as answered: \(address.fullAddress)")
    }
    
    /// Save address as a note answer
    func saveAddressToNotes(_ address: Address) async {
        print("[AddressManager] saveAddressToNotes called with address: \(address.fullAddress)")
        do {
            let notesStore = try await notesService.loadNotesStore()
            print("[AddressManager] Loaded notes store with \(notesStore.questions.count) questions")
            
            // Find the address question (supporting both old and new text)
            if let addressQuestion = notesStore.questions.first(where: { 
                $0.text == "Is this the right address?" || $0.text == "What's your home address?" 
            }) {
                print("[AddressManager] Found address question: \(addressQuestion.text)")
                try await notesService.saveOrUpdateNote(
                    for: addressQuestion.id,
                    answer: address.fullAddress,
                    metadata: [
                        "updated_via_conversation": "true",
                        "latitude": "\(address.coordinate.latitude)",
                        "longitude": "\(address.coordinate.longitude)"
                    ]
                )
                print("[AddressManager] Saved address note")
            } else {
                print("[AddressManager] Address question not found")
            }
            
            // Also save the house name if we can generate it
            if let houseNameQuestion = notesStore.questions.first(where: { 
                $0.text == "What should I call this house?" 
            }) {
                print("[AddressManager] Found house name question: \(houseNameQuestion.text)")
                // Only save if not already answered
                if notesStore.notes[houseNameQuestion.id] == nil {
                    let houseName = generateHouseNameFromStreet(address.street)
                    print("[AddressManager] Generated house name: \(houseName)")
                    try await notesService.saveOrUpdateNote(
                        for: houseNameQuestion.id,
                        answer: houseName,
                        metadata: ["generated_from_address": "true"]
                    )
                    print("[AddressManager] Saved house name note")
                } else {
                    print("[AddressManager] House name question already answered")
                }
            } else {
                print("[AddressManager] House name question not found")
            }
        } catch {
            print("Error saving address to notes: \(error)")
        }
    }
    
    /// Load saved address from storage
    func loadSavedAddress() async -> Address? {
        // Load from NotesService instead of UserDefaults
        do {
            let notesStore = try await notesService.loadNotesStore()
            
            // Find the address question
            if let addressQuestion = notesStore.questions.first(where: { 
                $0.text == "Is this the right address?" || $0.text == "What's your home address?" 
            }) {
                // Get the saved answer
                if let note = notesStore.notes[addressQuestion.id],
                   !note.answer.isEmpty {
                    // Parse the saved address text
                    return parseAddress(note.answer)
                }
            }
        } catch {
            print("[AddressManager] Error loading saved address: \(error)")
        }
        return nil
    }
    
    /// Load detected but unconfirmed address from storage
    func loadDetectedAddress() -> Address? {
        // Return the in-memory detected address
        // Do not persist detected addresses - they should only be saved when confirmed
        return detectedAddress
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
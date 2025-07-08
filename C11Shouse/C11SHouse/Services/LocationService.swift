/*
 * CONTEXT & PURPOSE:
 * LocationService provides location-based functionality including current location access,
 * geocoding for address lookup, and permission management. It abstracts Core Location
 * framework complexity and provides a clean async/await API for location operations.
 *
 * DECISION HISTORY:
 * - 2025-07-08: Initial implementation
 *   - Protocol-based design for testability
 *   - Combine publishers for reactive updates
 *   - async/await for geocoding operations
 *   - CLLocationManager wrapped with proper delegate handling
 *   - Permission management integrated
 *   - Address confirmation separated from lookup for flexibility
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Foundation
import CoreLocation
import Combine

// MARK: - Protocol

protocol LocationServiceProtocol {
    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
    
    func requestLocationPermission() async
    func getCurrentLocation() async throws -> CLLocation
    func lookupAddress(for location: CLLocation) async throws -> Address
    func confirmAddress(_ address: Address) async throws
}

// MARK: - Implementation

class LocationServiceImpl: NSObject, LocationServiceProtocol {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    private let currentLocationSubject = CurrentValueSubject<CLLocation?, Never>(nil)
    private let authorizationStatusSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.notDetermined)
    
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> {
        currentLocationSubject.eraseToAnyPublisher()
    }
    
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update every 100 meters
        
        // Update initial status
        authorizationStatusSubject.send(locationManager.authorizationStatus)
    }
    
    func requestLocationPermission() async {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        
        locationManager.requestWhenInUseAuthorization()
        
        // Wait for authorization change
        for await status in authorizationStatusPublisher.values {
            if status != .notDetermined {
                break
            }
        }
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        // Check authorization
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw LocationError.notAuthorized
        }
        
        // If we already have a location, return it immediately
        if let currentLocation = currentLocationSubject.value {
            return currentLocation
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation with timeout to prevent leaks
            self.locationContinuation = continuation
            
            // Set a timeout to prevent continuation leaks
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                if self.locationContinuation != nil {
                    self.locationContinuation?.resume(throwing: LocationError.locationFailed(NSError(domain: "LocationTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Location request timed out"])))
                    self.locationContinuation = nil
                }
            }
            
            locationManager.requestLocation()
        }
    }
    
    func lookupAddress(for location: CLLocation) async throws -> Address {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }
        
        guard let street = placemark.thoroughfare,
              let city = placemark.locality,
              let state = placemark.administrativeArea,
              let postalCode = placemark.postalCode,
              let country = placemark.country else {
            throw LocationError.incompleteAddress
        }
        
        let streetNumber = placemark.subThoroughfare ?? ""
        let fullStreet = streetNumber.isEmpty ? street : "\(streetNumber) \(street)"
        
        return Address(
            street: fullStreet,
            city: city,
            state: state,
            postalCode: postalCode,
            country: country,
            coordinate: Coordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        )
    }
    
    func confirmAddress(_ address: Address) async throws {
        // Store confirmed address
        UserDefaults.standard.set(try JSONEncoder().encode(address), forKey: "confirmedHomeAddress")
        
        // Start monitoring location updates if authorized
        if locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationServiceImpl: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocationSubject.send(location)
        
        // Complete any pending continuation
        if let continuation = locationContinuation {
            continuation.resume(returning: location)
            locationContinuation = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Complete any pending continuation with error
        if let continuation = locationContinuation {
            continuation.resume(throwing: LocationError.locationFailed(error))
            locationContinuation = nil
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatusSubject.send(manager.authorizationStatus)
    }
}

// MARK: - Errors

enum LocationError: LocalizedError {
    case notAuthorized
    case locationFailed(Error)
    case geocodingFailed
    case incompleteAddress
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location access not authorized"
        case .locationFailed(let error):
            return "Failed to get location: \(error.localizedDescription)"
        case .geocodingFailed:
            return "Failed to lookup address"
        case .incompleteAddress:
            return "Address information is incomplete"
        }
    }
}
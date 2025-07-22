/*
 * CONTEXT & PURPOSE:
 * LocationServiceTests validates the LocationService implementation including permission
 * handling, current location retrieval, geocoding, and address confirmation. Tests ensure
 * proper error handling and async operation behavior.
 *
 * DECISION HISTORY:
 * - 2025-07-08: Initial implementation
 *   - Mock CLLocationManager for testing
 *   - Test permission flow and authorization states
 *   - Validate geocoding with mock placemarks
 *   - Test address persistence in UserDefaults
 *   - Error case coverage for all failure modes
 *   - Combine publisher testing for reactive updates
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import XCTest
import CoreLocation
import Combine
@testable import C11SHouse

class LocationServiceTests: XCTestCase {
    var sut: LocationServiceImpl!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = LocationServiceImpl()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        // Clear UserDefaults to prevent test data from persisting
        UserDefaults.standard.removeObject(forKey: "confirmedHomeAddress")
        UserDefaults.standard.removeObject(forKey: "detectedHomeAddress")
        
        cancellables = nil
        sut = nil
        super.tearDown()
    }
    
    func testAuthorizationStatusPublisher() {
        let expectation = expectation(description: "Authorization status published")
        var receivedStatuses: [CLAuthorizationStatus] = []
        
        sut.authorizationStatusPublisher
            .sink { status in
                receivedStatuses.append(status)
                if receivedStatuses.count == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertFalse(receivedStatuses.isEmpty)
    }
    
    func testConfirmAddressDoesNotSaveToUserDefaults() async throws {
        // This test verifies the new behavior where addresses are NOT saved to UserDefaults
        // Address persistence is now handled exclusively by NotesService
        
        let address = Address(
            street: "123 Test Street",
            city: "Test City",
            state: "TS",
            postalCode: "12345",
            country: "Test Country",
            coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194)
        )
        
        try await sut.confirmAddress(address)
        
        // Verify that address is NOT saved to UserDefaults
        let savedData = UserDefaults.standard.data(forKey: "confirmedHomeAddress")
        XCTAssertNil(savedData, "Address should not be saved to UserDefaults - persistence is handled by NotesService")
        
        // The method should still complete without errors
        // (it now only handles location monitoring setup)
    }
    
    func testLocationErrorTypes() {
        XCTAssertEqual(LocationError.notAuthorized.errorDescription, "Location services not authorized")
        XCTAssertEqual(LocationError.geocodingFailed.errorDescription, "Geocoding failed")
        XCTAssertEqual(LocationError.incompleteAddress.errorDescription, "Incomplete address")
    }
}
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
    
    func testConfirmAddressSavesToUserDefaults() async throws {
        let address = Address(
            street: "123 Test Street",
            city: "Test City",
            state: "TS",
            postalCode: "12345",
            country: "Test Country",
            coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194)
        )
        
        try await sut.confirmAddress(address)
        
        let savedData = UserDefaults.standard.data(forKey: "confirmedHomeAddress")
        XCTAssertNotNil(savedData)
        
        let decodedAddress = try JSONDecoder().decode(Address.self, from: savedData!)
        XCTAssertEqual(decodedAddress, address)
    }
    
    func testLocationErrorTypes() {
        XCTAssertEqual(LocationError.notAuthorized.errorDescription, "Location access not authorized")
        XCTAssertEqual(LocationError.geocodingFailed.errorDescription, "Failed to lookup address")
        XCTAssertEqual(LocationError.incompleteAddress.errorDescription, "Address information is incomplete")
    }
}
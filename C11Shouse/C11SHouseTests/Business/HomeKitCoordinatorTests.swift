/*
 * CONTEXT & PURPOSE:
 * Tests for HomeKitCoordinator to ensure proper coordination between
 * HomeKitService and NotesService.
 *
 * DECISION HISTORY:
 * - 2025-07-23: Initial implementation
 *   - Tests for discovery flow
 *   - Authorization handling
 *   - Error cases
 *   - Note creation verification
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  HomeKitCoordinatorTests.swift
//  C11SHouseTests
//
//  Tests for HomeKit coordination logic
//

import XCTest
import Combine
@testable import C11SHouse

@MainActor
class HomeKitCoordinatorTests: XCTestCase {
    
    var coordinator: HomeKitCoordinator!
    var mockHomeKitService: MockHomeKitService!
    var mockNotesService: SharedMockNotesService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockHomeKitService = MockHomeKitService()
        mockNotesService = SharedMockNotesService()
        coordinator = HomeKitCoordinator(
            homeKitService: mockHomeKitService,
            notesService: mockNotesService
        )
        cancellables = []
    }
    
    override func tearDown() async throws {
        coordinator = nil
        mockHomeKitService = nil
        mockNotesService = nil
        cancellables = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Authorization Tests
    
    func testAuthorizationStatusUpdates() async {
        // Given
        let expectation = XCTestExpectation(description: "Authorization status updates")
        
        coordinator.$isAuthorized
            .dropFirst() // Skip initial value
            .sink { isAuthorized in
                XCTAssertTrue(isAuthorized)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        _ = await mockHomeKitService.requestAuthorization()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Discovery Tests
    
    func testSuccessfulDiscoveryAndSave() async {
        // Given
        mockHomeKitService.mockAuthorizationResult = true
        
        // When
        await coordinator.discoverAndSaveConfiguration()
        
        // Then
        XCTAssertTrue(mockHomeKitService.requestAuthorizationCalled)
        XCTAssertTrue(mockHomeKitService.discoverHomesCalled)
        XCTAssertTrue(mockHomeKitService.saveConfigurationAsNotesCalled)
        
        if case .completed(let summary) = coordinator.discoveryStatus {
            XCTAssertEqual(summary.homes.count, 1)
            XCTAssertEqual(summary.homes.first?.name, "Test Home")
        } else {
            XCTFail("Expected completed status")
        }
    }
    
    func testDiscoveryWithoutAuthorization() async {
        // Given
        mockHomeKitService.mockAuthorizationResult = false
        
        // When
        await coordinator.discoverAndSaveConfiguration()
        
        // Then
        XCTAssertTrue(mockHomeKitService.requestAuthorizationCalled)
        XCTAssertFalse(mockHomeKitService.discoverHomesCalled)
        
        if case .failed(let error) = coordinator.discoveryStatus {
            XCTAssertTrue(error is HomeKitError)
        } else {
            XCTFail("Expected failed status")
        }
    }
    
    func testDiscoveryWithNoHomes() async {
        // Given
        mockHomeKitService.mockAuthorizationResult = true
        mockHomeKitService.mockDiscoverySummary = HomeKitDiscoverySummary(
            homes: [],
            discoveredAt: Date()
        )
        
        // When
        await coordinator.discoverAndSaveConfiguration()
        
        // Then
        if case .failed(let error) = coordinator.discoveryStatus,
           case HomeKitError.noHomesFound = error {
            // Success
        } else {
            XCTFail("Expected noHomesFound error")
        }
    }
    
    func testDiscoveryError() async {
        // Given
        mockHomeKitService.mockAuthorizationResult = true
        mockHomeKitService.shouldThrowError = true
        
        // When
        await coordinator.discoverAndSaveConfiguration()
        
        // Then
        if case .failed(let error) = coordinator.discoveryStatus {
            XCTAssertNotNil(error)
        } else {
            XCTFail("Expected failed status")
        }
    }
    
    // MARK: - Status Management Tests
    
    func testStatusProgression() async {
        // Given
        let statusExpectation = XCTestExpectation(description: "Status progression")
        var receivedStatuses: [HomeKitDiscoveryStatus] = []
        
        coordinator.$discoveryStatus
            .sink { status in
                receivedStatuses.append(status)
                
                // Check for expected progression
                if receivedStatuses.count >= 4 {
                    statusExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await coordinator.discoverAndSaveConfiguration()
        
        // Then
        await fulfillment(of: [statusExpectation], timeout: 2.0)
        
        // Verify we went through the expected states
        XCTAssertTrue(receivedStatuses.contains { if case .checkingAuthorization = $0 { return true } else { return false } })
        XCTAssertTrue(receivedStatuses.contains { if case .discovering = $0 { return true } else { return false } })
        XCTAssertTrue(receivedStatuses.contains { if case .savingNotes = $0 { return true } else { return false } })
    }
    
    func testReset() async {
        // Given
        await coordinator.discoverAndSaveConfiguration()
        
        // When
        coordinator.reset()
        
        // Then
        if case .idle = coordinator.discoveryStatus {
            // Success
        } else {
            XCTFail("Expected idle status after reset")
        }
    }
    
    // MARK: - Helper Methods Tests
    
    func testHasHomeKitConfiguration() async {
        // Given - no homes initially
        mockHomeKitService.mockDiscoverySummary = nil
        
        // When/Then - should return false
        let hasConfigBefore = await coordinator.hasHomeKitConfiguration()
        XCTAssertFalse(hasConfigBefore)
        
        // Given - discover homes
        await coordinator.discoverAndSaveConfiguration()
        
        // When/Then - should return true
        let hasConfigAfter = await coordinator.hasHomeKitConfiguration()
        XCTAssertTrue(hasConfigAfter)
    }
    
    func testGetHomeByName() async {
        // Given
        await coordinator.discoverAndSaveConfiguration()
        
        // When
        let home = await coordinator.getHome(named: "Test Home")
        
        // Then
        XCTAssertNotNil(home)
        XCTAssertEqual(home?.name, "Test Home")
        
        // Test case insensitive
        let homeLowercase = await coordinator.getHome(named: "test home")
        XCTAssertNotNil(homeLowercase)
        
        // Test non-existent home
        let nonExistent = await coordinator.getHome(named: "Non-existent Home")
        XCTAssertNil(nonExistent)
    }
    
    func testRefreshConfiguration() async {
        // Given
        await coordinator.discoverAndSaveConfiguration()
        coordinator.reset()
        
        // When
        await coordinator.refreshConfiguration()
        
        // Then
        XCTAssertTrue(mockHomeKitService.discoverHomesCalled)
        if case .completed = coordinator.discoveryStatus {
            // Success
        } else {
            XCTFail("Expected completed status after refresh")
        }
    }
}
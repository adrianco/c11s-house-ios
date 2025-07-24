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
    
    // MARK: - Integration Test: Reading HomeKit Data into Notes
    
    func testReadHomeKitDataIntoNotes() async {
        // Given: Set up mock HomeKit data with various accessories and rooms
        let bedroom = HomeKitRoom(id: UUID(), name: "Master Bedroom")
        let livingRoom = HomeKitRoom(id: UUID(), name: "Living Room")
        let kitchen = HomeKitRoom(id: UUID(), name: "Kitchen")
        
        let bedroomLight = HomeKitAccessory(
            id: UUID(),
            name: "Bedroom Ceiling Light",
            roomId: bedroom.id,
            category: "Lights",
            manufacturer: "Philips",
            model: "Hue White",
            isReachable: true,
            isBridged: true,
            currentState: "On",
            services: ["Lightbulb"]
        )
        
        let smartTV = HomeKitAccessory(
            id: UUID(),
            name: "Living Room TV",
            roomId: livingRoom.id,
            category: "TVs",
            manufacturer: "LG",
            model: "OLED55",
            isReachable: true,
            isBridged: false,
            currentState: "Off",
            services: ["Television", "Speaker"]
        )
        
        let smartPlug = HomeKitAccessory(
            id: UUID(),
            name: "Coffee Maker Plug",
            roomId: kitchen.id,
            category: "Outlets",
            manufacturer: "TP-Link",
            model: "Kasa Smart",
            isReachable: true,
            isBridged: false,
            currentState: "On",
            services: ["Outlet", "Power Monitoring"]
        )
        
        let doorLock = HomeKitAccessory(
            id: UUID(),
            name: "Front Door Lock",
            roomId: nil, // Unassigned to any room
            category: "Locks",
            manufacturer: "August",
            model: "Smart Lock Pro",
            isReachable: false,
            isBridged: false,
            currentState: "Locked",
            services: ["Lock Management", "Battery"]
        )
        
        let home = HomeKitHome(
            id: UUID(),
            name: "My Smart Home",
            isPrimary: true,
            rooms: [bedroom, livingRoom, kitchen],
            accessories: [bedroomLight, smartTV, smartPlug, doorLock],
            createdAt: Date()
        )
        
        let discoverySummary = HomeKitDiscoverySummary(
            homes: [home],
            discoveredAt: Date()
        )
        
        // Configure mock service
        mockHomeKitService.mockAuthorizationResult = true
        mockHomeKitService.mockDiscoverySummary = discoverySummary
        
        // Create a custom mock notes service to track saved notes
        let customNotesService = MockHomeKitNotesService()
        let customCoordinator = HomeKitCoordinator(
            homeKitService: mockHomeKitService,
            notesService: customNotesService
        )
        
        // When: Discover and save HomeKit configuration
        await customCoordinator.discoverAndSaveConfiguration()
        
        // Then: Verify the discovery was successful
        if case .completed(let summary) = customCoordinator.discoveryStatus {
            XCTAssertEqual(summary.homes.count, 1)
            XCTAssertEqual(summary.totalRooms, 3)
            XCTAssertEqual(summary.totalAccessories, 4)
        } else {
            XCTFail("Expected completed status")
        }
        
        // Verify notes were saved
        XCTAssertTrue(mockHomeKitService.saveConfigurationAsNotesCalled)
        
        // Check that custom notes were created
        let savedNotes = customNotesService.savedCustomNotes
        
        // Should have: 1 summary + 3 rooms with accessories + 1 unassigned accessory = 5 notes
        XCTAssertEqual(savedNotes.count, 5)
        
        // Verify summary note
        let summaryNote = savedNotes.first { $0.category == "homekit_summary" }
        XCTAssertNotNil(summaryNote)
        XCTAssertTrue(summaryNote?.content.contains("My Smart Home") ?? false)
        XCTAssertTrue(summaryNote?.content.contains("primary home") ?? false)
        XCTAssertTrue(summaryNote?.content.contains("3") ?? false) // 3 rooms
        XCTAssertTrue(summaryNote?.content.contains("4") ?? false) // 4 accessories
        
        // Verify room notes contain correct accessories
        let bedroomNote = savedNotes.first { $0.title.contains("Master Bedroom") }
        XCTAssertNotNil(bedroomNote)
        XCTAssertTrue(bedroomNote?.content.contains("Bedroom Ceiling Light") ?? false)
        XCTAssertTrue(bedroomNote?.content.contains("Philips") ?? false)
        XCTAssertTrue(bedroomNote?.content.contains("✅") ?? false) // Reachable
        
        let livingRoomNote = savedNotes.first { $0.title.contains("Living Room") }
        XCTAssertNotNil(livingRoomNote)
        XCTAssertTrue(livingRoomNote?.content.contains("Living Room TV") ?? false)
        XCTAssertTrue(livingRoomNote?.content.contains("LG") ?? false)
        XCTAssertTrue(livingRoomNote?.content.contains("Television") ?? false)
        
        let kitchenNote = savedNotes.first { $0.title.contains("Kitchen") }
        XCTAssertNotNil(kitchenNote)
        XCTAssertTrue(kitchenNote?.content.contains("Coffee Maker Plug") ?? false)
        XCTAssertTrue(kitchenNote?.content.contains("TP-Link") ?? false)
        XCTAssertTrue(kitchenNote?.content.contains("Power Monitoring") ?? false)
        
        // Verify unassigned accessory note
        let lockNote = savedNotes.first { $0.title.contains("Front Door Lock") }
        XCTAssertNotNil(lockNote)
        XCTAssertEqual(lockNote?.category, "homekit_device")
        XCTAssertTrue(lockNote?.content.contains("August") ?? false)
        XCTAssertTrue(lockNote?.content.contains("❌") ?? false) // Unreachable
        XCTAssertTrue(lockNote?.content.contains("Lock Management") ?? false)
        
        // Test that we can retrieve the home by name
        let retrievedHome = await customCoordinator.getHome(named: "My Smart Home")
        XCTAssertNotNil(retrievedHome)
        XCTAssertEqual(retrievedHome?.accessories.count, 4)
        
        // Verify hasHomeKitConfiguration returns true
        let hasConfig = await customCoordinator.hasHomeKitConfiguration()
        XCTAssertTrue(hasConfig)
    }
}
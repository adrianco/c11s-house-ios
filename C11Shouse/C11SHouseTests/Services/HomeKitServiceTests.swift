/*
 * CONTEXT & PURPOSE:
 * Tests for HomeKitService to ensure proper discovery and note conversion functionality.
 * Since HomeKit requires actual device permissions and setup, these tests focus on
 * the data transformation and note generation logic.
 *
 * DECISION HISTORY:
 * - 2025-07-23: Initial implementation
 *   - Tests for model conversion and note generation
 *   - Mock HomeKit data for testing
 *   - Verify note format and content
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  HomeKitServiceTests.swift
//  C11SHouseTests
//
//  Tests for HomeKit service functionality
//

import XCTest
@testable import C11SHouse
import HomeKit
import Combine

// MARK: - Test Helpers for HomeKit Models
// Note: HomeKit models are structs with all let properties, so they have automatic memberwise initializers.
// We don't need to add custom initializers in extensions.

class HomeKitServiceTests: XCTestCase {
    
    var mockNotesService: MockNotesService!
    
    override func setUp() {
        super.setUp()
        mockNotesService = MockNotesService()
    }
    
    override func tearDown() {
        mockNotesService = nil
        super.tearDown()
    }
    
    // MARK: - Model Tests
    
    func testHomeKitHomeSummaryGeneration() {
        // Given
        let room1 = HomeKitRoom(id: UUID(), name: "Living Room")
        let room2 = HomeKitRoom(id: UUID(), name: "Kitchen")
        
        let accessory1 = HomeKitAccessory(
            id: UUID(),
            name: "Ceiling Light",
            roomId: room1.id,
            category: "Lights",
            manufacturer: "Philips",
            model: "Hue Go",
            isReachable: true,
            isBridged: true,
            currentState: "On",
            services: ["Lightbulb"]
        )
        
        let accessory2 = HomeKitAccessory(
            id: UUID(),
            name: "Smart Plug",
            roomId: room2.id,
            category: "Outlets",
            manufacturer: "Eve",
            model: "Energy",
            isReachable: true,
            isBridged: false,
            currentState: "Off",
            services: ["Outlet", "Power Monitoring"]
        )
        
        let home = HomeKitHome(
            id: UUID(),
            name: "My Home",
            isPrimary: true,
            rooms: [room1, room2],
            accessories: [accessory1, accessory2],
            createdAt: Date()
        )
        
        // When
        let summary = home.generateSummaryNote()
        
        // Then
        XCTAssertTrue(summary.contains("HomeKit Configuration for My Home"))
        XCTAssertTrue(summary.contains("This is your primary home"))
        XCTAssertTrue(summary.contains("Total Rooms: 2"))
        XCTAssertTrue(summary.contains("Total Accessories: 2"))
        XCTAssertTrue(summary.contains("Living Room (1 accessories)"))
        XCTAssertTrue(summary.contains("Kitchen (1 accessories)"))
        XCTAssertTrue(summary.contains("Lights: 1"))
        XCTAssertTrue(summary.contains("Outlets: 1"))
    }
    
    func testRoomNoteGeneration() {
        // Given
        let room = HomeKitRoom(id: UUID(), name: "Bedroom")
        let accessories = [
            HomeKitAccessory(
                id: UUID(),
                name: "Bedside Lamp",
                roomId: room.id,
                category: "Lights",
                manufacturer: "IKEA",
                model: "TRADFRI",
                isReachable: true,
                isBridged: false,
                currentState: "Brightness: 50%",
                services: ["Lightbulb"]
            ),
            HomeKitAccessory(
                id: UUID(),
                name: "Window Sensor",
                roomId: room.id,
                category: "Sensors",
                manufacturer: "Aqara",
                model: "Door and Window Sensor",
                isReachable: false,
                isBridged: true,
                currentState: nil as String?,
                services: ["Contact Sensor", "Battery"]
            )
        ]
        
        // When
        let note = room.generateNote(with: accessories)
        
        // Then
        XCTAssertTrue(note.contains("Room: Bedroom"))
        XCTAssertTrue(note.contains("Accessories (2)"))
        XCTAssertTrue(note.contains("Lights:"))
        XCTAssertTrue(note.contains("Bedside Lamp ✅ - Brightness: 50%"))
        XCTAssertTrue(note.contains("Sensors:"))
        XCTAssertTrue(note.contains("Window Sensor ❌ (unreachable)"))
    }
    
    func testAccessoryNoteGeneration() {
        // Given
        let accessory = HomeKitAccessory(
            id: UUID(),
            name: "Front Door Lock",
            roomId: nil as UUID?,
            category: "Locks",
            manufacturer: "August",
            model: "Smart Lock Pro",
            isReachable: true,
            isBridged: false,
            currentState: "Locked",
            services: ["Lock Management", "Battery"]
        )
        
        // When
        let note = accessory.generateNote()
        
        // Then
        XCTAssertTrue(note.contains("Front Door Lock"))
        XCTAssertTrue(note.contains("Type: Locks"))
        XCTAssertTrue(note.contains("Manufacturer: August"))
        XCTAssertTrue(note.contains("Model: Smart Lock Pro"))
        XCTAssertTrue(note.contains("Status: ✅ Reachable"))
        XCTAssertTrue(note.contains("Current State: Locked"))
        XCTAssertTrue(note.contains("Lock Management"))
        XCTAssertTrue(note.contains("Battery"))
    }
    
    func testDiscoverySummaryGeneration() {
        // Given
        let home = HomeKitHome(
            id: UUID(),
            name: "Test Home",
            isPrimary: false,
            rooms: [
                HomeKitRoom(id: UUID(), name: "Room 1"),
                HomeKitRoom(id: UUID(), name: "Room 2")
            ],
            accessories: [
                HomeKitAccessory(
                    id: UUID(),
                    name: "Device 1",
                    roomId: nil as UUID?,
                    category: "Other Accessories",
                    manufacturer: nil as String?,
                    model: nil as String?,
                    isReachable: true,
                    isBridged: false,
                    currentState: nil as String?,
                    services: []
                )
            ],
            createdAt: Date()
        )
        
        let summary = HomeKitDiscoverySummary(
            homes: [home],
            discoveredAt: Date()
        )
        
        // When
        let fullSummary = summary.generateFullSummary()
        
        // Then
        XCTAssertTrue(fullSummary.contains("HomeKit Discovery Summary"))
        XCTAssertTrue(fullSummary.contains("Found 1 home(s) with 2 rooms and 1 accessories"))
        XCTAssertTrue(fullSummary.contains("Test Home"))
        XCTAssertEqual(summary.totalRooms, 2)
        XCTAssertEqual(summary.totalAccessories, 1)
    }
    
    func testEmptyHomesSummary() {
        // Given
        let summary = HomeKitDiscoverySummary(homes: [], discoveredAt: Date())
        
        // When
        let fullSummary = summary.generateFullSummary()
        
        // Then
        XCTAssertTrue(fullSummary.contains("No HomeKit homes configured yet"))
        XCTAssertTrue(fullSummary.contains("Add homes and accessories in the Home app"))
    }
}

// MARK: - Mock NotesService

class MockNotesService: NotesServiceProtocol {
    var savedNotes: [(title: String, content: String, category: String)] = []
    
    var notesStorePublisher: AnyPublisher<NotesStoreData, Never> {
        Just(NotesStoreData(
            questions: [],
            notes: [:],
            version: 1
        )).eraseToAnyPublisher()
    }
    
    func loadNotesStore() async throws -> NotesStoreData {
        return NotesStoreData()
    }
    
    func saveNote(_ note: Note) async throws {
        // Not used in these tests
    }
    
    func updateNote(_ note: Note) async throws {
        // Not used in these tests
    }
    
    func deleteNote(for questionId: UUID) async throws {
        // Not used in these tests
    }
    
    func addQuestion(_ question: Question) async throws {
        // Not used in these tests
    }
    
    func deleteQuestion(_ questionId: UUID) async throws {
        // Not used in these tests
    }
    
    func resetToDefaults() async throws {
        // Not used in these tests
    }
    
    func clearAllData() async throws {
        savedNotes.removeAll()
    }
    
    func saveCustomNote(title: String, content: String, category: String) async {
        savedNotes.append((title: title, content: content, category: category))
    }
    
    // Additional protocol methods from extensions
    func getCurrentQuestion() async -> Question? {
        return nil
    }
    
    func areAllRequiredQuestionsAnswered() async -> Bool {
        return true
    }
    
    func saveOrUpdateNote(for questionId: UUID, answer: String, metadata: [String: String]? = nil) async throws {
        // Not used in these tests
    }
    
    func getNote(for questionId: UUID) async throws -> Note? {
        return nil
    }
    
    func getUnansweredQuestions() async throws -> [Question] {
        return []
    }
    
    func saveWeatherSummary(_ weather: Weather) async {
        // Not used in these tests
    }
    
    func saveHouseName(_ name: String) async {
        // Not used in these tests
    }
    
    func getHouseName() async -> String? {
        return nil
    }
}
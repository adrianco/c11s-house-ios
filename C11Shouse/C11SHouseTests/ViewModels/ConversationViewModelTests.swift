/*
 * CONTEXT & PURPOSE:
 * Comprehensive unit tests for ConversationViewModel covering all functionality:
 * - Note search and response generation
 * - HomeKit configuration announcement
 * - User input processing for various scenarios
 * - Room and device note creation workflows
 * - Message generation and state management
 *
 * DECISION HISTORY:
 * - 2025-07-25: Initial comprehensive test implementation
 *   - Tests all public methods and workflows
 *   - Covers note search functionality
 *   - Tests HomeKit integration
 *   - Verifies room/device note creation
 *   - Tests message handling and state updates
 *
 * FUTURE UPDATES:
 * - Add performance tests for large note collections
 * - Test concurrent operation handling
 * - Add stress tests for rapid input processing
 */

import XCTest
import Combine
import CoreLocation
@testable import C11SHouse

@MainActor
class ConversationViewModelTests: XCTestCase {
    // MARK: - Properties
    
    var sut: ConversationViewModel!
    var mockMessageStore: MockMessageStore!
    var mockStateManager: ConversationStateManager!
    var mockQuestionFlow: MockQuestionFlowCoordinator!
    var mockRecognizer: MockConversationRecognizer!
    fileprivate var mockServiceContainer: TestServiceContainer!
    var mockNotesService: SharedMockNotesService!
    fileprivate var mockHomeKitCoordinator: MockHomeKitCoordinator!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        cancellables = []
        
        // Initialize mocks
        mockMessageStore = MockMessageStore()
        mockNotesService = SharedMockNotesService()
        mockStateManager = ConversationStateManager(
            notesService: mockNotesService,
            ttsService: MockTTSService()
        )
        mockQuestionFlow = MockQuestionFlowCoordinator()
        mockRecognizer = MockConversationRecognizer()
        mockHomeKitCoordinator = MockHomeKitCoordinator()
        
        // Create service container with mocked services
        mockServiceContainer = TestServiceContainer(
            notesService: mockNotesService,
            homeKitCoordinator: mockHomeKitCoordinator
        )
        
        // Initialize SUT
        sut = ConversationViewModel(
            messageStore: mockMessageStore,
            stateManager: mockStateManager,
            questionFlow: mockQuestionFlow,
            recognizer: mockRecognizer,
            serviceContainer: mockServiceContainer
        )
    }
    
    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        mockServiceContainer = nil
        mockHomeKitCoordinator = nil
        mockNotesService = nil
        mockRecognizer = nil
        mockQuestionFlow = nil
        mockStateManager = nil
        mockMessageStore = nil
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "noteCreationState")
        UserDefaults.standard.removeObject(forKey: "currentRoomName")
        UserDefaults.standard.removeObject(forKey: "pendingRoomName")
        UserDefaults.standard.removeObject(forKey: "homeKitConfigurationAnnounced")
        
        try await super.tearDown()
    }
    
    // MARK: - Setup Tests
    
    func testSetupView_InitializesCorrectly() async {
        // Given
        let houseName = "My Smart House"
        mockNotesService.mockHouseName = houseName
        
        // When
        await sut.setupView()
        
        // Then
        XCTAssertEqual(sut.houseName, houseName)
        XCTAssertNotNil(mockQuestionFlow.conversationRecognizer)
        XCTAssertNotNil(mockQuestionFlow.addressSuggestionService)
        XCTAssertTrue(mockQuestionFlow.loadNextQuestionCalled)
        
        // Should have welcome message
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        XCTAssertEqual(mockMessageStore.messages.first?.content, "Hello! I'm your house consciousness. How can I help you today?")
        XCTAssertFalse(mockMessageStore.messages.first?.isFromUser ?? true)
    }
    
    func testSetupView_WithExistingMessages_DoesNotAddWelcome() async {
        // Given
        mockMessageStore.messages = [Message(content: "Existing", isFromUser: true, isVoice: false)]
        
        // When
        await sut.setupView()
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        XCTAssertEqual(mockMessageStore.messages.first?.content, "Existing")
    }
    
    // MARK: - HomeKit Configuration Tests
    
    func testCheckAndAnnounceHomeKitConfiguration_WithHomeKit() async {
        // Given
        mockHomeKitCoordinator.hasHomeKitConfigurationResult = true
        
        // Create HomeKit summary note
        let summaryQuestion = Question(
            text: "HomeKit Configuration Summary",
            category: .houseInfo,
            displayOrder: 100
        )
        let summaryNote = Note(
            questionId: summaryQuestion.id,
            answer: """
            Found 1 home configured in HomeKit:
            Home: My Smart Home
            Total Rooms: 3
            Total Accessories: 5
            
            Rooms:
            - Living Room (2 accessories)
            - Kitchen (2 accessories)
            - Bedroom (1 accessories)
            """
        )
        
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: [summaryQuestion],
            notes: [summaryQuestion.id: summaryNote],
            version: 1
        )
        
        // When
        await sut.setupView()
        
        // Then
        // Should have welcome message + HomeKit announcement
        XCTAssertEqual(mockMessageStore.messages.count, 2)
        
        let homeKitMessage = mockMessageStore.messages.last
        XCTAssertNotNil(homeKitMessage)
        XCTAssertTrue(homeKitMessage?.content.contains("HomeKit") ?? false)
        XCTAssertTrue(homeKitMessage?.content.contains("3 rooms") ?? false)
        XCTAssertTrue(homeKitMessage?.content.contains("5 devices") ?? false)
        
        // Should mark as announced
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "homeKitConfigurationAnnounced"))
    }
    
    func testCheckAndAnnounceHomeKitConfiguration_AlreadyAnnounced() async {
        // Given
        UserDefaults.standard.set(true, forKey: "homeKitConfigurationAnnounced")
        mockHomeKitCoordinator.hasHomeKitConfigurationResult = true
        
        // When
        await sut.setupView()
        
        // Then
        // Should only have welcome message
        XCTAssertEqual(mockMessageStore.messages.count, 1)
    }
    
    // MARK: - Note Search Tests
    
    func testSearchAndRespondWithNotes_FindsSingleMatch() async {
        // Given
        let livingRoomQuestion = Question(
            text: "Living Room",
            category: .other,
            displayOrder: 1000
        )
        let livingRoomNote = Note(
            questionId: livingRoomQuestion.id,
            answer: "The living room has a smart TV and Philips Hue lights.",
            metadata: ["type": "room"]
        )
        
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: [livingRoomQuestion],
            notes: [livingRoomQuestion.id: livingRoomNote],
            version: 1
        )
        
        // When
        await sut.processUserInput("What do you remember about the living room?", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("Here's what I remember about Living Room"))
        XCTAssertTrue(response.contains("smart TV"))
        XCTAssertTrue(response.contains("Philips Hue lights"))
    }
    
    func testSearchAndRespondWithNotes_FindsMultipleMatches() async {
        // Given
        let kitchenQuestion = Question(text: "Kitchen", category: .other, displayOrder: 1000)
        let kitchenNote = Note(
            questionId: kitchenQuestion.id,
            answer: "Kitchen has smart appliances",
            metadata: ["type": "room"]
        )
        
        let kitchenLightsQuestion = Question(text: "Kitchen Lights", category: .other, displayOrder: 1001)
        let kitchenLightsNote = Note(
            questionId: kitchenLightsQuestion.id,
            answer: "Dimmable LED lights in kitchen",
            metadata: ["type": "device"]
        )
        
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: [kitchenQuestion, kitchenLightsQuestion],
            notes: [
                kitchenQuestion.id: kitchenNote,
                kitchenLightsQuestion.id: kitchenLightsNote
            ],
            version: 1
        )
        
        // When
        await sut.processUserInput("search for kitchen notes", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("found 2 notes"))
        XCTAssertTrue(response.contains("Kitchen"))
        XCTAssertTrue(response.contains("Kitchen Lights"))
    }
    
    func testSearchAndRespondWithNotes_NoMatches() async {
        // Given
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: [],
            notes: [:],
            version: 1
        )
        
        // When
        await sut.processUserInput("what notes do you have about the garage?", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("don't have any notes"))
        XCTAssertTrue(response.contains("add room note"))
    }
    
    func testSearchAndRespondWithNotes_EmptySearchTerms_DoesNotReturnAll() async {
        // Given
        let livingRoomQuestion = Question(text: "Living Room", category: .other, displayOrder: 1000)
        let livingRoomNote = Note(questionId: livingRoomQuestion.id, answer: "Has a TV")
        
        let bedroomQuestion = Question(text: "Bedroom", category: .other, displayOrder: 1001)
        let bedroomNote = Note(questionId: bedroomQuestion.id, answer: "Has a bed")
        
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: [livingRoomQuestion, bedroomQuestion],
            notes: [
                livingRoomQuestion.id: livingRoomNote,
                bedroomQuestion.id: bedroomNote
            ],
            version: 1
        )
        
        // When - search with only stop words that get filtered out
        await sut.processUserInput("what about the", isMuted: true)
        
        // Then - should not return any notes since search terms are empty after filtering
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("don't have any notes") || !response.contains("Living Room"))
    }
    
    func testMightBeAskingAboutNote_DetectsNoteReference() async {
        // Given
        let bedroomQuestion = Question(text: "Master Bedroom", category: .other, displayOrder: 1000)
        let bedroomNote = Note(questionId: bedroomQuestion.id, answer: "King size bed")
        
        mockNotesService.mockNotesStore = NotesStoreData(
            questions: [bedroomQuestion],
            notes: [bedroomQuestion.id: bedroomNote],
            version: 1
        )
        
        // When
        await sut.processUserInput("bedroom temperature", isMuted: true)
        
        // Then
        // Should trigger note search since "bedroom" matches a note
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("Master Bedroom"))
    }
    
    // MARK: - Room Note Creation Tests
    
    func testHandleRoomNoteCreation_StartsWorkflow() async {
        // When
        await sut.processUserInput("add room note", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("What room would you like to add a note about?"))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "noteCreationState"), "creatingRoomNote")
    }
    
    func testHandleRoomNoteNameProvided_AsksForDetails() async {
        // Given
        UserDefaults.standard.set("creatingRoomNote", forKey: "noteCreationState")
        
        // When
        await sut.processUserInput("Master Bedroom", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("I'll create a note for the Master Bedroom"))
        XCTAssertTrue(response.contains("What would you like me to remember"))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "noteCreationState"), "awaitingRoomDetails")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "currentRoomName"), "Master Bedroom")
    }
    
    func testHandleRoomNoteDetailsProvided_SavesNote() async {
        // Given
        UserDefaults.standard.set("awaitingRoomDetails", forKey: "noteCreationState")
        UserDefaults.standard.set("Office", forKey: "currentRoomName")
        
        // When
        await sut.processUserInput("Standing desk with dual monitors and ergonomic chair", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("Perfect! I've saved that information about the Office"))
        
        // Verify note was saved
        XCTAssertEqual(mockNotesService.savedNotes.count, 1)
        let savedNote = mockNotesService.savedNotes.first
        XCTAssertEqual(savedNote?.answer, "Standing desk with dual monitors and ergonomic chair")
        XCTAssertEqual(savedNote?.metadata?["type"], "room")
        
        // Verify state was cleaned up
        XCTAssertNil(UserDefaults.standard.string(forKey: "noteCreationState"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "currentRoomName"))
    }
    
    // MARK: - Device Note Creation Tests
    
    func testHandleDeviceNoteCreation_StartsWorkflow() async {
        // When
        await sut.processUserInput("new device note", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("What device or appliance would you like to add a note about?"))
    }
    
    // MARK: - Question Flow Integration Tests
    
    func testProcessUserInput_WithCurrentQuestion_SavesAnswer() async {
        // Given
        let nameQuestion = Question(
            text: "What's your name?",
            category: .personal,
            displayOrder: 1
        )
        mockQuestionFlow.currentQuestion = nameQuestion
        
        // When
        await sut.processUserInput("John Doe", isMuted: true)
        
        // Then
        XCTAssertTrue(mockQuestionFlow.saveAnswerCalled)
        XCTAssertFalse(sut.isProcessing)
    }
    
    // MARK: - General Input Processing Tests
    
    func testProcessUserInput_GeneratesHouseResponse() async {
        // When
        await sut.processUserInput("Hello house!", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first
        XCTAssertNotNil(response)
        XCTAssertFalse(response?.isFromUser ?? true)
        XCTAssertTrue(response?.content.contains("Hello") ?? false)
    }
    
    func testProcessUserInput_UpdatesStateManagerTranscript() async {
        // Given
        let input = "Test input"
        
        // When
        await sut.processUserInput(input, isMuted: true)
        
        // Then
        XCTAssertEqual(mockStateManager.persistentTranscript, input)
    }
    
    func testProcessUserInput_SetsIsProcessing() async {
        // Given
        let expectation = XCTestExpectation(description: "Processing state changes")
        var processingStates: [Bool] = []
        
        sut.$isProcessing
            .sink { isProcessing in
                processingStates.append(isProcessing)
                if processingStates.count == 3 { // Initial false, true, false
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await sut.processUserInput("Test", isMuted: true)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(processingStates, [false, true, false])
    }
    
    // MARK: - House Thought Generation Tests
    
    func testGenerateHouseResponse_ForWeatherQuery() async {
        // When
        await sut.processUserInput("What's the weather like?", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("weather"))
    }
    
    func testGenerateHouseResponse_ForTemperatureQuery() async {
        // When
        await sut.processUserInput("Is it cold in here?", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("temperature") || response.contains("adjust"))
    }
    
    func testGenerateHouseResponse_ForHelpQuery() async {
        // When
        await sut.processUserInput("Can you help me?", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("help"))
        XCTAssertTrue(response.contains("managing your home") || response.contains("notes"))
    }
    
    func testGenerateHouseResponse_ForNoteQuery() async {
        // When
        await sut.processUserInput("How do I create notes?", isMuted: true)
        
        // Then
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        let response = mockMessageStore.messages.first?.content ?? ""
        XCTAssertTrue(response.contains("room note") || response.contains("device note"))
    }
    
    // MARK: - Voice/Mute Tests
    
    func testProcessUserInput_WhenNotMuted_SetsVoiceMessage() async {
        // When
        await sut.processUserInput("Hello", isMuted: false)
        
        // Then
        let message = mockMessageStore.messages.first
        XCTAssertTrue(message?.isVoice ?? false)
    }
    
    func testProcessUserInput_WhenMuted_SetsNonVoiceMessage() async {
        // When
        await sut.processUserInput("Hello", isMuted: true)
        
        // Then
        let message = mockMessageStore.messages.first
        XCTAssertFalse(message?.isVoice ?? true)
    }
}

// MARK: - Mock Classes

private class TestServiceContainer: ServiceContainer {
    let mockNotesService: SharedMockNotesService
    let mockHomeKitCoordinator: MockHomeKitCoordinator
    
    init(notesService: SharedMockNotesService, homeKitCoordinator: MockHomeKitCoordinator) {
        self.mockNotesService = notesService
        self.mockHomeKitCoordinator = homeKitCoordinator
        super.init(forTesting: true)
    }
    
    override var notesService: NotesServiceProtocol {
        return mockNotesService
    }
    
    override var homeKitCoordinator: HomeKitCoordinator {
        return mockHomeKitCoordinator
    }
    
    override var addressSuggestionService: AddressSuggestionService {
        let addressManager = SharedMockAddressManager(
            notesService: mockNotesService,
            locationService: MockLocationService()
        )
        let weatherCoordinator = WeatherCoordinator(
            weatherService: MockWeatherKitService(),
            notesService: mockNotesService,
            locationService: MockLocationService()
        )
        return AddressSuggestionService(
            addressManager: addressManager,
            locationService: MockLocationService(),
            weatherCoordinator: weatherCoordinator
        )
    }
    
    override var permissionManager: PermissionManager {
        let manager = PermissionManager()
        // Set permissions as granted for tests
        return manager
    }
    
    override var locationService: LocationServiceProtocol {
        return MockLocationService()
    }
}

private class MockHomeKitCoordinator: HomeKitCoordinator {
    var hasHomeKitConfigurationResult = false
    var hasHomeKitConfigurationCalled = false
    
    init() {
        super.init(
            homeKitService: MockHomeKitService(),
            notesService: SharedMockNotesService()
        )
    }
    
    override func hasHomeKitConfiguration() async -> Bool {
        hasHomeKitConfigurationCalled = true
        return hasHomeKitConfigurationResult
    }
}

// MockAddressManager and MockWeatherCoordinator are defined in other test files
// Use the shared implementations from TestMocks.swift instead
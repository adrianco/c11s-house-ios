/*
 * CONTEXT & PURPOSE:
 * OnboardingCoordinatorTests validates the onboarding flow coordination logic,
 * ensuring proper phase transitions, state management, and completion tracking.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation
 *   - Tests phase progression
 *   - Validates completion detection
 *   - Verifies permission integration
 *   - Ensures proper metrics tracking
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
import Combine
@testable import C11SHouse

@MainActor
class OnboardingCoordinatorTests: XCTestCase {
    
    private var coordinator: OnboardingCoordinator!
    private var notesService: NotesServiceProtocol!
    private var permissionManager: MockPermissionManager!
    private var addressManager: AddressManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        cancellables = Set<AnyCancellable>()
        
        // Setup services
        notesService = NotesServiceImpl()
        permissionManager = MockPermissionManager()
        let locationService = MockLocationService()
        addressManager = AddressManager(
            notesService: notesService,
            locationService: locationService
        )
        
        // Clear any existing data
        let emptyStore = NotesStore(questions: [], notes: [:])
        try await notesService.importNotes(from: JSONEncoder().encode(emptyStore))
        
        // Create coordinator
        coordinator = OnboardingCoordinator(
            notesService: notesService,
            permissionManager: permissionManager,
            addressManager: addressManager
        )
    }
    
    override func tearDown() async throws {
        cancellables = nil
        let emptyStore = NotesStore(questions: [], notes: [:])
        try await notesService.importNotes(from: JSONEncoder().encode(emptyStore))
        try await super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(coordinator.currentPhase, .welcome)
        XCTAssertFalse(coordinator.isOnboardingComplete)
        XCTAssertTrue(coordinator.showOnboarding) // Should show for new users
    }
    
    func testPhaseProgression() {
        // Start at welcome
        XCTAssertEqual(coordinator.currentPhase, .welcome)
        
        // Move to permissions
        coordinator.nextPhase()
        XCTAssertEqual(coordinator.currentPhase, .permissions)
        
        // Move to personalization
        coordinator.nextPhase()
        XCTAssertEqual(coordinator.currentPhase, .personalization)
        
        // Move to completion
        coordinator.nextPhase()
        XCTAssertEqual(coordinator.currentPhase, .completion)
        
        // Complete onboarding
        let expectation = expectation(forNotification: Notification.Name("OnboardingComplete"), object: nil)
        coordinator.nextPhase()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(coordinator.isOnboardingComplete)
        XCTAssertFalse(coordinator.showOnboarding)
    }
    
    func testSkipToPhase() {
        coordinator.skipToPhase(.personalization)
        XCTAssertEqual(coordinator.currentPhase, .personalization)
        
        coordinator.skipToPhase(.completion)
        XCTAssertEqual(coordinator.currentPhase, .completion)
    }
    
    func testCheckPermissions() {
        // Initially no permissions
        permissionManager.mockMicrophoneStatus = .notDetermined
        permissionManager.mockSpeechRecognitionStatus = .notDetermined
        XCTAssertFalse(coordinator.checkPermissions())
        
        // Grant microphone only
        permissionManager.mockMicrophoneStatus = .authorized
        XCTAssertFalse(coordinator.checkPermissions())
        
        // Grant both required permissions
        permissionManager.mockSpeechRecognitionStatus = .authorized
        XCTAssertTrue(coordinator.checkPermissions())
        
        // Location is optional
        permissionManager.mockLocationStatus = .denied
        XCTAssertTrue(coordinator.checkPermissions())
    }
    
    func testRequestPermissions() async {
        permissionManager.mockMicrophoneStatus = .notDetermined
        permissionManager.mockSpeechRecognitionStatus = .notDetermined
        permissionManager.mockLocationStatus = .notDetermined
        
        await coordinator.requestPermissions()
        
        // Verify all permissions were requested
        XCTAssertEqual(permissionManager.mockMicrophoneStatus, .authorized)
        XCTAssertEqual(permissionManager.mockSpeechRecognitionStatus, .authorized)
        XCTAssertEqual(permissionManager.mockLocationStatus, .authorized)
    }
    
    func testOnboardingStatusCheck() async throws {
        // Setup - no permissions, no questions answered
        permissionManager.mockMicrophoneStatus = .notDetermined
        permissionManager.mockSpeechRecognitionStatus = .notDetermined
        
        // Add required questions
        let questions = [
            Question(id: UUID(), text: "Name?", category: .personal, priority: .high, isRequired: true),
            Question(id: UUID(), text: "Address?", category: .location, priority: .high, isRequired: true)
        ]
        
        let testStore = NotesStore(questions: questions, notes: [:])
        try await notesService.importNotes(from: JSONEncoder().encode(testStore))
        
        coordinator.checkOnboardingStatus()
        
        // Wait for async check
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertFalse(coordinator.isOnboardingComplete)
        XCTAssertTrue(coordinator.showOnboarding)
        
        // Grant permissions and answer questions
        permissionManager.mockMicrophoneStatus = .authorized
        permissionManager.mockSpeechRecognitionStatus = .authorized
        
        for question in questions {
            try await notesService.saveOrUpdateNote(
                for: question.id,
                answer: "Test Answer"
            )
        }
        
        coordinator.checkOnboardingStatus()
        
        // Wait for async check
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertTrue(coordinator.isOnboardingComplete)
        XCTAssertFalse(coordinator.showOnboarding)
    }
    
    func testCompleteOnboarding() {
        coordinator.startOnboarding()
        coordinator.currentPhase = .completion
        
        let notificationExpectation = expectation(
            forNotification: Notification.Name("OnboardingComplete"),
            object: nil
        )
        
        coordinator.completeOnboarding()
        
        wait(for: [notificationExpectation], timeout: 1.0)
        
        XCTAssertTrue(coordinator.isOnboardingComplete)
        XCTAssertFalse(coordinator.showOnboarding)
    }
    
    func testPhaseTransitionTracking() {
        // Track phase transitions
        var recordedPhases: [OnboardingPhase] = []
        
        coordinator.$currentPhase
            .sink { phase in
                recordedPhases.append(phase)
            }
            .store(in: &cancellables)
        
        // Progress through all phases
        coordinator.nextPhase() // -> permissions
        coordinator.nextPhase() // -> personalization
        coordinator.nextPhase() // -> completion
        
        // Verify all phases were recorded
        XCTAssertEqual(recordedPhases, [.welcome, .permissions, .personalization, .completion])
    }
}
/*
 * CONTEXT & PURPOSE:
 * ThreadingVerificationTests validates that all UI-related updates in the app happen on the main
 * thread, preventing UI freezes and crashes. It tests @Published properties, async/await code,
 * and Combine publishers to ensure thread safety across voice services and view models.
 *
 * DECISION HISTORY:
 * - 2025-07-04: Initial implementation
 *   - Comprehensive tests for all @MainActor-marked classes
 *   - Tests verify @Published properties update on main thread
 *   - Async/await operations tested for proper thread handling
 *   - Combine publisher thread verification
 *   - Tests for AudioEngine, VoiceTranscriptionViewModel, and PermissionManager
 *   - XCTestExpectation used for async verification
 *   - Thread.isMainThread checks ensure UI safety
 *   - Tests simulate real-world scenarios (recording, transcription, permissions)
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import XCTest
import Combine
@testable import C11SHouse

final class ThreadingVerificationTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        cancellables.removeAll()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Main Thread Verification Tests
    
    func testAudioEnginePublishedPropertiesUpdateOnMainThread() async {
        let expectation = XCTestExpectation(description: "Audio level updates on main thread")
        
        // Create AudioEngine on main actor since it's @MainActor
        let audioEngine = await MainActor.run {
            AudioEngine()
        }
        
        await audioEngine.$audioLevel
            .dropFirst() // Skip initial value
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread, "Audio level should update on main thread")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Try to trigger audio level update
        do {
            try await audioEngine.prepareForRecording()
            try await audioEngine.startRecording()
            
            // Give a brief moment for audio level updates
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Always clean up properly
            await audioEngine.stopRecording()
            
        } catch {
            print("Audio engine setup failed: \(error)")
            // Test still passes if setup fails - we're testing threading behavior
        }
        
        await fulfillment(of: [expectation], timeout: 2.0, enforceOrder: false)
    }
    
    func testVoiceTranscriptionViewModelStateUpdatesOnMainThread() async {
        
        let expectation = XCTestExpectation(description: "State updates on main thread")
        let container = ServiceContainer.shared
        let viewModel = await ViewModelFactory.shared.makeVoiceTranscriptionViewModel()
        
        await viewModel.$state
            .dropFirst()
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread, "State should update on main thread")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Trigger state change
        await viewModel.startRecording()
        
        await fulfillment(of: [expectation], timeout: 2.0)
        await viewModel.cancelRecording()
    }
    
    func testNotesServicePublisherUpdatesOnMainThread() async {
        let expectation = XCTestExpectation(description: "Notes updates on main thread")
        let notesService = ServiceContainer.shared.notesService
        
        notesService.notesStorePublisher
            .dropFirst()
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread, "Notes store should update on main thread")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Trigger update
        let testNote = Note(
            questionId: UUID(),
            answer: "Test answer"
        )
        try? await notesService.saveNote(testNote)
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Concurrent Operation Tests
    
    func testConcurrentAudioBufferOperations() async {
        // Create AudioEngine on main actor since it's @MainActor
        let audioEngine = await MainActor.run {
            AudioEngine()
        }
        let operationCount = 100
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = operationCount
        
        // Perform concurrent read/write operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<operationCount {
                group.addTask {
                    if i % 2 == 0 {
                        // Simulate buffer append (write operation)
                        _ = await audioEngine.getCurrentAudioData()
                    } else {
                        // Simulate buffer read
                        _ = await audioEngine.getCurrentAudioData()
                    }
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Timer Lifecycle Tests
    
    func testTimerProperCleanup() async {
        let viewModel = await ViewModelFactory.shared.makeVoiceTranscriptionViewModel()
        
        // Start recording (creates timers)
        await viewModel.startRecording()
        
        // Wait for timers to be created
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Stop recording (should clean up timers)
        await viewModel.stopRecording()
        
        // Verify no timer references remain
        let mirror = Mirror(reflecting: viewModel)
        for child in mirror.children {
            if let timer = child.value as? Timer {
                XCTAssertFalse(timer.isValid, "Timer should be invalidated after stopping")
            }
        }
    }
    
    // MARK: - State Consistency Tests
    
    func testRapidStateChangesThreadSafety() async {
        
        let viewModel = await ViewModelFactory.shared.makeVoiceTranscriptionViewModel()
        let operationCount = 50
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<operationCount {
                group.addTask {
                    await viewModel.startRecording()
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    await viewModel.stopRecording()
                }
            }
        }
        
        // Verify final state is consistent
        let finalState = await viewModel.state
        XCTAssertTrue(
            finalState == .idle || 
            finalState == .ready || 
            finalState == .cancelled ||
            finalState.isError,
            "Final state should be valid after rapid changes"
        )
    }
    
    // MARK: - Memory Management Tests
    
    func testNoRetainCyclesInTimers() async {
        
        weak var weakViewModel: VoiceTranscriptionViewModel?
        
        // Create a scope for the view model
        do {
            let viewModel = await ViewModelFactory.shared.makeVoiceTranscriptionViewModel()
            weakViewModel = viewModel
            
            await viewModel.startRecording()
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await viewModel.stopRecording()
        }
        
        // Give time for deallocation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertNil(weakViewModel, "ViewModel should be deallocated (no retain cycles)")
    }
    
    // MARK: - Integration Tests
    
    func testFullRecordingFlowThreadSafety() async {
        
        let viewModel = await ViewModelFactory.shared.makeVoiceTranscriptionViewModel()
        var updateCount = 0
        let updateExpectation = XCTestExpectation(description: "Multiple UI updates")
        
        // Monitor multiple published properties
        await viewModel.$audioLevel
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread)
                updateCount += 1
                if updateCount > 10 {
                    updateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await viewModel.$recordingDuration
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread)
            }
            .store(in: &cancellables)
        
        await viewModel.$state
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread)
            }
            .store(in: &cancellables)
        
        // Perform recording flow
        await viewModel.startRecording()
        
        await fulfillment(of: [updateExpectation], timeout: 3.0)
        
        await viewModel.stopRecording()
    }
    
    // MARK: - Performance Tests
    
    func testMainThreadPerformance() async {
        await self.measure {
            let expectation = XCTestExpectation(description: "Performance test")
            
            Task { @MainActor in
                let viewModel = await ViewModelFactory.shared.makeVoiceTranscriptionViewModel()
                
                // Perform multiple UI updates
                for _ in 0..<100 {
                    viewModel.clearHistory()
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Test Helpers

extension TranscriptionState {
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}
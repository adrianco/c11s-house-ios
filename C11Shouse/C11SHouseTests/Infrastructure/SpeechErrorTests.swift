/*
 * CONTEXT & PURPOSE:
 * SpeechErrorTests validates the SpeechError enum functionality, ensuring proper
 * error mapping from NSError codes and correct behavior of helper properties.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation
 *   - Tests error code mapping
 *   - Validates isIgnorable logic
 *   - Verifies error descriptions
 *   - Ensures permission error detection
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import XCTest
@testable import C11SHouse

class SpeechErrorTests: XCTestCase {
    
    func testErrorCodeMapping() {
        // Test known error codes
        let noSpeechError = NSError(domain: "test", code: 1110, userInfo: nil)
        XCTAssertEqual(SpeechError(nsError: noSpeechError), .noSpeechDetected)
        
        let recordingError = NSError(domain: "test", code: 1101, userInfo: nil)
        if case .recordingError(let error) = SpeechError(nsError: recordingError) {
            XCTAssertEqual(error.code, 1101)
        } else {
            XCTFail("Expected recording error")
        }
        
        let cancelledError1 = NSError(domain: "test", code: 203, userInfo: nil)
        XCTAssertEqual(SpeechError(nsError: cancelledError1), .cancelled)
        
        let cancelledError2 = NSError(domain: "test", code: 216, userInfo: nil)
        XCTAssertEqual(SpeechError(nsError: cancelledError2), .cancelled)
        
        let cancelledError3 = NSError(domain: "test", code: 301, userInfo: nil)
        XCTAssertEqual(SpeechError(nsError: cancelledError3), .cancelled)
        
        let deviceError = NSError(domain: "test", code: 1700, userInfo: nil)
        XCTAssertEqual(SpeechError(nsError: deviceError), .deviceNotAvailable)
        
        // Test unknown error code
        let unknownError = NSError(domain: "test", code: 9999, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        if case .recognitionError(let message) = SpeechError(nsError: unknownError) {
            XCTAssertEqual(message, "Unknown error")
        } else {
            XCTFail("Expected recognition error")
        }
    }
    
    func testIsIgnorable() {
        XCTAssertTrue(SpeechError.noSpeechDetected.isIgnorable)
        XCTAssertTrue(SpeechError.cancelled.isIgnorable)
        
        let recordingError = NSError(domain: "test", code: 1101, userInfo: nil)
        XCTAssertTrue(SpeechError.recordingError(recordingError).isIgnorable)
        
        let otherRecordingError = NSError(domain: "test", code: 9999, userInfo: nil)
        XCTAssertFalse(SpeechError.recordingError(otherRecordingError).isIgnorable)
        
        XCTAssertFalse(SpeechError.deviceNotAvailable.isIgnorable)
        XCTAssertFalse(SpeechError.recognitionError("Error").isIgnorable)
        XCTAssertFalse(SpeechError.permissionDenied.isIgnorable)
        XCTAssertFalse(SpeechError.audioEngineError.isIgnorable)
    }
    
    func testErrorDescriptions() {
        XCTAssertEqual(
            SpeechError.noSpeechDetected.localizedDescription,
            "No speech was detected. Please try speaking again."
        )
        
        XCTAssertEqual(
            SpeechError.cancelled.localizedDescription,
            "Speech recognition was cancelled."
        )
        
        XCTAssertEqual(
            SpeechError.deviceNotAvailable.localizedDescription,
            "The audio device is not available."
        )
        
        XCTAssertEqual(
            SpeechError.permissionDenied.localizedDescription,
            "Microphone or speech recognition permission denied."
        )
        
        XCTAssertEqual(
            SpeechError.audioEngineError.localizedDescription,
            "Audio engine error. Please try again."
        )
        
        let testError = NSError(domain: "test", code: 1101, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        if case .recordingError(let error) = SpeechError.recordingError(testError) {
            XCTAssertTrue(SpeechError.recordingError(error).localizedDescription.contains("Test error"))
        }
    }
    
    func testIsPermissionError() {
        XCTAssertTrue(SpeechError.permissionDenied.isPermissionError)
        
        XCTAssertTrue(SpeechError.recognitionError("Permission denied").isPermissionError)
        XCTAssertTrue(SpeechError.recognitionError("Authorization required").isPermissionError)
        XCTAssertTrue(SpeechError.recognitionError("PERMISSION needed").isPermissionError)
        
        XCTAssertFalse(SpeechError.noSpeechDetected.isPermissionError)
        XCTAssertFalse(SpeechError.cancelled.isPermissionError)
        XCTAssertFalse(SpeechError.deviceNotAvailable.isPermissionError)
        XCTAssertFalse(SpeechError.audioEngineError.isPermissionError)
        XCTAssertFalse(SpeechError.recognitionError("Other error").isPermissionError)
    }
    
    func testEquality() {
        XCTAssertEqual(SpeechError.noSpeechDetected, SpeechError.noSpeechDetected)
        XCTAssertEqual(SpeechError.cancelled, SpeechError.cancelled)
        XCTAssertNotEqual(SpeechError.noSpeechDetected, SpeechError.cancelled)
        
        let error1 = NSError(domain: "test", code: 1101, userInfo: nil)
        let error2 = NSError(domain: "test", code: 1101, userInfo: nil)
        
        // Note: NSError equality is reference-based, so these won't be equal
        XCTAssertNotEqual(SpeechError.recordingError(error1), SpeechError.recordingError(error2))
    }
}
/*
 * CONTEXT & PURPOSE:
 * Unit tests for ErrorView and related error handling components to ensure
 * proper display of user-friendly errors with appropriate styling and behavior.
 *
 * DECISION HISTORY:
 * - 2025-07-15: Initial test implementation
 *   - Test error view rendering and behavior
 *   - Verify auto-dismiss functionality
 *   - Test user interaction callbacks
 *   - Validate error severity display
 *
 * FUTURE UPDATES:
 * - Add snapshot tests for visual consistency
 * - Test accessibility features
 */

import XCTest
import SwiftUI
// import ViewInspector // TODO: Add ViewInspector dependency to project
@testable import C11SHouse

class ErrorViewTests: XCTestCase {
    
    // MARK: - Error View Basic Tests
    
    func testErrorViewInitialization() throws {
        // Given
        let error = AppError.networkUnavailable
        var dismissCalled = false
        var retryCalled = false
        
        // When
        let view = ErrorView(
            error: error,
            onDismiss: { dismissCalled = true },
            onRetry: { retryCalled = true }
        )
        
        // Then
        XCTAssertEqual(view.error.userFriendlyTitle, "No Internet Connection")
        XCTAssertNotNil(view.onDismiss)
        XCTAssertNotNil(view.onRetry)
    }
    
    func testErrorViewWithDifferentSeverities() {
        // Test info severity
        let infoError = TestError.info
        let infoView = ErrorView(error: infoError)
        XCTAssertEqual(infoError.severity, .info)
        
        // Test warning severity
        let warningError = AppError.networkUnavailable
        let warningView = ErrorView(error: warningError)
        XCTAssertEqual(warningError.severity, .warning)
        
        // Test error severity
        let errorError = AppError.locationAccessDenied
        let errorView = ErrorView(error: errorError)
        XCTAssertEqual(errorError.severity, .error)
        
        // Test critical severity
        let criticalError = AppError.dataCorrupted
        let criticalView = ErrorView(error: criticalError)
        XCTAssertEqual(criticalError.severity, .critical)
    }
    
    // MARK: - User Friendly Error Tests
    
    func testAppErrorUserFriendlyMessages() {
        // Test each error type
        let testCases: [(AppError, String, String)] = [
            (.networkUnavailable, "No Internet Connection", "Please check your internet connection and try again."),
            (.locationAccessDenied, "Location Access Required", "This app needs access to your location to provide weather information."),
            (.microphoneAccessDenied, "Microphone Access Required", "This app needs access to your microphone for voice commands."),
            (.weatherServiceUnavailable, "Weather Service Unavailable", "The weather service is temporarily unavailable."),
            (.voiceRecognitionFailed, "Voice Recognition Failed", "We couldn't understand your voice command."),
            (.dataCorrupted, "Data Error", "There was a problem loading your data.")
        ]
        
        for (error, expectedTitle, expectedMessage) in testCases {
            XCTAssertEqual(error.userFriendlyTitle, expectedTitle)
            XCTAssertEqual(error.userFriendlyMessage, expectedMessage)
            XCTAssertFalse(error.recoverySuggestions.isEmpty)
            XCTAssertNotNil(error.errorCode)
        }
    }
    
    func testErrorSeverityProperties() {
        // Test severity icon names
        XCTAssertEqual(ErrorSeverity.info.iconSystemName, "info.circle")
        XCTAssertEqual(ErrorSeverity.warning.iconSystemName, "exclamationmark.triangle")
        XCTAssertEqual(ErrorSeverity.error.iconSystemName, "xmark.circle")
        XCTAssertEqual(ErrorSeverity.critical.iconSystemName, "exclamationmark.octagon")
        
        // Test severity colors
        XCTAssertEqual(ErrorSeverity.info.tintColor, "blue")
        XCTAssertEqual(ErrorSeverity.warning.tintColor, "orange")
        XCTAssertEqual(ErrorSeverity.error.tintColor, "red")
        XCTAssertEqual(ErrorSeverity.critical.tintColor, "red")
    }
    
    func testAutoDissmissProperty() {
        // Info and warning should auto-dismiss
        XCTAssertTrue(AppError.voiceRecognitionFailed.shouldAutoDismiss)
        XCTAssertTrue(AppError.networkUnavailable.shouldAutoDismiss)
        
        // Error and critical should not auto-dismiss
        XCTAssertFalse(AppError.locationAccessDenied.shouldAutoDismiss)
        XCTAssertFalse(AppError.dataCorrupted.shouldAutoDismiss)
    }
    
    func testRecoverySuggestions() {
        // Network error suggestions
        let networkError = AppError.networkUnavailable
        XCTAssertEqual(networkError.recoverySuggestions.count, 3)
        XCTAssertTrue(networkError.recoverySuggestions.contains("Check your Wi-Fi or cellular connection"))
        
        // Location error suggestions
        let locationError = AppError.locationAccessDenied
        XCTAssertEqual(locationError.recoverySuggestions.count, 3)
        XCTAssertTrue(locationError.recoverySuggestions.contains("Open Settings > Privacy > Location Services"))
        
        // Voice recognition error suggestions
        let voiceError = AppError.voiceRecognitionFailed
        XCTAssertEqual(voiceError.recoverySuggestions.count, 3)
        XCTAssertTrue(voiceError.recoverySuggestions.contains("Speak clearly and try again"))
    }
    
    func testErrorCodes() {
        XCTAssertEqual(AppError.networkUnavailable.errorCode, "NET-001")
        XCTAssertEqual(AppError.locationAccessDenied.errorCode, "LOC-001")
        XCTAssertEqual(AppError.microphoneAccessDenied.errorCode, "MIC-001")
        XCTAssertEqual(AppError.weatherServiceUnavailable.errorCode, "WTH-001")
        XCTAssertEqual(AppError.voiceRecognitionFailed.errorCode, "VOC-001")
        XCTAssertEqual(AppError.dataCorrupted.errorCode, "DAT-001")
        XCTAssertEqual(AppError.unknown(TestError.generic).errorCode, "UNK-001")
    }
    
    // MARK: - Error Extension Tests
    
    func testErrorToUserFriendlyConversion() {
        // Test converting a UserFriendlyError
        let userFriendlyError = AppError.networkUnavailable
        let converted = userFriendlyError.asUserFriendlyError
        XCTAssertTrue(converted is AppError)
        
        // Test converting a non-UserFriendlyError
        let genericError = TestError.generic
        let convertedGeneric = genericError.asUserFriendlyError
        if case AppError.unknown(let wrappedError) = convertedGeneric {
            XCTAssertTrue(wrappedError is TestError)
        } else {
            XCTFail("Expected AppError.unknown")
        }
    }
    
    // MARK: - Full Screen Error View Tests
    
    func testFullScreenErrorViewInitialization() {
        // Given
        let error = AppError.dataCorrupted
        var retryCalled = false
        var dismissCalled = false
        
        // When
        let view = FullScreenErrorView(
            error: error,
            onRetry: { retryCalled = true },
            onDismiss: { dismissCalled = true }
        )
        
        // Then
        XCTAssertEqual(view.error.userFriendlyTitle, "Data Error")
        XCTAssertNotNil(view.onRetry)
        XCTAssertNotNil(view.onDismiss)
    }
    
    // MARK: - Error Overlay Modifier Tests
    
    func testErrorOverlayModifier() {
        // Given
        var error: UserFriendlyError? = AppError.networkUnavailable
        var retryCalled = false
        
        // When
        let modifier = ErrorOverlay(
            error: .constant(error),
            onRetry: { retryCalled = true }
        )
        
        // Then
        XCTAssertNotNil(modifier.error)
    }
}

// MARK: - Test Helpers

private enum TestError: Error, UserFriendlyError {
    case info
    case generic
    
    var userFriendlyTitle: String {
        switch self {
        case .info:
            return "Information"
        case .generic:
            return "Test Error"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .info:
            return "This is an informational message"
        case .generic:
            return "This is a test error"
        }
    }
    
    var recoverySuggestions: [String] {
        ["Try again", "Contact support"]
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .info:
            return .info
        case .generic:
            return .error
        }
    }
}
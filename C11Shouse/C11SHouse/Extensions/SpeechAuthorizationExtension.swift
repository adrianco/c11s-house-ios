/*
 * CONTEXT & PURPOSE:
 * Extension for SFSpeechRecognizerAuthorizationStatus to provide human-readable
 * descriptions. This was extracted from ConversationView to reduce its complexity
 * and provide a reusable utility for speech authorization status display.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation
 *   - Extracted from ConversationView as part of refactoring effort
 *   - Provides localized string representation of authorization states
 *   - Handles all known cases plus unknown default
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import Speech

extension SFSpeechRecognizerAuthorizationStatus {
    /// Returns a human-readable description of the authorization status
    var localizedDescription: String {
        switch self {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
}
/*
 * CONTEXT & PURPOSE:
 * Demo utility to demonstrate OnboardingLogger functionality.
 * This can be used to test the logging system and see how logs appear
 * in the Xcode console.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Created for testing and demonstrating logging capabilities
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation

/// Demo class to show OnboardingLogger functionality
class OnboardingLoggerDemo {
    
    /// Run a demo of the logging system
    static func runDemo() {
        print("\n🎯 Starting OnboardingLogger Demo...\n")
        
        // Start a new session
        OnboardingLogger.shared.startSession()
        
        // Simulate Welcome Phase
        simulateWelcomePhase()
        
        // Simulate Permissions Phase
        simulatePermissionsPhase()
        
        // Simulate Personalization Phase
        simulatePersonalizationPhase()
        
        // Simulate Tutorial Phase
        simulateTutorialPhase()
        
        // End session
        OnboardingLogger.shared.endSession(completed: true)
        
        // Print copyable log
        print("\n📋 COPYABLE LOG:\n")
        print(OnboardingLogger.shared.getCopyableLog())
    }
    
    private static func simulateWelcomePhase() {
        // Phase transition
        OnboardingLogger.shared.logPhaseTransition(from: nil, to: "welcome")
        
        // User views the welcome screen
        OnboardingLogger.shared.logUserAction("view_appeared", phase: "welcome")
        
        // Wait a bit (simulate user reading)
        Thread.sleep(forTimeInterval: 2.0)
        
        // User taps begin setup
        OnboardingLogger.shared.logButtonTap("begin_setup", phase: "welcome")
    }
    
    private static func simulatePermissionsPhase() {
        // Phase transition
        OnboardingLogger.shared.logPhaseTransition(from: "welcome", to: "permissions")
        
        // User views permissions
        OnboardingLogger.shared.logUserAction("view_appeared", phase: "permissions")
        
        // User grants permissions
        OnboardingLogger.shared.logButtonTap("grant_permissions", phase: "permissions")
        
        // Simulate permission requests
        OnboardingLogger.shared.logPermissionRequest("microphone", granted: true)
        OnboardingLogger.shared.logPermissionRequest("speech_recognition", granted: true)
        OnboardingLogger.shared.logPermissionRequest("location", granted: false)
        
        // User views location explanation
        OnboardingLogger.shared.logUserAction("location_explanation_viewed", phase: "permissions")
        
        // User skips location
        OnboardingLogger.shared.logButtonTap("skip_location", phase: "permissions")
        OnboardingLogger.shared.logUserAction("location_permission_skipped", phase: "permissions")
        
        // Continue
        OnboardingLogger.shared.logButtonTap("continue", phase: "permissions")
    }
    
    private static func simulatePersonalizationPhase() {
        // Phase transition
        OnboardingLogger.shared.logPhaseTransition(from: "permissions", to: "personalization")
        
        // User views personalization
        OnboardingLogger.shared.logUserAction("view_appeared", phase: "personalization")
        
        // Start conversation
        OnboardingLogger.shared.logButtonTap("start_conversation", phase: "personalization")
        
        // Simulate address detection (failed due to no location permission)
        OnboardingLogger.shared.logServiceCall("address_detection", phase: "personalization", success: false)
        OnboardingLogger.shared.logError(
            NSError(domain: "Location", code: 1, userInfo: [NSLocalizedDescriptionKey: "Location permission denied"]),
            phase: "personalization",
            recovery: "User will enter address manually"
        )
        
        // User enters address via voice
        OnboardingLogger.shared.logUserAction("recording_started", phase: "personalization")
        Thread.sleep(forTimeInterval: 3.0)
        OnboardingLogger.shared.logVoiceInput(
            phase: "personalization",
            duration: 3.0,
            transcript: "123 Main Street, San Francisco, CA 94105"
        )
        OnboardingLogger.shared.logUserAction("recording_stopped", phase: "personalization")
        
        // Confirm answer
        OnboardingLogger.shared.logButtonTap("confirm_answer", phase: "personalization")
        OnboardingLogger.shared.logUserAction("answer_confirmed", phase: "personalization", details: [
            "question": "What's your home address?",
            "answer_length": 38
        ])
        
        // House name suggestion
        OnboardingLogger.shared.logHouseNameSuggestion(suggested: "Main House", accepted: false)
        
        // User provides custom name
        OnboardingLogger.shared.logUserAction("recording_started", phase: "personalization")
        OnboardingLogger.shared.logVoiceInput(
            phase: "personalization",
            duration: 2.0,
            transcript: "The Smart Castle"
        )
        OnboardingLogger.shared.logButtonTap("confirm_answer", phase: "personalization")
        OnboardingLogger.shared.logHouseNameSuggestion(suggested: "The Smart Castle", accepted: true)
        
        // User name
        OnboardingLogger.shared.logTextInput("user_name", phase: "personalization", length: 10)
        OnboardingLogger.shared.logButtonTap("confirm_answer", phase: "personalization")
    }
    
    private static func simulateTutorialPhase() {
        // Phase transition
        OnboardingLogger.shared.logPhaseTransition(from: "personalization", to: "tutorial")
        
        // Tutorial steps
        let steps = ["intro", "roomNoteIntro", "roomNoteCreation", "deviceNoteIntro", "deviceNoteCreation", "completion"]
        
        for (index, step) in steps.enumerated() {
            OnboardingLogger.shared.logUserAction("tutorial_step", phase: "tutorial", details: ["step": step])
            
            if step == "roomNoteCreation" {
                // Create room note
                OnboardingLogger.shared.logTextInput("room_name", phase: "tutorial", length: 11)
                OnboardingLogger.shared.logTextInput("room_details", phase: "tutorial", length: 45)
                OnboardingLogger.shared.logButtonTap("Save & Continue", phase: "tutorial")
                OnboardingLogger.shared.logFeatureUsage("room_note_created", phase: "tutorial", details: [
                    "room_name": "Living Room",
                    "content_length": 45
                ])
            } else if step == "deviceNoteCreation" {
                // Skip device note
                OnboardingLogger.shared.logButtonTap("Skip", phase: "tutorial")
            } else if step == "completion" {
                // Complete tutorial
                OnboardingLogger.shared.logUserAction("tutorial_completed", phase: "tutorial", details: [
                    "room_note_created": true,
                    "device_note_created": false
                ])
                OnboardingLogger.shared.logButtonTap("Start Using C11S House", phase: "tutorial")
            } else if index < steps.count - 1 {
                // Continue to next step
                OnboardingLogger.shared.logButtonTap("Continue", phase: "tutorial")
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Complete onboarding
        OnboardingLogger.shared.logUserAction("onboarding_complete", phase: "tutorial")
    }
}
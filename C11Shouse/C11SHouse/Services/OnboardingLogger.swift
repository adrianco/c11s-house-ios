/*
 * CONTEXT & PURPOSE:
 * OnboardingLogger provides comprehensive logging for the onboarding flow.
 * It tracks user behavior, phase transitions, timing, errors, and feature usage
 * using OSLog for better Xcode console integration. Logs are structured to be
 * easily copyable and analyzable.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Initial implementation for onboarding flow logging
 *   - Uses OSLog for better Xcode console integration
 *   - Structured logging with categories and subsystems
 *   - Timing measurements for each phase
 *   - User action tracking
 *   - Error tracking with recovery paths
 *   - Summary generation for easy copying
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import Foundation
import OSLog

/// Onboarding logger for tracking user behavior and flow metrics
public class OnboardingLogger {
    
    // MARK: - Properties
    
    /// Shared instance for global access
    static let shared = OnboardingLogger()
    
    /// OSLog subsystem for onboarding
    private let subsystem = "com.c11s.house.onboarding"
    
    /// Different log categories
    private let phaseLog: Logger
    private let userActionLog: Logger
    private let featureLog: Logger
    private let errorLog: Logger
    private let timingLog: Logger
    
    /// Session tracking
    private var sessionId: String
    private var sessionStartTime: Date
    private var phaseStartTimes: [String: Date] = [:]
    private var phaseDurations: [String: TimeInterval] = [:]
    private var actionHistory: [OnboardingAction] = []
    
    // MARK: - Types
    
    /// Represents an onboarding action
    struct OnboardingAction {
        let timestamp: Date
        let phase: String
        let action: String
        let details: [String: Any]?
        
        var formattedLog: String {
            let detailsString = details?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? ""
            return "[\(timestamp.formatted())] \(phase) - \(action)\(detailsString.isEmpty ? "" : " - \(detailsString)")"
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Initialize loggers with different categories
        self.phaseLog = Logger(subsystem: subsystem, category: "phase")
        self.userActionLog = Logger(subsystem: subsystem, category: "action")
        self.featureLog = Logger(subsystem: subsystem, category: "feature")
        self.errorLog = Logger(subsystem: subsystem, category: "error")
        self.timingLog = Logger(subsystem: subsystem, category: "timing")
        
        // Initialize session
        self.sessionId = UUID().uuidString
        self.sessionStartTime = Date()
    }
    
    // MARK: - Session Management
    
    /// Start a new onboarding session
    public func startSession() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        phaseStartTimes.removeAll()
        phaseDurations.removeAll()
        actionHistory.removeAll()
        
        phaseLog.info("🚀 ONBOARDING SESSION STARTED - ID: \(self.sessionId)")
        phaseLog.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    /// End the current onboarding session
    public func endSession(completed: Bool) {
        let totalDuration = Date().timeIntervalSince(sessionStartTime)
        
        phaseLog.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        phaseLog.info("🏁 ONBOARDING SESSION ENDED - ID: \(self.sessionId)")
        phaseLog.info("Status: \(completed ? "✅ COMPLETED" : "❌ ABANDONED")")
        phaseLog.info("Total Duration: \(self.formatDuration(totalDuration))")
        
        // Generate and log summary
        generateSummary()
    }
    
    // MARK: - Phase Tracking
    
    /// Log phase transition
    public func logPhaseTransition(from oldPhase: String?, to newPhase: String) {
        // End timing for previous phase
        if let oldPhase = oldPhase {
            endPhase(oldPhase)
        }
        
        // Start timing for new phase
        phaseStartTimes[newPhase] = Date()
        
        phaseLog.notice("📍 PHASE TRANSITION: \(oldPhase ?? "Start") → \(newPhase)")
        
        // Log action
        recordAction(
            phase: newPhase,
            action: "phase_started",
            details: ["previous_phase": oldPhase ?? "none"]
        )
    }
    
    /// End a phase and record its duration
    private func endPhase(_ phase: String) {
        guard let startTime = phaseStartTimes[phase] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        phaseDurations[phase] = duration
        
        timingLog.info("⏱️ Phase '\(phase)' completed in \(self.formatDuration(duration))")
    }
    
    // MARK: - User Actions
    
    /// Log a user action
    public func logUserAction(_ action: String, phase: String, details: [String: Any]? = nil) {
        userActionLog.notice("👆 USER ACTION: \(action) in \(phase)")
        
        if let details = details {
            let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            userActionLog.debug("   Details: \(detailsString)")
        }
        
        recordAction(phase: phase, action: action, details: details)
    }
    
    /// Log button tap
    public func logButtonTap(_ buttonName: String, phase: String) {
        logUserAction("button_tap", phase: phase, details: ["button": buttonName])
    }
    
    /// Log text input
    public func logTextInput(_ fieldName: String, phase: String, length: Int) {
        logUserAction("text_input", phase: phase, details: [
            "field": fieldName,
            "length": length
        ])
    }
    
    /// Log voice input
    public func logVoiceInput(phase: String, duration: TimeInterval, transcript: String) {
        logUserAction("voice_input", phase: phase, details: [
            "duration": formatDuration(duration),
            "transcript_length": transcript.count,
            "transcript_preview": String(transcript.prefix(50))
        ])
    }
    
    // MARK: - Feature Usage
    
    /// Log feature usage
    public func logFeatureUsage(_ feature: String, phase: String, details: [String: Any]? = nil) {
        featureLog.info("✨ FEATURE USED: \(feature) in \(phase)")
        
        if let details = details {
            let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            featureLog.debug("   Details: \(detailsString)")
        }
        
        recordAction(phase: phase, action: "feature_\(feature)", details: details)
    }
    
    /// Log permission request
    public func logPermissionRequest(_ permission: String, granted: Bool) {
        logFeatureUsage("permission_request", phase: "permissions", details: [
            "permission": permission,
            "granted": granted
        ])
    }
    
    /// Log address suggestion
    public func logAddressSuggestion(suggested: String, accepted: Bool) {
        logFeatureUsage("address_suggestion", phase: "personalization", details: [
            "suggested": suggested,
            "accepted": accepted
        ])
    }
    
    /// Log house name suggestion
    public func logHouseNameSuggestion(suggested: String, accepted: Bool) {
        logFeatureUsage("house_name_suggestion", phase: "personalization", details: [
            "suggested": suggested,
            "accepted": accepted
        ])
    }
    
    // MARK: - Error Tracking
    
    /// Log error with recovery path
    public func logError(_ error: Error, phase: String, recovery: String? = nil) {
        errorLog.error("❌ ERROR in \(phase): \(error.localizedDescription)")
        
        if let recovery = recovery {
            errorLog.info("   Recovery: \(recovery)")
        }
        
        recordAction(phase: phase, action: "error", details: [
            "error": error.localizedDescription,
            "recovery": recovery ?? "none"
        ])
    }
    
    /// Log warning
    public func logWarning(_ message: String, phase: String) {
        errorLog.warning("⚠️ WARNING in \(phase): \(message)")
        
        recordAction(phase: phase, action: "warning", details: ["message": message])
    }
    
    // MARK: - Service Calls
    
    /// Log service call
    public func logServiceCall(_ service: String, phase: String, success: Bool, duration: TimeInterval? = nil) {
        let status = success ? "✅ SUCCESS" : "❌ FAILED"
        userActionLog.info("🔄 SERVICE CALL: \(service) - \(status)")
        
        var details: [String: Any] = ["service": service, "success": success]
        if let duration = duration {
            details["duration"] = formatDuration(duration)
        }
        
        recordAction(phase: phase, action: "service_call", details: details)
    }
    
    // MARK: - Summary Generation
    
    /// Generate a copyable summary of the onboarding session
    public func generateSummary() {
        let summary = """
        
        ╔════════════════════════════════════════════════════════════════╗
        ║                    ONBOARDING SESSION SUMMARY                   ║
        ╠════════════════════════════════════════════════════════════════╣
        ║ Session ID: \(sessionId)
        ║ Start Time: \(sessionStartTime.formatted())
        ║ Total Duration: \(formatDuration(Date().timeIntervalSince(sessionStartTime)))
        ║ Phases Completed: \(phaseDurations.count)
        ╠════════════════════════════════════════════════════════════════╣
        ║                         PHASE TIMINGS                           ║
        ╠════════════════════════════════════════════════════════════════╣
        \(formatPhaseDurations())
        ╠════════════════════════════════════════════════════════════════╣
        ║                         USER ACTIONS                            ║
        ╠════════════════════════════════════════════════════════════════╣
        \(formatActionSummary())
        ╠════════════════════════════════════════════════════════════════╣
        ║                        FEATURE USAGE                            ║
        ╠════════════════════════════════════════════════════════════════╣
        \(formatFeatureUsage())
        ╚════════════════════════════════════════════════════════════════╝
        
        """
        
        phaseLog.info("\(summary)")
    }
    
    /// Get copyable action log
    public func getCopyableLog() -> String {
        var log = "ONBOARDING ACTION LOG - Session: \(sessionId)\n"
        log += "=" .repeated(60) + "\n\n"
        
        for action in actionHistory {
            log += action.formattedLog + "\n"
        }
        
        return log
    }
    
    // MARK: - Private Helpers
    
    private func recordAction(phase: String, action: String, details: [String: Any]?) {
        let action = OnboardingAction(
            timestamp: Date(),
            phase: phase,
            action: action,
            details: details
        )
        actionHistory.append(action)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.2fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
    
    private func formatPhaseDurations() -> String {
        var result = ""
        for (phase, duration) in phaseDurations.sorted(by: { $0.key < $1.key }) {
            result += "║ \(phase.padding(toLength: 20, withPad: " ", startingAt: 0)) │ \(formatDuration(duration).padding(toLength: 15, withPad: " ", startingAt: 0)) ║\n"
        }
        return result.trimmingCharacters(in: .newlines)
    }
    
    private func formatActionSummary() -> String {
        let actionCounts = Dictionary(grouping: actionHistory, by: { $0.action })
            .mapValues { $0.count }
            .sorted(by: { $0.value > $1.value })
        
        var result = ""
        for (action, count) in actionCounts.prefix(10) {
            result += "║ \(action.padding(toLength: 30, withPad: " ", startingAt: 0)) │ \(String(count).padding(toLength: 5, withPad: " ", startingAt: 0)) ║\n"
        }
        return result.trimmingCharacters(in: .newlines)
    }
    
    private func formatFeatureUsage() -> String {
        let features = actionHistory.filter { $0.action.hasPrefix("feature_") }
        let featureCounts = Dictionary(grouping: features, by: { $0.action })
            .mapValues { $0.count }
            .sorted(by: { $0.value > $1.value })
        
        var result = ""
        for (feature, count) in featureCounts {
            let featureName = feature.replacingOccurrences(of: "feature_", with: "")
            result += "║ \(featureName.padding(toLength: 30, withPad: " ", startingAt: 0)) │ \(String(count).padding(toLength: 5, withPad: " ", startingAt: 0)) ║\n"
        }
        return result.trimmingCharacters(in: .newlines)
    }
}

// MARK: - String Extension

private extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// MARK: - Date Extension

private extension Date {
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: self)
    }
}
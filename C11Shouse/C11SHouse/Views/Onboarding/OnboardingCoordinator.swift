/*
 * CONTEXT & PURPOSE:
 * OnboardingCoordinator manages the onboarding flow state and progression through
 * different phases. It coordinates between the various onboarding views and ensures
 * smooth transitions while tracking user progress.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation based on OnboardingUXPlan.md
 *   - State machine for onboarding phases
 *   - Progress tracking and analytics
 *   - Persistence of onboarding completion
 *   - Coordination with existing app flow
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI
import Combine
import OSLog

enum OnboardingPhase: Int, CaseIterable {
    case welcome = 0
    case permissions = 1
    case completion = 2
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .permissions:
            return "Setup"
        case .completion:
            return "Complete Setup"
        }
    }
}

@MainActor
class OnboardingCoordinator: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentPhase: OnboardingPhase = .welcome
    @Published var isOnboardingComplete = false
    @Published var showOnboarding = false
    
    // MARK: - Private Properties
    
    private let notesService: NotesServiceProtocol
    private let permissionManager: PermissionManager
    private let addressManager: AddressManager
    private var cancellables = Set<AnyCancellable>()
    private var isInitializingOnboarding = false
    
    // Onboarding metrics
    private var startTime: Date?
    private var phaseStartTimes: [OnboardingPhase: Date] = [:]
    
    // MARK: - Initialization
    
    init(notesService: NotesServiceProtocol,
         permissionManager: PermissionManager,
         addressManager: AddressManager) {
        self.notesService = notesService
        self.permissionManager = permissionManager
        self.addressManager = addressManager
        
        checkOnboardingStatus()
    }
    
    // MARK: - Public Methods
    
    /// Check if onboarding should be shown
    func checkOnboardingStatus() {
        Task {
            // Check if required questions are answered
            let requiredComplete = await notesService.areAllRequiredQuestionsAnswered()
            
            // Check if permissions are granted
            let permissionsGranted = permissionManager.allPermissionsGranted
            
            // Show onboarding if not complete
            await MainActor.run {
                isOnboardingComplete = requiredComplete && permissionsGranted
                showOnboarding = !isOnboardingComplete
                
                // Only start onboarding if not already initializing
                if showOnboarding && !isInitializingOnboarding {
                    isInitializingOnboarding = true
                    startOnboarding()
                }
            }
        }
    }
    
    /// Start the onboarding flow
    func startOnboarding() {
        startTime = Date()
        currentPhase = .welcome
        recordPhaseStart(.welcome)
        
        // Start logging session
        OnboardingLogger.shared.startSession()
        OnboardingLogger.shared.logPhaseTransition(from: nil, to: "welcome")
    }
    
    /// Move to the next phase
    func nextPhase() {
        guard let currentIndex = OnboardingPhase.allCases.firstIndex(of: currentPhase),
              currentIndex < OnboardingPhase.allCases.count - 1 else {
            completeOnboarding()
            return
        }
        
        recordPhaseCompletion(currentPhase)
        
        let oldPhase = currentPhase.title
        let nextPhase = OnboardingPhase.allCases[currentIndex + 1]
        currentPhase = nextPhase
        recordPhaseStart(nextPhase)
        
        // Log phase transition
        OnboardingLogger.shared.logPhaseTransition(from: oldPhase, to: nextPhase.title)
    }
    
    /// Skip to a specific phase (for testing or recovery)
    func skipToPhase(_ phase: OnboardingPhase) {
        recordPhaseCompletion(currentPhase)
        let oldPhase = currentPhase.title
        currentPhase = phase
        recordPhaseStart(phase)
        
        // Log skip action
        OnboardingLogger.shared.logUserAction("phase_skip", phase: oldPhase, details: [
            "skipped_to": phase.title
        ])
        OnboardingLogger.shared.logPhaseTransition(from: oldPhase, to: phase.title)
    }
    
    /// Complete the onboarding process
    func completeOnboarding() {
        recordPhaseCompletion(currentPhase)
        
        // Calculate total time
        if let start = startTime {
            let totalTime = Date().timeIntervalSince(start)
            print("Onboarding completed in \(Int(totalTime)) seconds")
        }
        
        isOnboardingComplete = true
        showOnboarding = false
        isInitializingOnboarding = false
        
        // Log completion
        OnboardingLogger.shared.logUserAction("onboarding_complete", phase: currentPhase.title)
        OnboardingLogger.shared.endSession(completed: true)
        
        // Print copyable log
        let copyableLog = OnboardingLogger.shared.getCopyableLog()
        print("\n=== COPYABLE ONBOARDING LOG ===\n")
        print(copyableLog)
        print("\n=== END OF LOG ===\n")
        
        // Notify other parts of the app
        NotificationCenter.default.post(name: Notification.Name("OnboardingComplete"), object: nil)
    }
    
    /// Check if all permissions are granted
    func checkPermissions() -> Bool {
        return permissionManager.isMicrophoneGranted &&
               permissionManager.isSpeechRecognitionGranted
        // Location is optional
    }
    
    /// Request all permissions
    func requestPermissions() async {
        // Log permission requests
        OnboardingLogger.shared.logUserAction("request_all_permissions", phase: "permissions")
        
        await permissionManager.requestMicrophonePermission()
        OnboardingLogger.shared.logPermissionRequest("microphone", granted: permissionManager.isMicrophoneGranted)
        
        await permissionManager.requestSpeechRecognitionPermission()
        OnboardingLogger.shared.logPermissionRequest("speech_recognition", granted: permissionManager.isSpeechRecognitionGranted)
        
        if !permissionManager.hasLocationPermission {
            await permissionManager.requestLocationPermission()
            OnboardingLogger.shared.logPermissionRequest("location", granted: permissionManager.hasLocationPermission)
        }
    }
    
    // MARK: - Logging Methods
    
    /// Log a user action in the current phase
    func logAction(_ action: String, details: [String: Any]? = nil) {
        OnboardingLogger.shared.logUserAction(action, phase: currentPhase.title, details: details)
    }
    
    /// Log feature usage in the current phase
    func logFeature(_ feature: String, details: [String: Any]? = nil) {
        OnboardingLogger.shared.logFeatureUsage(feature, phase: currentPhase.title, details: details)
    }
    
    /// Log an error in the current phase
    func logError(_ error: Error, recovery: String? = nil) {
        OnboardingLogger.shared.logError(error, phase: currentPhase.title, recovery: recovery)
    }
    
    // MARK: - Private Methods
    
    private func recordPhaseStart(_ phase: OnboardingPhase) {
        phaseStartTimes[phase] = Date()
        print("Started onboarding phase: \(phase.title)")
    }
    
    private func recordPhaseCompletion(_ phase: OnboardingPhase) {
        guard let startTime = phaseStartTimes[phase] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        print("Completed onboarding phase: \(phase.title) in \(Int(duration)) seconds")
        
        // Here you could send analytics events
        // Analytics.track("onboarding_phase_complete", properties: [
        //     "phase": phase.title,
        //     "duration": duration
        // ])
    }
}

// MARK: - SwiftUI View Modifier

struct OnboardingModifier: ViewModifier {
    @StateObject private var coordinator: OnboardingCoordinator
    private let serviceContainer: ServiceContainer
    
    init(serviceContainer: ServiceContainer) {
        self.serviceContainer = serviceContainer
        _coordinator = StateObject(wrappedValue: OnboardingCoordinator(
            notesService: serviceContainer.notesService,
            permissionManager: serviceContainer.permissionManager,
            addressManager: serviceContainer.addressManager
        ))
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(coordinator.showOnboarding)
            
            if coordinator.showOnboarding {
                OnboardingContainerView()
                    .environmentObject(coordinator)
                    .environmentObject(serviceContainer)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}

// Extension to make it easy to apply
extension View {
    func withOnboarding(serviceContainer: ServiceContainer) -> some View {
        modifier(OnboardingModifier(serviceContainer: serviceContainer))
    }
}
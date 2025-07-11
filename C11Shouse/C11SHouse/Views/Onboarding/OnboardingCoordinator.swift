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

enum OnboardingPhase: Int, CaseIterable {
    case welcome = 0
    case permissions = 1
    case personalization = 2
    case completion = 3
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .permissions:
            return "Setup"
        case .personalization:
            return "Personalize"
        case .completion:
            return "Complete"
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
    }
    
    /// Move to the next phase
    func nextPhase() {
        guard let currentIndex = OnboardingPhase.allCases.firstIndex(of: currentPhase),
              currentIndex < OnboardingPhase.allCases.count - 1 else {
            completeOnboarding()
            return
        }
        
        recordPhaseCompletion(currentPhase)
        
        let nextPhase = OnboardingPhase.allCases[currentIndex + 1]
        currentPhase = nextPhase
        recordPhaseStart(nextPhase)
    }
    
    /// Skip to a specific phase (for testing or recovery)
    func skipToPhase(_ phase: OnboardingPhase) {
        recordPhaseCompletion(currentPhase)
        currentPhase = phase
        recordPhaseStart(phase)
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
        await permissionManager.requestAllPermissions()
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
    
    init(serviceContainer: ServiceContainer) {
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
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
    case homeKitImport = 2
    case completion = 3
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .permissions:
            return "Setup"
        case .homeKitImport:
            return "Importing HomeKit"
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
    @Published var isImportingHomeKit = false
    @Published var homeKitImportStatus: String = ""
    @Published var homeKitDiscoverySummary: HomeKitDiscoverySummary?
    
    // MARK: - Private Properties
    
    private let notesService: NotesServiceProtocol
    private let permissionManager: PermissionManager
    private let addressManager: AddressManager
    private let serviceContainer: ServiceContainer
    private var cancellables = Set<AnyCancellable>()
    private var isInitializingOnboarding = false
    
    // Onboarding metrics
    private var startTime: Date?
    private var phaseStartTimes: [OnboardingPhase: Date] = [:]
    
    // MARK: - Initialization
    
    init(notesService: NotesServiceProtocol,
         permissionManager: PermissionManager,
         addressManager: AddressManager,
         serviceContainer: ServiceContainer) {
        self.notesService = notesService
        self.permissionManager = permissionManager
        self.addressManager = addressManager
        self.serviceContainer = serviceContainer
        
        checkOnboardingStatus()
    }
    
    // MARK: - Public Methods
    
    /// Check if onboarding should be shown
    func checkOnboardingStatus() {
        Task {
            // Check if we're in UI testing mode and should skip onboarding
            let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING") ||
                              ProcessInfo.processInfo.arguments.contains("--uitesting")
            let shouldSkipOnboarding = ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
            let shouldResetOnboarding = ProcessInfo.processInfo.arguments.contains("--reset-onboarding")
            
            if isUITesting && (shouldSkipOnboarding || !shouldResetOnboarding) {
                // Skip onboarding for UI tests that don't explicitly need it
                await MainActor.run {
                    isOnboardingComplete = true
                    showOnboarding = false
                }
                return
            }
            
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
        
        // If we're entering HomeKit import phase and user has granted permission, start the import
        if nextPhase == .homeKitImport {
            Task {
                await performHomeKitImport()
            }
        }
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
        
        if !permissionManager.isHomeKitGranted {
            await permissionManager.requestHomeKitPermission()
            OnboardingLogger.shared.logPermissionRequest("homekit", granted: permissionManager.isHomeKitGranted)
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
    
    // MARK: - HomeKit Import
    
    private func performHomeKitImport() async {
        // Skip HomeKit import phase if permission not granted
        guard permissionManager.isHomeKitGranted else {
            nextPhase() // Skip to completion
            return
        }
        
        // Access homeKitCoordinator only when needed
        let coordinator = await MainActor.run {
            serviceContainer.homeKitCoordinator
        }
        
        await MainActor.run {
            isImportingHomeKit = true
            homeKitImportStatus = "Discovering HomeKit configuration..."
        }
        
        logAction("homekit_import_started")
        
        // Observe coordinator status
        coordinator.$discoveryStatus
            .sink { [weak self] status in
                Task { @MainActor in
                    self?.handleHomeKitDiscoveryStatus(status)
                }
            }
            .store(in: &cancellables)
        
        // Start discovery
        await coordinator.discoverAndSaveConfiguration()
    }
    
    private func handleHomeKitDiscoveryStatus(_ status: HomeKitDiscoveryStatus) {
        switch status {
        case .idle:
            break
            
        case .checkingAuthorization:
            homeKitImportStatus = "Checking HomeKit authorization..."
            
        case .discovering:
            homeKitImportStatus = "Discovering homes and devices..."
            
        case .savingNotes:
            homeKitImportStatus = "Saving configuration..."
            
        case .completed(let summary):
            homeKitDiscoverySummary = summary
            homeKitImportStatus = "Import complete!"
            isImportingHomeKit = false
            
            logAction("homekit_import_completed", details: [
                "homes_count": summary.homes.count,
                "total_rooms": summary.totalRooms,
                "total_accessories": summary.totalAccessories
            ])
            
            // Auto-advance to completion after a brief delay
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                await MainActor.run {
                    nextPhase()
                }
            }
            
        case .failed(let error):
            homeKitImportStatus = "Import failed: \(error.localizedDescription)"
            isImportingHomeKit = false
            
            logError(error, recovery: "User can manually add rooms and devices later")
            
            // Auto-advance to completion after showing error
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await MainActor.run {
                    nextPhase()
                }
            }
        }
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
            addressManager: serviceContainer.addressManager,
            serviceContainer: serviceContainer
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
/*
 * CONTEXT & PURPOSE:
 * C11SHouseApp is the main entry point for the C11S House iOS application, a voice-based
 * house consciousness system. It initializes the app's dependency injection container,
 * sets up the main scene, and handles initial permission requests for microphone access.
 *
 * DECISION HISTORY:
 * - 2025-07-03: Initial implementation
 *   - Used @main attribute for SwiftUI app lifecycle
 *   - ServiceContainer implemented as singleton for dependency injection
 *   - @StateObject wrapper ensures ServiceContainer lifecycle is managed by SwiftUI
 *   - Permissions requested on app launch using .task modifier for async operations
 *   - Conditional permission request only if not already granted to improve UX
 *   - ContentView used as root view with ServiceContainer injected via environment
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

@main
struct C11SHouseApp: App {
    @StateObject private var serviceContainer = ServiceContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceContainer)
                .withOnboarding(serviceContainer: serviceContainer)
                .task {
                    // Request permissions through onboarding flow
                    // The onboarding coordinator will handle permission requests
                }
        }
    }
    
    private func requestPermissionsIfNeeded() async {
        let permissionManager = serviceContainer.permissionManager
        
        // Request permissions if not all granted
        if !permissionManager.allPermissionsGranted {
            await permissionManager.requestAllPermissions()
        }
    }
}

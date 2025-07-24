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
 * - 2025-07-24: Removed separate splash screen
 *   - Animation moved to OnboardingWelcomeView per UX plan requirements
 *   - Splash screen animation was not part of original design spec
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

@main
struct C11SHouseApp: App {
    @StateObject private var serviceContainer = ServiceContainer.shared
    
    init() {
        #if DEBUG
        // Clean up any test data that might have persisted from unit tests
        cleanupTestData()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceContainer)
                .task {
                    // For existing users who already have HomeKit permission
                    await checkForHomeKitDiscovery()
                }
        }
    }
    
    
    @MainActor
    private func checkForHomeKitDiscovery() async {
        // Wait a bit for app to fully initialize
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Check if user has HomeKit permission but hasn't run discovery
        let hasRunHomeKitDiscovery = UserDefaults.standard.bool(forKey: "hasRunHomeKitDiscovery")
        
        if !hasRunHomeKitDiscovery {
            // Check if HomeKit permission is granted
            let permissionManager = serviceContainer.permissionManager
            permissionManager.checkCurrentPermissions()
            
            if permissionManager.isHomeKitGranted {
                print("[C11SHouseApp] User has HomeKit permission but discovery hasn't run. Running now...")
                
                // Run HomeKit discovery
                let homeKitCoordinator = serviceContainer.homeKitCoordinator
                await homeKitCoordinator.discoverAndSaveConfiguration()
                
                // Mark as complete
                UserDefaults.standard.set(true, forKey: "hasRunHomeKitDiscovery")
                
                print("[C11SHouseApp] HomeKit discovery completed for existing user")
            }
        }
    }
    
    #if DEBUG
    private func cleanupTestData() {
        // Check if we have test data persisted from unit tests
        if let addressData = UserDefaults.standard.data(forKey: "confirmedHomeAddress"),
           let address = try? JSONDecoder().decode(Address.self, from: addressData) {
            // Check if this is test data
            if address.street.contains("Test Street") || 
               address.city.contains("Test City") ||
               address.street.contains("Mock") ||
               address.postalCode == "12345" ||
               address.state == "TS" ||
               address.state == "TC" ||
               address.state == "MC" {
                print("[C11SHouseApp] Removing test data from UserDefaults: \(address.fullAddress)")
                UserDefaults.standard.removeObject(forKey: "confirmedHomeAddress")
                UserDefaults.standard.removeObject(forKey: "detectedHomeAddress")
            }
        }
        
        // Also check house name for test data
        if let houseName = UserDefaults.standard.string(forKey: "houseName") {
            if houseName.contains("Test") || houseName.contains("Mock") {
                print("[C11SHouseApp] Removing test house name: \(houseName)")
                UserDefaults.standard.removeObject(forKey: "houseName")
            }
        }
    }
    #endif
}

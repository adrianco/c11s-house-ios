import SwiftUI

@main
struct C11SHouseApp: App {
    @StateObject private var serviceContainer = ServiceContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceContainer)
                .task {
                    // Request permissions on app launch
                    await requestPermissionsIfNeeded()
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

import SwiftUI

@main
struct C11SHouseApp: App {
    @StateObject private var serviceContainer = ServiceContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withServiceContainer(serviceContainer)
                .task {
                    // Request permissions on app launch
                    await requestPermissionsIfNeeded()
                }
        }
    }
    
    private func requestPermissionsIfNeeded() async {
        let permissionManager = serviceContainer.permissionManager
        let status = await permissionManager.checkAllPermissions()
        
        // Request permissions if not granted
        if !status.microphone || !status.speechRecognition {
            _ = await permissionManager.requestAllPermissions()
        }
    }
}

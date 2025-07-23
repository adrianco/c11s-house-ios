/*
 * CONTEXT & PURPOSE:
 * Example implementation showing how to integrate HomeKit discovery into the app flow.
 * This demonstrates the intended usage pattern for the HomeKitCoordinator.
 *
 * DECISION HISTORY:
 * - 2025-07-23: Initial implementation
 *   - Example view model showing HomeKit discovery
 *   - Integration with conversation flow
 *   - Error handling and user feedback
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  HomeKitIntegrationExample.swift
//  C11SHouse
//
//  Example of HomeKit integration in the app
//

import Foundation
import SwiftUI

/// Example view model showing HomeKit integration
@MainActor
class HomeKitExampleViewModel: ObservableObject {
    private let coordinator: HomeKitCoordinator
    
    @Published var isDiscovering = false
    @Published var discoveryMessage = ""
    @Published var hasHomeKitData = false
    
    init(coordinator: HomeKitCoordinator) {
        self.coordinator = coordinator
    }
    
    /// Trigger HomeKit discovery from conversation or UI
    func discoverHomeKit() async {
        isDiscovering = true
        discoveryMessage = "Discovering your HomeKit configuration..."
        
        await coordinator.discoverAndSaveConfiguration()
        
        switch coordinator.discoveryStatus {
        case .completed(let summary):
            discoveryMessage = "Found \(summary.homes.count) home(s) with \(summary.totalAccessories) accessories!"
            hasHomeKitData = true
        case .failed(let error):
            discoveryMessage = "Failed to discover HomeKit: \(error.localizedDescription)"
        default:
            discoveryMessage = "Discovery process interrupted"
        }
        
        isDiscovering = false
    }
    
    /// Check if HomeKit has been set up
    func checkHomeKitStatus() async {
        hasHomeKitData = await coordinator.hasHomeKitConfiguration()
    }
}

// MARK: - Integration with Conversation Flow

extension ConversationStateManager {
    /// Handle HomeKit discovery during conversation
    func handleHomeKitDiscovery() async -> String {
        let coordinator = ServiceContainer.shared.homeKitCoordinator
        
        // Check if already discovered
        if await coordinator.hasHomeKitConfiguration() {
            return "I've already discovered your HomeKit configuration. Would you like me to refresh it?"
        }
        
        // Start discovery
        await coordinator.discoverAndSaveConfiguration()
        
        switch coordinator.discoveryStatus {
        case .completed(let summary):
            if summary.homes.isEmpty {
                return "I couldn't find any HomeKit homes. Make sure you've set up homes and accessories in the Home app first."
            } else {
                return """
                Great! I've discovered your HomeKit setup:
                • \(summary.homes.count) home(s)
                • \(summary.totalRooms) room(s)
                • \(summary.totalAccessories) accessory/accessories
                
                I've saved all this information in my notes so I can remember your home's configuration.
                """
            }
            
        case .failed(let error):
            return "I had trouble accessing your HomeKit data: \(error.localizedDescription). You can try again later or set up HomeKit in the Home app first."
            
        default:
            return "Something unexpected happened during HomeKit discovery. Please try again."
        }
    }
}

// MARK: - Example SwiftUI View

struct HomeKitDiscoveryView: View {
    @StateObject private var viewModel: HomeKitExampleViewModel
    
    init(coordinator: HomeKitCoordinator) {
        _viewModel = StateObject(wrappedValue: HomeKitExampleViewModel(coordinator: coordinator))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.hasHomeKitData {
                Label("HomeKit Configured", systemImage: "homekit")
                    .foregroundColor(.green)
            }
            
            Button(action: {
                Task {
                    await viewModel.discoverHomeKit()
                }
            }) {
                if viewModel.isDiscovering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Discover HomeKit")
                }
            }
            .disabled(viewModel.isDiscovering)
            
            if !viewModel.discoveryMessage.isEmpty {
                Text(viewModel.discoveryMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .task {
            await viewModel.checkHomeKitStatus()
        }
    }
}
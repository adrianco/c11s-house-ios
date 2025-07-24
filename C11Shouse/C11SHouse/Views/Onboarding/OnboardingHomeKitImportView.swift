/*
 * CONTEXT & PURPOSE:
 * OnboardingHomeKitImportView shows progress during HomeKit configuration import.
 * It provides visual feedback while the app discovers and saves HomeKit homes,
 * rooms, and accessories as notes.
 *
 * DECISION HISTORY:
 * - 2025-01-23: Initial implementation
 *   - Progress animation during import
 *   - Status updates from coordinator
 *   - Auto-advance to completion
 *   - Error handling with graceful fallback
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

import SwiftUI

struct OnboardingHomeKitImportView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    @State private var animationPhase = 0.0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated House Icon
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .scaleEffect(1.0 + animationPhase * 0.1)
                
                // House icon with pulse animation
                Image(systemName: "house.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(1.0 + animationPhase * 0.05)
                
                // Scanning effect
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(animationPhase * 360))
                    .opacity(coordinator.isImportingHomeKit ? 1 : 0)
            }
            .onAppear {
                withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                    animationPhase = 1.0
                }
            }
            
            // Status Text
            VStack(spacing: 16) {
                Text("Importing HomeKit Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(coordinator.homeKitImportStatus)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .animation(.easeInOut, value: coordinator.homeKitImportStatus)
                
                if coordinator.isImportingHomeKit {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                        .padding(.top, 10)
                }
            }
            
            // Results Summary (shown when completed)
            if let summary = coordinator.homeKitDiscoverySummary {
                VStack(alignment: .leading, spacing: 12) {
                    ImportResultRow(
                        icon: "house.circle.fill",
                        label: "Homes",
                        count: summary.homes.count
                    )
                    
                    ImportResultRow(
                        icon: "door.left.hand.open",
                        label: "Rooms",
                        count: summary.totalRooms
                    )
                    
                    ImportResultRow(
                        icon: "lightbulb.fill",
                        label: "Devices",
                        count: summary.totalAccessories
                    )
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale))
            }
            
            Spacer()
            
            // Info text
            Text("Your HomeKit configuration is being imported in the background")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
        }
        .onAppear {
            OnboardingLogger.shared.logUserAction("view_homekit_import", phase: "homekit_import")
        }
    }
}

// MARK: - Supporting Views

struct ImportResultRow: View {
    let icon: String
    let label: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(label)
                .font(.body)
            
            Spacer()
            
            Text("\(count)")
                .font(.headline)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Preview

struct OnboardingHomeKitImportView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingHomeKitImportView()
            .environmentObject(OnboardingCoordinator(
                notesService: NotesServiceImpl(),
                permissionManager: PermissionManager.shared,
                addressManager: AddressManager(
                    notesService: NotesServiceImpl(),
                    locationService: LocationServiceImpl()
                ),
                serviceContainer: ServiceContainer.shared
            ))
    }
}
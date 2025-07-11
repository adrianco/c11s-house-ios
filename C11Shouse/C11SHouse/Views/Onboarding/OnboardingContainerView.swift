/*
 * CONTEXT & PURPOSE:
 * OnboardingContainerView is the main container that manages the onboarding flow.
 * It displays the appropriate view based on the current phase and handles transitions
 * between phases with smooth animations.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation based on OnboardingUXPlan.md
 *   - Smooth phase transitions
 *   - Progress indicator
 *   - Adaptive layout for different screen sizes
 *   - Handles both new and returning users
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var isTransitioning = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.secondarySystemBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Indicator
                if coordinator.currentPhase != .welcome {
                    ProgressIndicator(
                        currentPhase: coordinator.currentPhase,
                        totalPhases: OnboardingPhase.allCases.count
                    )
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Phase Content
                Group {
                    switch coordinator.currentPhase {
                    case .welcome:
                        OnboardingWelcomeView {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                coordinator.nextPhase()
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                    case .permissions:
                        OnboardingPermissionsView(
                            permissionManager: serviceContainer.permissionManager,
                            onContinue: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    coordinator.nextPhase()
                                }
                            }
                        )
                        .environmentObject(serviceContainer)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                    case .completion:
                        OnboardingCompletionView {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                coordinator.completeOnboarding()
                            }
                        }
                        .environmentObject(serviceContainer)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                    }
                }
                .id(coordinator.currentPhase)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentPhase)
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    let currentPhase: OnboardingPhase
    let totalPhases: Int
    
    private var progress: Double {
        Double(currentPhase.rawValue) / Double(totalPhases - 1)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
            
            // Phase Label
            Text(currentPhase.title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct OnboardingContainerView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingContainerView()
            .environmentObject(OnboardingCoordinator(
                notesService: NotesServiceImpl(),
                permissionManager: PermissionManager.shared,
                addressManager: AddressManager(
                    notesService: NotesServiceImpl(),
                    locationService: LocationServiceImpl()
                )
            ))
            .environmentObject(ServiceContainer.shared)
    }
}
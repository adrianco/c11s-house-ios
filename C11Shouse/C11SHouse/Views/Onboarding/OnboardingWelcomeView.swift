/*
 * CONTEXT & PURPOSE:
 * OnboardingWelcomeView implements Phase 1 of the onboarding UX plan. It creates
 * an emotional connection with the user through animated visuals and establishes
 * the app's personality as a conscious house companion.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation based on OnboardingUXPlan.md
 *   - Animated house icon with consciousness visualization
 *   - Smooth transitions and micro-interactions
 *   - Time-based personalized greeting
 *   - Blue gradient design language
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI

struct OnboardingWelcomeView: View {
    @State private var isAnimating = false
    @State private var showContent = false
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    // Completion handler
    let onContinue: () -> Void
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Animated House Icon
            ZStack {
                // Consciousness visualization rings
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.2)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .opacity(isAnimating ? 0.3 : 0.7)
                        .animation(
                            Animation.easeInOut(duration: 2.0 + Double(index) * 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
                
                // Central house icon
                Image(uiImage: AppIconCreator.createIcon(size: CGSize(width: 120, height: 120)))
                    .resizable()
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    .scaleEffect(showContent ? 1.0 : 0.8)
                    .opacity(showContent ? 1.0 : 0.0)
            }
            .padding(.bottom, 40)
            
            // Welcome Text
            VStack(spacing: 16) {
                Text(greeting)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
                
                Text("Your House, Awakened")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
            }
            
            Spacer()
            
            // Value Propositions
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "mic.fill",
                    title: "Natural Conversations",
                    description: "Talk to your house like a helpful companion"
                )
                .opacity(showContent ? 1.0 : 0.0)
                .offset(x: showContent ? 0 : -50)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
                
                FeatureRow(
                    icon: "brain",
                    title: "Intelligent Memory",
                    description: "Remembers important details about your home"
                )
                .opacity(showContent ? 1.0 : 0.0)
                .offset(x: showContent ? 0 : -50)
                .animation(.easeOut(duration: 0.6).delay(0.5), value: showContent)
                
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "Privacy First",
                    description: "Your data stays on your device"
                )
                .opacity(showContent ? 1.0 : 0.0)
                .offset(x: showContent ? 0 : -50)
                .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                OnboardingLogger.shared.logButtonTap("begin_setup", phase: "welcome")
                onContinue()
            }) {
                Text("Begin Setup")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "007AFF"), Color(hex: "5856D6")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
            .opacity(showContent ? 1.0 : 0.0)
            .scaleEffect(showContent ? 1.0 : 0.9)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: showContent)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.secondarySystemBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            
            // Log welcome view appearance
            OnboardingLogger.shared.logUserAction("view_appeared", phase: "welcome")
            
            // Trigger content animation after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showContent = true
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

struct OnboardingWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingWelcomeView(onContinue: {})
            .environmentObject(ServiceContainer.shared)
    }
}
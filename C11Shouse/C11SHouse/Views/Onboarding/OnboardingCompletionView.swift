/*
 * CONTEXT & PURPOSE:
 * OnboardingCompletionView implements the final phase of onboarding. It celebrates
 * the user's completion, shows a personalized message using collected data, and
 * provides quick actions to encourage immediate engagement with the app.
 *
 * DECISION HISTORY:
 * - 2025-07-10: Initial implementation based on OnboardingUXPlan.md
 *   - Celebration animation with confetti effect
 *   - Personalized completion message
 *   - Quick action suggestions
 *   - Smooth transition to main app
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI

struct OnboardingCompletionView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var showCelebration = false
    @State private var showContent = false
    @State private var userName = ""
    @State private var houseName = ""
    @State private var currentWeather: Weather?
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                
                // Success Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.green.opacity(0.3), .blue.opacity(0.2)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(showCelebration ? 1.0 : 0.5)
                        .opacity(showCelebration ? 1.0 : 0.0)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .scaleEffect(showCelebration ? 1.0 : 0.5)
                        .opacity(showCelebration ? 1.0 : 0.0)
                }
                .padding(.bottom, 40)
                
                // Personalized Message
                VStack(spacing: 16) {
                    Text("Welcome Home, \(userName)!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .opacity(showContent ? 1.0 : 0.0)
                    
                    Text("I'm the conscious mind for \(houseName). I'll help you manage your home and remember important details.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
                }
                
                Spacer()
                
                // Quick Actions
                VStack(spacing: 16) {
                    Text("What would you like to do first?")
                        .font(.headline)
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
                    
                    VStack(spacing: 12) {
                        QuickActionButton(
                            icon: "bubble.left.fill",
                            title: "Start a Conversation",
                            description: weatherBasedSuggestion(),
                            action: {
                                onComplete()
                                // Navigate to conversation view
                            }
                        )
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.5), value: showContent)
                        
                        QuickActionButton(
                            icon: "note.text",
                            title: "Add a Room Note",
                            description: "Tell me about a room in your house",
                            action: {
                                onComplete()
                                // Navigate to notes with room prompt
                            }
                        )
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
                        
                        QuickActionButton(
                            icon: "lightbulb.fill",
                            title: "Explore Features",
                            description: "See what else I can do",
                            action: {
                                onComplete()
                                // Show feature tour
                            }
                        )
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.7), value: showContent)
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
                
                // Skip to Main App
                Button(action: onComplete) {
                    Text("Go to Home Screen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 30)
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(0.8), value: showContent)
            }
            
            // Confetti Effect
            if showCelebration {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            loadUserData()
            celebrate()
        }
    }
    
    private func loadUserData() {
        Task {
            // Load user name
            if let name = await getUserName() {
                await MainActor.run {
                    userName = name.isEmpty ? "Friend" : name
                }
            }
            
            // Load house name
            if let house = await serviceContainer.notesService.getHouseName() {
                await MainActor.run {
                    houseName = house.isEmpty ? "Your House" : house
                }
            }
            
            // Load current weather
            if let weather = await loadCurrentWeather() {
                await MainActor.run {
                    currentWeather = weather
                }
            }
        }
    }
    
    private func getUserName() async -> String? {
        let notesStore = try? await serviceContainer.notesService.loadNotesStore()
        if let nameQuestion = notesStore?.questions.first(where: { $0.text == "What's your name?" }),
           let nameNote = notesStore?.notes[nameQuestion.id] {
            return nameNote.answer
        }
        return nil
    }
    
    private func loadCurrentWeather() async -> Weather? {
        // Try to load weather from notes
        let notesStore = try? await serviceContainer.notesService.loadNotesStore()
        if let weatherNote = notesStore?.notes.values.first(where: { $0.title.lowercased().contains("weather") }) {
            // Parse weather from note (simplified)
            return nil // Would parse actual weather data
        }
        return nil
    }
    
    private func weatherBasedSuggestion() -> String {
        if let weather = currentWeather {
            switch weather.condition {
            case .rain, .drizzle, .heavyRain:
                return "It's raining - should I check the windows?"
            case .hot:
                return "It's warm today - want to adjust the thermostat?"
            case .frigid:
                return "It's chilly - should I check the heating?"
            case .snow, .heavySnow, .flurries:
                return "It's snowing - want me to check the heating?"
            default:
                return "Ask me about today's weather"
            }
        }
        return "Try saying 'Hi!'"
    }
    
    private func celebrate() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showCelebration = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showContent = true
            }
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(piece: piece)
                }
            }
            .onAppear {
                createConfetti(in: geometry.size)
            }
        }
    }
    
    private func createConfetti(in size: CGSize) {
        for _ in 0..<50 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                startY: CGFloat.random(in: -100...0),
                color: [.blue, .green, .purple, .orange, .pink].randomElement()!,
                size: CGFloat.random(in: 8...15),
                duration: Double.random(in: 2...4)
            )
            confettiPieces.append(piece)
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let startY: CGFloat
    let color: Color
    let size: CGFloat
    let duration: Double
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    @State private var y: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size * 0.6)
            .position(x: piece.x, y: piece.startY + y)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: piece.duration)) {
                    y = UIScreen.main.bounds.height + 100
                    rotation = Double.random(in: 180...720)
                }
            }
    }
}

// MARK: - Preview

struct OnboardingCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingCompletionView(onComplete: {})
            .environmentObject(ServiceContainer.shared)
    }
}
/*
 * CONTEXT & PURPOSE:
 * Phase4TutorialView implements the note creation tutorial phase of onboarding.
 * It guides users through creating their first room and device notes through
 * an interactive conversation-based tutorial, completing the onboarding experience.
 *
 * DECISION HISTORY:
 * - 2025-07-11: Initial implementation based on OnboardingUXPlan.md Phase 4
 *   - Interactive tutorial for room note creation
 *   - Interactive tutorial for device note creation
 *   - Conversation-based guidance
 *   - Visual indicators and step tracking
 *   - Smooth transitions between tutorial steps
 *
 * FUTURE UPDATES:
 * - [Placeholder for future changes - update when modifying the file]
 */

import SwiftUI

enum TutorialStep: Int {
    case intro = 0
    case roomNoteIntro = 1
    case roomNoteCreation = 2
    case deviceNoteIntro = 3
    case deviceNoteCreation = 4
    case completion = 5
    
    var title: String {
        switch self {
        case .intro:
            return "Let's Add Some Notes!"
        case .roomNoteIntro:
            return "Room Notes"
        case .roomNoteCreation:
            return "Create Your First Room Note"
        case .deviceNoteIntro:
            return "Device Notes"
        case .deviceNoteCreation:
            return "Create Your First Device Note"
        case .completion:
            return "All Set!"
        }
    }
    
    var description: String {
        switch self {
        case .intro:
            return "I can help you remember important details about your home. Let me show you how to create notes about rooms and devices."
        case .roomNoteIntro:
            return "Room notes help me understand your home layout and remember important details about each space."
        case .roomNoteCreation:
            return "Tell me about the room you're in right now. What would you like me to remember about this space?"
        case .deviceNoteIntro:
            return "Device notes help me remember how to operate appliances, where manuals are stored, and maintenance schedules."
        case .deviceNoteCreation:
            return "Is there a device or appliance in your home that you'd like me to remember details about?"
        case .completion:
            return "Great job! You can create more notes anytime by saying 'new room note' or 'new device note' in our conversations."
        }
    }
    
    var icon: String {
        switch self {
        case .intro:
            return "note.text"
        case .roomNoteIntro, .roomNoteCreation:
            return "door.left.hand.open"
        case .deviceNoteIntro, .deviceNoteCreation:
            return "tv.and.hifispeaker.fill"
        case .completion:
            return "checkmark.circle.fill"
        }
    }
}

struct Phase4TutorialView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var currentStep: TutorialStep = .intro
    @State private var showConversation = false
    @State private var roomNoteName = ""
    @State private var roomNoteContent = ""
    @State private var deviceNoteName = ""
    @State private var deviceNoteContent = ""
    @State private var deviceRoom = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            TutorialProgressBar(
                currentStep: currentStep.rawValue,
                totalSteps: 6
            )
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Content Area
            ScrollView {
                VStack(spacing: 30) {
                    // Step Icon and Title
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: currentStep.icon)
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        
                        Text(currentStep.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(currentStep.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 40)
                    
                    // Interactive Content
                    switch currentStep {
                    case .intro:
                        introContent
                        
                    case .roomNoteIntro:
                        roomNoteIntroContent
                        
                    case .roomNoteCreation:
                        roomNoteCreationContent
                        
                    case .deviceNoteIntro:
                        deviceNoteIntroContent
                        
                    case .deviceNoteCreation:
                        deviceNoteCreationContent
                        
                    case .completion:
                        completionContent
                    }
                }
                .padding(.bottom, 100)
            }
            
            // Bottom Navigation
            bottomNavigation
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            OnboardingLogger.shared.logUserAction("view_appeared", phase: "tutorial")
            OnboardingLogger.shared.logUserAction("tutorial_step", phase: "tutorial", details: [
                "step": currentStep.title
            ])
        }
    }
    
    // MARK: - Content Views
    
    private var introContent: some View {
        VStack(spacing: 20) {
            // Visual representation of notes
            HStack(spacing: 30) {
                NoteTypeCard(
                    icon: "door.left.hand.open",
                    title: "Room Notes",
                    description: "Living room, kitchen, bedroom details",
                    color: .blue
                )
                
                NoteTypeCard(
                    icon: "tv.and.hifispeaker.fill",
                    title: "Device Notes",
                    description: "TV, thermostat, appliance info",
                    color: .purple
                )
            }
            .padding(.horizontal, 30)
        }
    }
    
    private var roomNoteIntroContent: some View {
        VStack(spacing: 20) {
            // Example room notes
            VStack(alignment: .leading, spacing: 12) {
                ExampleNoteRow(icon: "sofa", text: "Living room has a smart TV with voice control")
                ExampleNoteRow(icon: "bed.double", text: "Master bedroom thermostat is set to 68°F at night")
                ExampleNoteRow(icon: "refrigerator", text: "Kitchen water filter needs replacing every 6 months")
            }
            .padding(20)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 30)
        }
    }
    
    private var roomNoteCreationContent: some View {
        VStack(spacing: 20) {
            // Room name input
            VStack(alignment: .leading, spacing: 8) {
                Label("Room Name", systemImage: "door.left.hand.open")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("e.g., Living Room, Kitchen, Bedroom", text: $roomNoteName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isProcessing)
            }
            .padding(.horizontal, 30)
            
            // Room details input
            VStack(alignment: .leading, spacing: 8) {
                Label("What should I remember about this room?", systemImage: "note.text")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextEditor(text: $roomNoteContent)
                    .frame(minHeight: 100)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(isProcessing)
                
                Text("Tip: Mention devices, important features, or things to remember")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 30)
            
            // Voice input option
            Button(action: {
                showConversation = true
            }) {
                Label("Use Voice Input", systemImage: "mic.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .disabled(isProcessing)
        }
    }
    
    private var deviceNoteIntroContent: some View {
        VStack(spacing: 20) {
            // Example device notes
            VStack(alignment: .leading, spacing: 12) {
                ExampleNoteRow(icon: "tv", text: "TV remote uses AAA batteries, extras in drawer")
                ExampleNoteRow(icon: "thermometer", text: "Thermostat schedule: 68°F night, 72°F day")
                ExampleNoteRow(icon: "washer", text: "Washing machine manual is in the laundry cabinet")
            }
            .padding(20)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 30)
        }
    }
    
    private var deviceNoteCreationContent: some View {
        VStack(spacing: 20) {
            // Device name input
            VStack(alignment: .leading, spacing: 8) {
                Label("Device Name", systemImage: "tv.and.hifispeaker.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("e.g., Living Room TV, Kitchen Dishwasher", text: $deviceNoteName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isProcessing)
            }
            .padding(.horizontal, 30)
            
            // Room association
            VStack(alignment: .leading, spacing: 8) {
                Label("Which room is this device in?", systemImage: "door.left.hand.open")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("e.g., Living Room (optional)", text: $deviceRoom)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isProcessing)
            }
            .padding(.horizontal, 30)
            
            // Device details input
            VStack(alignment: .leading, spacing: 8) {
                Label("Device details to remember", systemImage: "note.text")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextEditor(text: $deviceNoteContent)
                    .frame(minHeight: 100)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(isProcessing)
                
                Text("Tip: Include model info, maintenance schedules, or operating instructions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 30)
            
            // Voice input option
            Button(action: {
                showConversation = true
            }) {
                Label("Use Voice Input", systemImage: "mic.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .disabled(isProcessing)
        }
    }
    
    private var completionContent: some View {
        VStack(spacing: 30) {
            // Success animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .scaleEffect(1.2)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: currentStep)
            
            // Summary
            VStack(spacing: 16) {
                if !roomNoteName.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Created room note: \(roomNoteName)")
                            .font(.body)
                    }
                }
                
                if !deviceNoteName.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Created device note: \(deviceNoteName)")
                            .font(.body)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            // Tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Tips:")
                    .font(.headline)
                
                TipRow(text: "Say \"new room note\" to add room details")
                TipRow(text: "Say \"new device note\" to track appliances")
                TipRow(text: "I'll help you remember maintenance schedules")
                TipRow(text: "Ask me \"what's in the living room?\" anytime")
            }
            .padding(20)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 30)
        }
    }
    
    // MARK: - Bottom Navigation
    
    private var bottomNavigation: some View {
        HStack {
            // Back button (not on first step)
            if currentStep.rawValue > 0 {
                Button(action: {
                    OnboardingLogger.shared.logButtonTap("back", phase: "tutorial")
                    previousStep()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.secondary)
                }
                .disabled(isProcessing)
            }
            
            Spacer()
            
            // Next/Complete button
            Button(action: {
                OnboardingLogger.shared.logButtonTap(nextButtonTitle, phase: "tutorial")
                nextStep()
            }) {
                HStack {
                    Text(nextButtonTitle)
                    if currentStep != .completion {
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: nextButtonColors),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
            .disabled(isProcessing || !canProceed)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(Color(UIColor.systemBackground))
    }
    
    private var nextButtonTitle: String {
        switch currentStep {
        case .completion:
            return "Start Using C11S House"
        case .roomNoteCreation, .deviceNoteCreation:
            return canProceed ? "Save & Continue" : "Skip"
        default:
            return "Continue"
        }
    }
    
    private var nextButtonColors: [Color] {
        if currentStep == .completion {
            return [.green, .blue]
        } else if canProceed {
            return [.blue, .purple]
        } else {
            return [.gray, .gray.opacity(0.8)]
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .roomNoteCreation:
            return !roomNoteName.isEmpty && !roomNoteContent.isEmpty
        case .deviceNoteCreation:
            return !deviceNoteName.isEmpty && !deviceNoteContent.isEmpty
        default:
            return true
        }
    }
    
    // MARK: - Navigation Methods
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newStep = TutorialStep(rawValue: currentStep.rawValue - 1) {
                currentStep = newStep
            }
        }
    }
    
    private func nextStep() {
        switch currentStep {
        case .roomNoteCreation:
            if canProceed {
                saveRoomNote()
            } else {
                advanceStep()
            }
            
        case .deviceNoteCreation:
            if canProceed {
                saveDeviceNote()
            } else {
                advanceStep()
            }
            
        case .completion:
            onComplete()
            
        default:
            advanceStep()
        }
    }
    
    private func advanceStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newStep = TutorialStep(rawValue: currentStep.rawValue + 1) {
                currentStep = newStep
            }
        }
    }
    
    // MARK: - Note Saving Methods
    
    private func saveRoomNote() {
        isProcessing = true
        
        Task {
            do {
                // Create custom note through notes service
                let noteTitle = "Room: \(roomNoteName)"
                let noteContent = """
                Room: \(roomNoteName)
                
                \(roomNoteContent)
                
                Created during onboarding tutorial.
                """
                
                // Save as a custom note
                await serviceContainer.notesService.saveCustomNote(
                    title: noteTitle,
                    content: noteContent,
                    category: "room"
                )
                
                await MainActor.run {
                    isProcessing = false
                    advanceStep()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to save room note: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func saveDeviceNote() {
        isProcessing = true
        
        Task {
            do {
                // Create custom note through notes service
                let noteTitle = "Device: \(deviceNoteName)"
                let noteContent = """
                Device: \(deviceNoteName)
                \(deviceRoom.isEmpty ? "" : "Location: \(deviceRoom)")
                
                \(deviceNoteContent)
                
                Created during onboarding tutorial.
                """
                
                // Save as a custom note
                await serviceContainer.notesService.saveCustomNote(
                    title: noteTitle,
                    content: noteContent,
                    category: "device"
                )
                
                await MainActor.run {
                    isProcessing = false
                    advanceStep()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to save device note: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct TutorialProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    private var progress: Double {
        Double(currentStep) / Double(totalSteps - 1)
    }
    
    var body: some View {
        VStack(spacing: 8) {
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
            
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NoteTypeCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ExampleNoteRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct Phase4TutorialView_Previews: PreviewProvider {
    static var previews: some View {
        Phase4TutorialView(onComplete: {})
            .environmentObject(ServiceContainer.shared)
    }
}
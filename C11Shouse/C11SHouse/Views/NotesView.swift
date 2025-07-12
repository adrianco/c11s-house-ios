/*
 * CONTEXT & PURPOSE:
 * NotesView displays all house-related questions and their answers (notes) with editing
 * capabilities. It provides an intuitive interface for viewing and editing notes with proper
 * save/cancel functionality and visual feedback during edit mode.
 *
 * DECISION HISTORY:
 * - 2025-07-07: Initial implementation
 *   - @State properties for edit mode and temporary text storage
 *   - Toggle between view and edit modes with visual feedback
 *   - Blue outline and edit icon for items in edit mode
 *   - TextEditor for multi-line note editing
 *   - Save/cancel functionality for each edited note
 *   - Grouped display by question categories
 *   - Progress indicator showing completion percentage
 *   - Integration with NotesService for persistence
 *   - iOS-standard editing conventions and gestures
 *
 * FUTURE UPDATES:
 * - [Add future changes and decisions here]
 */

//
//  NotesView.swift
//  C11SHouse
//
//  View for displaying and editing house-related Q&A notes
//

import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var notesStore = NotesStoreData()
    @State private var editingNoteId: UUID? = nil
    @State private var editingText: String = ""
    @State private var originalText: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showClearAllAlert = false
    @State private var isLoadingAddress = false
    @State private var detectedAddress: Address? = nil
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack {
            // Progress header
            ProgressHeaderView(notesStore: notesStore)
                .padding(.horizontal)
                .padding(.top)
            
            // Notes list
            notesListView
        }
        .navigationTitle("Notes & Questions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showClearAllAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .disabled(notesStore.notes.isEmpty)
            }
        }
        .onAppear {
            loadNotes()
        }
        .onReceive(serviceContainer.notesService.notesStorePublisher) { _ in
            loadNotes()
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Clear All Notes", isPresented: $showClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllNotes()
            }
        } message: {
            Text("This will delete all notes, clear chat history, and reset to default questions. Are you sure?")
        }
    }
    
    // MARK: - View Components
    
    private var notesListView: some View {
        List {
            ForEach(QuestionCategory.allCases, id: \.self) { category in
                categorySection(for: category)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    @ViewBuilder
    private func categorySection(for category: QuestionCategory) -> some View {
        let categoryQuestions = notesStore.questions(in: category)
        if !categoryQuestions.isEmpty {
            Section(header: categoryHeader(for: category)) {
                ForEach(categoryQuestions, id: \.id) { question in
                    noteRow(for: question)
                }
            }
        }
    }
    
    private func categoryHeader(for category: QuestionCategory) -> some View {
        HStack {
            Image(systemName: category.iconName)
            Text(category.rawValue)
        }
    }
    
    private func noteRow(for question: Question) -> some View {
        let note = notesStore.notes[question.id]
        let isEditing = editingNoteId == question.id
        
        return NoteRowView(
            question: question,
            note: note,
            isEditing: isEditing,
            editingText: $editingText,
            isTextFieldFocused: $isTextFieldFocused,
            isLoadingAddress: isLoadingAddress && question.text == "Is this the right address?",
            onEdit: {
                print("Edit button tapped for question: \(question.text)")
                startEditing(question: question)
            },
            onSave: {
                saveNote(for: question)
            },
            onCancel: {
                cancelEditing()
            },
            onClear: {
                print("Clearing text, keeping edit session open")
                editingText = ""
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadNotes() {
        Task {
            do {
                notesStore = try await serviceContainer.notesService.loadNotesStore()
            } catch {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    private func startEditing(question: Question) {
        print("Starting edit for question: \(question.text)")
        editingNoteId = question.id
        let currentAnswer = notesStore.note(for: question)?.answer ?? ""
        
        // Check if this is the address question and no answer exists
        if question.text == "Is this the right address?" && currentAnswer.isEmpty {
            // Try to get current location and lookup address
            isLoadingAddress = true
            Task {
                do {
                    let location = try await serviceContainer.locationService.getCurrentLocation()
                    let address = try await serviceContainer.locationService.lookupAddress(for: location)
                    
                    await MainActor.run {
                        detectedAddress = address
                        editingText = address.fullAddress
                        originalText = ""  // Keep original as empty so they can cancel
                        isLoadingAddress = false
                        
                        // Focus the text field
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        isLoadingAddress = false
                        // If location fails, just use empty text
                        editingText = currentAnswer
                        originalText = currentAnswer
                        
                        // Show error message
                        alertMessage = "Could not detect your address. Please enter it manually."
                        showingAlert = true
                        
                        // Focus the text field
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }
                }
            }
        } else {
            // Normal editing flow
            print("Current answer: '\(currentAnswer)'")
            editingText = currentAnswer
            originalText = currentAnswer
            print("Stored original text: '\(originalText)'")
            
            // Focus the text field and position cursor at end
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
                // Trigger cursor to end by appending and removing empty string
                let temp = editingText
                editingText = temp + " "
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    editingText = temp
                }
            }
        }
    }
    
    private func saveNote(for question: Question) {
        Task {
            do {
                print("Saving note for question: \(question.text)")
                print("Answer text: '\(editingText)'")
                
                // Save the answer - empty text is allowed and makes it unanswered
                let trimmedText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                try await serviceContainer.notesService.saveOrUpdateNote(
                    for: question.id,
                    answer: trimmedText
                )
                
                // If this is the address question, save address and trigger house name generation
                if question.text == "Is this the right address?" && !trimmedText.isEmpty {
                    // If we have a detected address with coordinates, use it
                    if let detectedAddr = self.detectedAddress {
                        // Parse the user's edited address while keeping detected coordinates
                        let finalAddress = AddressParser.parseAddress(trimmedText, coordinate: detectedAddr.coordinate) ?? detectedAddr
                        
                        // Save to UserDefaults
                        if let encoded = try? JSONEncoder().encode(finalAddress) {
                            UserDefaults.standard.set(encoded, forKey: "confirmedHomeAddress")
                        }
                        
                        // Save using LocationService method
                        try? await serviceContainer.locationService.confirmAddress(finalAddress)
                    }
                    
                    // Generate and save house name from the address
                    let houseName = AddressParser.generateHouseNameFromAddress(trimmedText)
                    if houseName != "My House" {
                        await serviceContainer.notesService.saveHouseName(houseName)
                    }
                }
                
                print("Successfully saved note")
                
                // Update UI on main thread
                await MainActor.run {
                    cancelEditing()
                }
                
                // Reload notes after a short delay to ensure save is complete
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await MainActor.run {
                    loadNotes()
                }
            } catch {
                print("Error saving note: \(error)")
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func cancelEditing() {
        print("Canceling edit, restoring original text: '\(originalText)'")
        // Restore original text if we were editing
        if editingNoteId != nil {
            editingText = originalText
        }
        editingNoteId = nil
        editingText = ""
        originalText = ""
        isTextFieldFocused = false
    }
    
    private func clearAllNotes() {
        Task {
            do {
                // Clear all notes data
                try await serviceContainer.notesService.clearAllData()
                
                // Post notification on main thread to clear chat history
                await MainActor.run {
                    NotificationCenter.default.post(name: Notification.Name("ClearChatHistory"), object: nil)
                    print("Posted ClearChatHistory notification")
                }
                
                // Reload to show empty state
                loadNotes()
                
                print("Successfully cleared all notes data")
            } catch {
                alertMessage = "Failed to clear notes: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

// MARK: - Subviews

struct ProgressHeaderView: View {
    let notesStore: NotesStoreData
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text("\(Int(notesStore.completionPercentage))%")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: notesStore.completionPercentage / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            Text("\(notesStore.questions.filter { notesStore.isAnswered($0) }.count) of \(notesStore.questions.count) questions answered")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct NoteRowView: View {
    let question: Question
    let note: Note?
    let isEditing: Bool
    @Binding var editingText: String
    var isTextFieldFocused: FocusState<Bool>.Binding
    let isLoadingAddress: Bool
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Question text
            HStack {
                Text(question.text)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if question.isRequired {
                    Text("Required")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if !isEditing {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            
            // Hint text if available
            if let hint = question.hint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Answer/Note section
            if isEditing {
                // Edit mode with TextEditor
                VStack(spacing: 8) {
                    if isLoadingAddress {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Detecting your address...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    // Buttons above text box to avoid keyboard covering them
                    HStack {
                        Button(action: {
                            print("Cancel button tapped")
                            onCancel()
                        }) {
                            Text("Cancel")
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Spacer()
                        
                        Button(action: {
                            print("Clear button tapped")
                            onClear()
                        }) {
                            Text("Clear")
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Spacer()
                        
                        Button(action: {
                            print("Save button tapped")
                            onSave()
                        }) {
                            Text("Save")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    TextEditor(text: $editingText)
                        .frame(minHeight: 80)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .focused(isTextFieldFocused)
                }
                .padding(.top, 4)
            } else {
                // View mode
                if let note = note, note.isAnswered {
                    Text(note.answer)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                } else {
                    HStack {
                        Text("Tap edit to add answer...")
                            .font(.body)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                            .italic()
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Metadata (last modified)
            if let note = note, note.isAnswered && !isEditing {
                Text("Last updated: \(note.lastModified, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationView {
        NotesView()
            .environmentObject(ServiceContainer.shared)
    }
}
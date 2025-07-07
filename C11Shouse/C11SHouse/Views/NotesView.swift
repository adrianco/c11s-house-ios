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
    @State private var isEditMode = false
    @State private var editingNoteId: UUID? = nil
    @State private var editingText: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
                    withAnimation {
                        isEditMode.toggle()
                        if !isEditMode {
                            cancelEditing()
                        }
                    }
                }) {
                    Text(isEditMode ? "Done" : "Edit")
                        .fontWeight(.medium)
                }
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
        let note = notesStore.notes.first(where: { $0.questionId == question.id })
        let isEditing = editingNoteId == question.id
        
        return NoteRowView(
            question: question,
            note: note,
            isEditMode: isEditMode,
            isEditing: isEditing,
            editingText: $editingText,
            onTap: {
                if isEditMode {
                    startEditing(question: question)
                }
            },
            onSave: {
                saveNote(for: question)
            },
            onCancel: {
                cancelEditing()
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
        editingNoteId = question.id
        editingText = notesStore.note(for: question)?.answer ?? ""
    }
    
    private func saveNote(for question: Question) {
        Task {
            do {
                try await serviceContainer.notesService.saveOrUpdateNote(
                    for: question.id,
                    answer: editingText
                )
                cancelEditing()
                loadNotes()
            } catch {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    private func cancelEditing() {
        editingNoteId = nil
        editingText = ""
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
    let isEditMode: Bool
    let isEditing: Bool
    @Binding var editingText: String
    let onTap: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    
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
                
                if isEditMode && !isEditing {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
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
                    TextEditor(text: $editingText)
                        .frame(minHeight: 80)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    
                    HStack {
                        Button(action: onCancel) {
                            Text("Cancel")
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Button(action: onSave) {
                            Text("Save")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
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
                    Text("Tap to add answer...")
                        .font(.body)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .italic()
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
        .onTapGesture {
            if isEditMode && !isEditing {
                onTap()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEditMode && !isEditing ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    NavigationView {
        NotesView()
            .environmentObject(ServiceContainer.shared)
    }
}
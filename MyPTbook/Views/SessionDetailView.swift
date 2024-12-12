import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    let session: Session
    @State private var isEditing = false
    @State private var exercises: [Exercise]
    @State private var showingAddExercise = false
    @State private var showingDeleteAlert = false
    
    // MARK: - Initialization
    init(session: Session) {
        self.session = session
        _exercises = State(initialValue: session.exercises)
    }
    
    // MARK: - Main View
    var body: some View {
        VStack(spacing: 0) {
            headerView
            exerciseListView
            bottomButtonsView
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: navigationBarButtons)
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteSession() }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView { exercise in
                exercises.append(exercise)
                saveChanges()
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(alignment: .center, spacing: 8) {  // Increased spacing for better readability
            Text("Session \(session.sessionNumber)")
                .font(.title.bold())  // Using system font with bold weight
            Text("\(exercises.count) exercises")
                .font(.subheadline)
                .foregroundColor(.secondary)  // Using semantic colors
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)  // Increased padding for better touch targets
    }
    
    // MARK: - Exercise List
    private var exerciseListView: some View {
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    exerciseRow(exercise: exercise, index: index)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    if index < exercises.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    // MARK: - Exercise Row
    private func exerciseRow(exercise: Exercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {  // Increased spacing
            HStack(alignment: .center, spacing: 12) {
                Text("\(index + 1).")
                    .font(.body.bold())
                    .frame(width: 30, alignment: .leading)
                    .foregroundColor(.primary)
                
                if isEditing {
                    TextField("Exercise name", text: Binding(
                        get: { exercise.name },
                        set: { newValue in
                            exercises[index].name = newValue
                            saveChanges()
                        }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.body.bold())
                } else {
                    Text(exercise.name)
                        .font(.body.bold())
                }
                
                Spacer()
                
                if isEditing {
                    Button(action: { 
                        exercises.remove(at: index)
                        saveChanges()
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                            .imageScale(.large)
                            .frame(width: 44, height: 44)  // Minimum touch target
                    }
                }
            }
            
            if !exercise.name.isEmpty {
                HStack(spacing: 20) {
                    // Sets
                    HStack(spacing: 8) {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(Colors.nasmBlue)
                            .imageScale(.large)
                        
                        if isEditing {
                            TextField("Sets", value: Binding(
                                get: { exercise.sets },
                                set: { newValue in
                                    exercises[index].sets = newValue
                                    saveChanges()
                                }
                            ), formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                        } else {
                            Text("\(exercise.sets) sets")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Reps
                    HStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(Colors.nasmBlue)
                            .imageScale(.large)
                        
                        if isEditing {
                            TextField("Reps", text: Binding(
                                get: { exercise.reps },
                                set: { newValue in
                                    exercises[index].reps = newValue
                                    saveChanges()
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Text(exercise.reps.isEmpty ? "-- reps" : exercise.reps)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 42)
            }
        }
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtonsView: some View {
        Group {
            if !session.isCompleted {
                HStack(spacing: 16) {
                    if isEditing {
                        addExerciseButton
                    } else {
                        completeSessionButton
                    }
                    editButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    Color(UIColor.systemBackground)
                }
            }
        }
    }
    
    private var addExerciseButton: some View {
        Button(action: { showingAddExercise = true }) {
            Text("Add Exercise")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Colors.nasmBlue)
                .cornerRadius(10)
        }
    }
    
    private var completeSessionButton: some View {
        Button(action: completeSession) {
            Text("Complete Session")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Colors.nasmBlue)
                .cornerRadius(10)
        }
    }
    
    private var editButton: some View {
        Button(action: { 
            isEditing.toggle()
            if !isEditing { saveChanges() }
        }) {
            Text(isEditing ? "Done" : "Edit")
                .font(.headline)
                .foregroundColor(Colors.nasmBlue)
                .frame(width: 80)
                .frame(height: 44)
                .background(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Colors.nasmBlue, lineWidth: 1)
                )
        }
    }
    
    private var navigationBarButtons: some View {
        Group {
            if !isEditing {
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)  // Minimum touch target
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func completeSession() {
        var updatedSession = session
        updatedSession.isCompleted = true
        saveSession(updatedSession)
        dismiss()
    }
    
    private func saveChanges() {
        var updatedSession = session
        updatedSession.exercises = exercises
        saveSession(updatedSession)
    }
    
    private func saveSession(_ updatedSession: Session) {
        var clients = DataManager.shared.getClients()
        if let clientIndex = clients.firstIndex(where: { $0.sessions.contains(where: { $0.id == session.id }) }),
           let sessionIndex = clients[clientIndex].sessions.firstIndex(where: { $0.id == session.id }) {
            clients[clientIndex].sessions[sessionIndex] = updatedSession
            DataManager.shared.saveClients(clients)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshClientData"), object: nil)
        }
    }
    
    private func deleteSession() {
        var clients = DataManager.shared.getClients()
        if let clientIndex = clients.firstIndex(where: { $0.sessions.contains(where: { $0.id == session.id }) }) {
            clients[clientIndex].sessions.removeAll(where: { $0.id == session.id })
            DataManager.shared.saveClients(clients)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshClientData"), object: nil)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// Add Exercise View
struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sets = ""
    @State private var reps = ""
    
    var onAdd: (Exercise) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise Name", text: $name)
                TextField("Sets (e.g., 3)", text: $sets)
                    .keyboardType(.numberPad)
                TextField("Reps (e.g., 8-12)", text: $reps)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let setsValue = Int(sets) else { return }
                        
                        // Clean the reps by handling ranges with dashes
                        let cleanReps = reps.trimmingCharacters(in: .whitespaces)
                        
                        let exercise = Exercise(
                            name: cleanExerciseName(name),
                            sets: setsValue,
                            reps: cleanReps
                        )
                        onAdd(exercise)
                        dismiss()
                    }
                    .disabled(name.isEmpty || sets.isEmpty || reps.isEmpty)
                }
            }
        }
    }
    
    private func cleanExerciseName(_ name: String) -> String {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        
        // Handle special cases for exercises ending with "ups"
        let lowerName = cleanName.lowercased()
        if lowerName == "pull" {
            return "Pull-Ups"
        } else if lowerName == "step" {
            return "Step-Ups"
        } else if lowerName.hasSuffix("-ups") {
            // Properly capitalize other exercises ending with "-ups"
            let base = String(cleanName.dropLast(4))
            return base.capitalized + "-Ups"
        }
        
        return cleanName
    }
}

import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @State private var isEditing = false
    @State private var exercises: [Exercise]
    @State private var showingAddExercise = false
    
    init(session: WorkoutSession) {
        self.session = session
        _exercises = State(initialValue: session.exercises)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            ScrollView {
                VStack(spacing: 16) {
                    // Session Header
                    HStack {
                        Text("Session \(session.sessionNumber)")
                            .font(.title2.bold())
                        Spacer()
                        Text("\(exercises.count) exercises")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Exercises List
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                // Exercise Number
                                Text("\(index + 1).")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Exercise Name
                                    Text(exercise.name)
                                        .font(.headline)
                                    
                                    // Sets and Reps
                                    HStack {
                                        Image(systemName: "number.circle.fill")
                                            .foregroundColor(Colors.nasmBlue)
                                        Text("\(exercise.sets) sets")
                                            .foregroundColor(.gray)
                                        
                                        Image(systemName: "figure.walk.circle.fill")
                                            .foregroundColor(Colors.nasmBlue)
                                        Text("\(exercise.reps) reps")
                                            .foregroundColor(.gray)
                                    }
                                    .font(.subheadline)
                                }
                                
                                Spacer()
                                
                                if isEditing {
                                    Button(action: { deleteExercise(exercise) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            
                            if let notes = exercise.notes {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            
            // Bottom Buttons - Only show if session is not completed
            if !session.isCompleted {
                HStack(spacing: 16) {
                    // Complete Session Button
                    Button(action: completeSession) {
                        Text("Complete Session")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Colors.nasmBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Edit Button
                    Button(action: { isEditing.toggle() }) {
                        Text("Edit")
                            .font(.headline)
                            .foregroundColor(Colors.nasmBlue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Colors.nasmBlue, lineWidth: 2)
                            )
                    }
                }
                .padding()
                .background(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
            }
        }
        .background(Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddExercise = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView { exercise in
                exercises.append(exercise)
                saveChanges()
            }
        }
    }
    
    private func deleteExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
        saveChanges()
    }
    
    private func completeSession() {
        var updatedSession = session
        updatedSession.isCompleted = true
        
        // Update the session in the client's sessions array
        var clients = DataManager.shared.getClients()
        if let clientIndex = clients.firstIndex(where: { $0.sessions.contains(where: { $0.id == session.id }) }),
           let sessionIndex = clients[clientIndex].sessions.firstIndex(where: { $0.id == session.id }) {
            clients[clientIndex].sessions[sessionIndex] = updatedSession
            DataManager.shared.saveClients(clients)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshClientData"), object: nil)
        }
        
        dismiss()
    }
    
    private func saveChanges() {
        var clients = DataManager.shared.getClients()
        if let clientIndex = clients.firstIndex(where: { $0.sessions.contains(where: { $0.id == session.id }) }),
           let sessionIndex = clients[clientIndex].sessions.firstIndex(where: { $0.id == session.id }) {
            clients[clientIndex].sessions[sessionIndex].exercises = exercises
            DataManager.shared.saveClients(clients)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshClientData"), object: nil)
        }
    }
}

// Add Exercise View
struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var notes = ""
    
    var onAdd: (Exercise) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise Name", text: $name)
                TextField("Sets", text: $sets)
                    .keyboardType(.numberPad)
                TextField("Reps", text: $reps)
                TextField("Notes (optional)", text: $notes)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let exercise = Exercise(
                            name: name,
                            sets: Int(sets) ?? 3,
                            reps: reps,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onAdd(exercise)
                        dismiss()
                    }
                    .disabled(name.isEmpty || sets.isEmpty || reps.isEmpty)
                }
            }
        }
    }
} 

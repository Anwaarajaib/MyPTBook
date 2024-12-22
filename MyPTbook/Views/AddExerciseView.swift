import SwiftUI

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataManager = DataManager.shared
    let session: Session
    
    @State private var exerciseName = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var time = ""
    @State private var groupType: Exercise.GroupType?
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $exerciseName)
                    
                    TextField("Sets", text: $sets)
                        .keyboardType(.numberPad)
                    
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                    
                    TextField("Weight (kg)", text: $weight)
                        .keyboardType(.decimalPad)
                    
                    TextField("Time (seconds)", text: $time)
                        .keyboardType(.numberPad)
                }
                
                Section("Exercise Type") {
                    Picker("Type", selection: $groupType) {
                        Text("Regular").tag(Optional<Exercise.GroupType>.none)
                        Text("Superset").tag(Optional<Exercise.GroupType>.some(.superset))
                        Text("Circuit").tag(Optional<Exercise.GroupType>.some(.circuit))
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveExercise()
                    }
                    .disabled(exerciseName.isEmpty || isProcessing)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "An unknown error occurred")
            }
        }
    }
    
    private func saveExercise() {
        isProcessing = true
        
        Task {
            do {
                let exercise = Exercise(
                    _id: "",
                    exerciseName: exerciseName,
                    sets: Int(sets) ?? 0,
                    reps: Int(reps) ?? 0,
                    weight: Double(weight) ?? 0,
                    time: Int(time),
                    groupType: groupType,
                    session: session._id
                )
                
                print("AddExerciseView: Creating exercise for session:", session._id)
                let savedExercise = try await dataManager.createExercise(exercise: exercise)
                print("AddExerciseView: Exercise created successfully:", savedExercise)
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    self.error = "Failed to save exercise: \(error.localizedDescription)"
                    showingError = true
                    print("AddExerciseView: Error creating exercise:", error)
                }
            }
        }
    }
} 
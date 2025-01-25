import SwiftUI

struct AddSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataManager = DataManager.shared
    let client: Client
    
    // Session properties
    @State private var workoutName = ""
    @State private var exercises: [Exercise] = []
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showingError = false
    
    // Add state objects for each exercise field
    @State private var exerciseNames: [String] = []
    @State private var exerciseSets: [String] = []
    @State private var exerciseReps: [String] = []
    @State private var exerciseGroupTypes: [Exercise.GroupType?] = []
    @State private var showingGroupTypeSheet = false
    @State private var selectedGroupIndex: Int?
    
    // Add focus states
    @FocusState private var focusedSetsField: Int?
    @FocusState private var focusedRepsField: Int?
    
    // Add these state variables at the top with other @State properties
    @State private var selectedExerciseType: ExerciseType = .single
    
    // Add this enum
    private enum ExerciseType {
        case single, superset, circuit
        
        var icon: String {
            switch self {
            case .single: return "figure.strengthtraining.traditional"
            case .superset: return "arrow.triangle.2.circlepath"
            case .circuit: return "arrow.3.trianglepath"
            }
        }
        
        var title: String {
            switch self {
            case .single: return "Exercise"
            case .superset: return "Superset"
            case .circuit: return "Circuit"
            }
        }
    }
    
    // Add this enum
    private enum ExerciseMetricType {
        case reps, time
    }
    
    // Add state variable for metric type
    @State private var exerciseMetricTypes: [ExerciseMetricType] = []
    
    // Initialize with one empty exercise
    init(client: Client) {
        self.client = client
        _exercises = State(initialValue: [])
        _exerciseNames = State(initialValue: [])
        _exerciseSets = State(initialValue: [])
        _exerciseReps = State(initialValue: [])
        _exerciseGroupTypes = State(initialValue: [])
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Session Header Card
                        VStack(spacing: 12) {
                            // Workout Name
                            TextField("Workout Name", text: $workoutName)
                                .font(.title3.bold())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            
                            Divider()
                                .foregroundColor(Color.gray.opacity(0.2))
                            
                            // Exercise List
                            VStack(spacing: 0) {
                                ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                                    VStack(spacing: 0) {
                                        exerciseRow(exercise: exercise, index: index)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, exerciseGroupTypes[index] != nil ? 4 : 8)
                                        
                                        if index < exercises.count - 1 &&
                                           (exerciseGroupTypes[index] == nil ||
                                            exerciseGroupTypes[index] != exerciseGroupTypes[index + 1]) {
                                            Divider()
                                                .padding(.horizontal, 20)
                                        }
                                    }
                                }
                                
                                // Add Exercise Button
                                addExerciseButtons
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        Color.clear.frame(height: 60)
                    }
                    .padding(.vertical)
                }
                .background(Colors.background)
                
                // Bottom Save Button
                saveButton
                    .background(Colors.background)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "An unknown error occurred")
            }
        }
    }
    
    private func exerciseRow(exercise: Exercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let groupType = exerciseGroupTypes[index],
               isFirstInGroup(at: index) {
                HStack(alignment: .center, spacing: 8) {
                    Text("\(displayNumber(for: index)).")
                        .font(.body.bold())
                        .frame(width: 30, alignment: .leading)
                    
                    GroupTypeHeader(
                        type: groupType,
                        sets: Binding(
                            get: { exerciseSets[index] },
                            set: { newValue in
                                // Update sets for all exercises in the group
                                var currentIndex = index
                                while currentIndex < exercises.count &&
                                      exerciseGroupTypes[currentIndex] == groupType {
                                    exerciseSets[currentIndex] = newValue
                                    currentIndex += 1
                                }
                            }
                        )
                    )
                    
                    Spacer()
                }
                .padding(.bottom, 4)
            }
            
            // Exercise Name Row
            HStack(alignment: .center, spacing: 8) {
                if exerciseGroupTypes[index] == nil {
                    Text("\(displayNumber(for: index)).")
                        .font(.body.bold())
                        .frame(width: 30, alignment: .leading)
                } else {
                    Color.clear
                        .frame(width: 30, alignment: .leading)
                }
                
                HStack {
                    // Create an HStack for the name and bullet point
                    HStack(spacing: 4) {
                        if exerciseGroupTypes[index] != nil {
                            // Bullet point before exercise name
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.primary.opacity(0.6))
                        }
                        
                        TextField("Exercise name", text: $exerciseNames[index])
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(height: 32)
                            .font(.body.bold())
                            .foregroundColor(.primary)
                            .accentColor(Colors.nasmBlue)
                            .onChange(of: exerciseNames[index]) { _, newValue in
                                var updatedExercise = exercises[index]
                                updatedExercise.exerciseName = newValue
                                exercises[index] = updatedExercise
                            }
                    }
                    
                    Button(action: {
                        exercises.remove(at: index)
                        exerciseNames.remove(at: index)
                        exerciseSets.remove(at: index)
                        exerciseReps.remove(at: index)
                        exerciseGroupTypes.remove(at: index)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            
            // Reps/Time Picker and Input
            HStack(spacing: 24) {
                // Sets (if not in a group)
                if exerciseGroupTypes[index] == nil {
                    // Show both sets and reps for single exercises
                    HStack(spacing: 8) {
                        // Sets
                        HStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundColor(Colors.nasmBlue)
                                .imageScale(.large)
                            
                            TextField("", text: $exerciseSets[index])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60, height: 32)
                                .font(.body.bold())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .focused($focusedSetsField, equals: index)
                                .overlay(
                                    Text("Sets")
                                        .font(.body.bold())
                                        .foregroundColor(Color(.placeholderText))
                                        .opacity(exerciseSets[index].isEmpty && focusedSetsField != index ? 1 : 0)
                                )
                                .onChange(of: exerciseSets[index]) { _, newValue in
                                    if let value = Int(newValue.trimmingCharacters(in: .whitespaces)) {
                                        var updatedExercise = exercises[index]
                                        updatedExercise.sets = value
                                        exercises[index] = updatedExercise
                                    }
                                }
                        }
                        
                        // Reps/Time Input
                        HStack(spacing: 8) {
                            TextField("", text: $exerciseReps[index])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60, height: 32)
                                .font(.body.bold())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .overlay(
                                    Text(exerciseMetricTypes[index] == .reps ? "Reps" : "Sec")
                                        .font(.body.bold())
                                        .foregroundColor(Color(.placeholderText))
                                        .opacity(exerciseReps[index].isEmpty ? 1 : 0)
                                )
                            
                            // Move the type selector here
                            HStack(spacing: 0) {
                                ForEach([ExerciseMetricType.reps, .time], id: \.self) { type in
                                    Button(action: {
                                        exerciseMetricTypes[index] = type
                                        var updatedExercise = exercises[index]
                                        if type == .reps {
                                            updatedExercise.reps = Int(exerciseReps[index]) ?? 0
                                            updatedExercise.time = nil
                                        } else {
                                            updatedExercise.time = Int(exerciseReps[index])
                                            updatedExercise.reps = 0
                                        }
                                        exercises[index] = updatedExercise
                                    }) {
                                        Text(type == .reps ? "Reps" : "Time")
                                            .font(.footnote.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(exerciseMetricTypes[index] == type ? Colors.nasmBlue : Color.clear)
                                            .foregroundColor(exerciseMetricTypes[index] == type ? .white : Colors.nasmBlue)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Colors.nasmBlue, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(width: 120)
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 30)
                } else {
                    // Only show reps for grouped exercises
                    HStack(spacing: 24) {
                        // Reps only
                        HStack(spacing: 8) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(Colors.nasmBlue)
                                .imageScale(.large)
                            
                            TextField("", text: $exerciseReps[index])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60, height: 32)
                                .font(.body.bold())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .focused($focusedRepsField, equals: index)
                                .overlay(
                                    Text("Reps")
                                        .font(.body.bold())
                                        .foregroundColor(Color(.placeholderText))
                                        .opacity(exerciseReps[index].isEmpty && focusedRepsField != index ? 1 : 0)
                                )
                                .onChange(of: exerciseReps[index]) { _, newValue in
                                    if let value = Int(newValue.trimmingCharacters(in: .whitespaces)) {
                                        var updatedExercise = exercises[index]
                                        updatedExercise.reps = value
                                        exercises[index] = updatedExercise
                                    }
                                }
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 30)
                }
                
                // Add "Add to Circuit" button if this is the last exercise in a circuit
                if let groupType = exerciseGroupTypes[index],
                   groupType == .circuit,
                   isLastInGroup(at: index) {
                    Button(action: {
                        addExerciseToCircuit(afterIndex: index)
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Circuit")
                                .font(.footnote.bold())
                        }
                        .foregroundColor(Colors.nasmBlue)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var addExerciseButtons: some View {
        VStack(spacing: 12) {
            // Exercise Type Picker
            HStack(spacing: 0) {
                ForEach([ExerciseType.single, .superset, .circuit], id: \.self) { type in
                    Button(action: { selectedExerciseType = type }) {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .imageScale(.small)
                            Text(type.title)
                                .font(.footnote.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedExerciseType == type ? Colors.nasmBlue : Color.clear)
                        .foregroundColor(selectedExerciseType == type ? .white : Colors.nasmBlue)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Colors.nasmBlue, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            
            // Original style Add Exercise Button
            Button(action: {
                switch selectedExerciseType {
                case .single:
                    addNewExercise()
                case .superset:
                    addNewExerciseGroup(.superset)
                case .circuit:
                    addNewExerciseGroup(.circuit)
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add \(selectedExerciseType.title)")
                }
                .foregroundColor(Colors.nasmBlue)
                .padding(.vertical, 12)
            }
        }
    }
    
    private func addNewExercise() {
        let newExercise = Exercise(
            _id: "",
            exerciseName: "",
            sets: 0,
            reps: 0,
            weight: 0,
            time: nil,
            groupType: nil,
            session: ""
        )
        
        withAnimation {
            exercises.append(newExercise)
            exerciseNames.append("")
            exerciseSets.append("")
            exerciseReps.append("")
            exerciseGroupTypes.append(nil)
            exerciseMetricTypes.append(.reps)
        }
    }
    
    private func addNewExerciseGroup(_ groupType: Exercise.GroupType) {
        // Generate a unique group ID for this specific group
        let groupId = UUID().uuidString
        let count = groupType == .superset ? 2 : 3
        
        withAnimation {
            for _ in 0..<count {
                let newExercise = Exercise(
                    _id: "",
                    exerciseName: "",
                    sets: 0,
                    reps: 0,
                    weight: 0,
                    time: nil,
                    groupType: groupType,
                    groupId: groupId,  // Use the same groupId for exercises in this group
                    session: ""
                )
                
                exercises.append(newExercise)
                exerciseNames.append("")
                exerciseSets.append("")
                exerciseReps.append("")
                exerciseGroupTypes.append(groupType)
                exerciseMetricTypes.append(.reps)
            }
        }
    }
    
    private func addExerciseToCircuit(afterIndex: Int) {
        // Get the groupId from the exercise we're adding to
        guard let groupId = exercises[afterIndex].groupId else { return }
        
        let newExercise = Exercise(
            _id: "",
            exerciseName: "",
            sets: 0,
            reps: 0,
            weight: 0,
            time: nil,
            groupType: .circuit,
            groupId: groupId,  // Use the same groupId as the circuit we're adding to
            session: ""
        )
        
        withAnimation {
            exercises.insert(newExercise, at: afterIndex + 1)
            exerciseNames.insert("", at: afterIndex + 1)
            exerciseSets.insert("", at: afterIndex + 1)
            exerciseReps.insert("", at: afterIndex + 1)
            exerciseGroupTypes.insert(.circuit, at: afterIndex + 1)
            exerciseMetricTypes.insert(.reps, at: afterIndex + 1)
        }
    }
    
    private var saveButton: some View {
        Button(action: saveSession) {
            HStack {
                Text(isProcessing ? "Adding..." : "Add Session")
                    .fontWeight(.semibold)
                
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                        .padding(.leading, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(workoutName.isEmpty ? Color.gray.opacity(0.3) : Colors.nasmBlue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(workoutName.isEmpty || isProcessing)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func saveSession() {
        // Validation
        guard !workoutName.isEmpty else {
            error = "Please enter a workout name"
            showingError = true
            return
        }
        
        // Validate exercises
        for (index, _) in exercises.enumerated() {
            guard !exerciseNames[index].isEmpty else {
                error = "Please fill in all exercise names"
                showingError = true
                return
            }
            
            guard Int(exerciseSets[index]) ?? 0 > 0 else {
                error = "Please enter valid sets for all exercises"
                showingError = true
                return
            }
            
            guard Int(exerciseReps[index]) ?? 0 > 0 else {
                error = "Please enter valid reps for all exercises"
                showingError = true
                return
            }
        }
        
        // Dismiss immediately
        dismiss()
        
        Task {
            isProcessing = true
            do {
                // 1. Create the session
                let newSession = try await dataManager.createSession(
                    for: client._id,
                    workoutName: workoutName,
                    isCompleted: false,
                    completedDate: nil
                )
                
                // 2. Create exercises sequentially to maintain order
                for index in 0..<exercises.count {
                    let exercise = Exercise(
                        _id: "",
                        exerciseName: exerciseNames[index],
                        sets: Int(exerciseSets[index]) ?? 0,
                        reps: Int(exerciseReps[index]) ?? 0,
                        weight: 0,
                        time: nil,
                        groupType: exerciseGroupTypes[index],
                        groupId: exercises[index].groupId,  // Add this line to include groupId
                        session: newSession._id
                    )
                    
                    // Create exercise data dictionary with all fields including groupId
                    let exerciseData: [String: Any] = [
                        "exerciseName": exercise.exerciseName,
                        "sets": exercise.sets,
                        "reps": exercise.reps,
                        "weight": exercise.weight,
                        "time": exercise.time as Any,
                        "groupType": exercise.groupType?.rawValue as Any,
                        "groupId": exercise.groupId as Any,  // Include groupId in the request
                        "session": exercise.session
                    ]
                    
                    _ = try await dataManager.createExercise(exerciseData: exerciseData)
                }
                
                await MainActor.run {
                    isProcessing = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshClientData"),
                        object: nil
                    )
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    self.error = "Failed to save session: \(error.localizedDescription)"
                    showingError = true
                    print("Save error:", error)
                }
            }
        }
    }
    
    private struct GroupTypeHeader: View {
        let type: Exercise.GroupType
        @Binding var sets: String
        
        var body: some View {
            HStack(spacing: 6) {
                // Group type indicator
                HStack(spacing: 6) {
                    Image(systemName: type == .superset ? "arrow.triangle.2.circlepath" : "arrow.3.trianglepath")
                        .imageScale(.large)
                    Text(type == .superset ? "Superset" : "Circuit")
                        .font(.headline)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Colors.nasmBlue.opacity(0.1))
                .cornerRadius(6)
                .foregroundColor(.primary)
                
                // Sets input
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(Colors.nasmBlue)
                        .imageScale(.large)
                    
                    TextField("", text: $sets)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60, height: 32)
                        .font(.body.bold())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .overlay(
                            Text("Sets")
                                .font(.body.bold())
                                .foregroundColor(Color(.placeholderText))
                                .opacity(sets.isEmpty ? 1 : 0)
                        )
                }
            }
        }
    }
    
    // Add this function to check if an exercise is the last one in its group
    private func isLastInGroup(at index: Int) -> Bool {
        guard index < exercises.count - 1 else { return true }
        let currentExercise = exercises[index]
        let nextExercise = exercises[index + 1]
        return currentExercise.groupId != nextExercise.groupId
    }
    
    // Add this helper function to determine if an exercise is the first in its group
    private func isFirstInGroup(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentExercise = exercises[index]
        let previousExercise = exercises[index - 1]
        return currentExercise.groupId != previousExercise.groupId
    }
    
    // Add this helper function to get the display number for an exercise
    private func displayNumber(for index: Int) -> Int {
        var number = 1
        var currentGroupId: String? = nil
        
        for i in 0..<index {
            if let groupId = exercises[i].groupId {
                // If this is the start of a new group
                if currentGroupId == nil || groupId != currentGroupId {
                    number += 1
                    currentGroupId = groupId
                }
                // If it's part of the same group, don't increment
            } else {
                // For non-grouped exercises, always increment
                number += 1
                currentGroupId = nil
            }
        }
        
        return number
    }
}

import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataManager = DataManager.shared
    let session: Session
    
    @State private var exercises: [Exercise] = []
    @State private var isLoading = true
    @State private var showingDeleteAlert = false
    @State private var isEditing = false
    @State private var editedWorkoutName = ""
    @State private var error: String?
    @State private var showingError = false
    @State private var isProcessing = false
    @State private var exerciseNames: [String] = []
    @State private var exerciseSets: [String] = []
    @State private var exerciseReps: [String] = []
    @FocusState private var focusedSetsField: Int?
    @FocusState private var focusedRepsField: Int?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    // Session Header Card
                    VStack(spacing: 12) {
                        headerView
                        
                        if !exercises.isEmpty {
                            Divider()
                                .foregroundColor(Color.gray.opacity(0.2))
                        }
                        
                        exerciseListView
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Add padding at bottom to account for fixed buttons
                    Color.clear.frame(height: 60)
                }
                .padding(.vertical)
            }
            .background(Colors.background)
            
            // Fixed bottom buttons
            if !session.isCompleted {
                bottomButtonsView
                    .background(Colors.background)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarItems
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteSession()
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(error ?? "An unknown error occurred")
        }
        .task {
            await fetchExercises()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Session number and name
                Text("Session \(session.sessionNumber): \(session.workoutName)")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal)
    }
    
    private var exerciseListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                VStack(spacing: 0) {
                    if let groupType = exercise.groupType,
                       isFirstInGroup(at: index) {
                        HStack(alignment: .center, spacing: 8) {
                            Text("\(displayNumber(for: index)).")
                                .font(.body.bold())
                                .frame(width: 30, alignment: .leading)
                            
                            GroupTypeHeader(
                                type: groupType,
                                sets: exercise.sets,
                                isEditing: isEditing,
                                setsText: Binding(
                                    get: { 
                                        guard index < exerciseSets.count else { return "" }
                                        return exerciseSets[index]
                                    },
                                    set: { newValue in
                                        guard index < exerciseSets.count else { return }
                                        // Update sets for all exercises in the group
                                        var currentIndex = index
                                        while currentIndex < exercises.count &&
                                              exercises[currentIndex].groupType == groupType {
                                            exerciseSets[currentIndex] = newValue
                                            currentIndex += 1
                                        }
                                    }
                                )
                            )
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    
                    exerciseRow(exercise: exercise, index: index)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    
                    if index < exercises.count - 1 {
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
            }
            
            // Add this new button when in editing mode
            if isEditing {
                Button(action: addNewExercise) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Exercise")
                    }
                    .foregroundColor(Colors.nasmBlue)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    private func exerciseRow(exercise: Exercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Exercise Name Row
            HStack(alignment: .center, spacing: 8) {
                // Only show number for single exercises (not in a group)
                if exercise.groupType == nil {
                    Text("\(displayNumber(for: index)).")
                        .font(.body.bold())
                        .frame(width: 30, alignment: .leading)
                } else {
                    // Add padding to align with numbered exercises
                    Color.clear
                        .frame(width: 30, alignment: .leading)
                }
                
                if isEditing {
                    HStack {
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
                        
                        Button(action: {
                            if exercises.count > 1 {
                                Task {
                                    do {
                                        // Delete from backend immediately
                                        try await dataManager.deleteExercise(exercises[index])
                                        
                                        // Update local state
                                        await MainActor.run {
                                            exercises.remove(at: index)
                                            exerciseNames.remove(at: index)
                                            exerciseSets.remove(at: index)
                                            exerciseReps.remove(at: index)
                                        }
                                    } catch {
                                        self.error = "Failed to delete exercise"
                                        showingError = true
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 32, height: 32)
                        }
                    }
                } else {
                    Text(exercise.exerciseName)
                        .font(.body.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            if exercise.groupType == nil {
                // Show both sets and reps for single exercises
                HStack(spacing: 24) {
                    // Sets
                    HStack(spacing: 8) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundColor(Colors.nasmBlue)
                            .imageScale(.large)
                        
                        if isEditing {
                            TextField("", text: $exerciseSets[index])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60, height: 32)
                                .font(.body.bold())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .focused($focusedSetsField, equals: index)
                                .overlay(
                                    Text("Sets")
                                        .font(.body.bold())
                                        .foregroundColor(Color(.placeholderText))
                                        .opacity(exerciseSets[index].isEmpty && focusedSetsField != index ? 1 : 0)
                                )
                        } else {
                            Text("\(exercise.sets) sets")
                                .font(.body.bold())
                        }
                    }
                    
                    // Reps
                    HStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(Colors.nasmBlue)
                            .imageScale(.large)
                        
                        if isEditing {
                            TextField("", text: $exerciseReps[index])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60, height: 32)
                                .font(.body.bold())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .focused($focusedRepsField, equals: index)
                                .overlay(
                                    Text("Reps")
                                        .font(.body.bold())
                                        .foregroundColor(Color(.placeholderText))
                                        .opacity(exerciseReps[index].isEmpty && focusedRepsField != index ? 1 : 0)
                                )
                        } else {
                            Text("\(exercise.reps) reps")
                                .font(.body.bold())
                        }
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
                        
                        if isEditing {
                            TextField("", text: $exerciseReps[index])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60, height: 32)
                                .font(.body.bold())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .focused($focusedRepsField, equals: index)
                                .overlay(
                                    Text("Reps")
                                        .font(.body.bold())
                                        .foregroundColor(Color(.placeholderText))
                                        .opacity(exerciseReps[index].isEmpty && focusedRepsField != index ? 1 : 0)
                                )
                        } else {
                            Text("\(exercise.reps) reps")
                                .font(.body.bold())
                        }
                    }
                    
                    Spacer()
                }
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, isEditing ? 4 : 8)
    }
    
    private var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func fetchExercises() async {
        isLoading = true
        do {
            exercises = try await dataManager.getSessionExercises(sessionId: session._id)
            
            // Initialize the state arrays with the fetched data
            await MainActor.run {
                exerciseNames = exercises.map { $0.exerciseName }
                exerciseSets = exercises.map { String($0.sets) }
                exerciseReps = exercises.map { String($0.reps) }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load exercises"
                showingError = true
                isLoading = false
            }
        }
    }
    
    private func deleteExercise(_ exercise: Exercise) {
        Task {
            do {
                try await dataManager.deleteExercise(exercise)
                await MainActor.run {
                    exercises.removeAll { $0._id == exercise._id }
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to delete exercise"
                    showingError = true
                }
            }
        }
    }
    
    private func deleteSession() {
        Task {
            do {
                try await dataManager.deleteSession(clientId: session.client, sessionId: session._id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to delete session"
                    showingError = true
                }
            }
        }
    }
    
    private func startEditing() {
        editedWorkoutName = session.workoutName
        isEditing = true
    }
    
    private func saveChanges() {
        guard !isProcessing else { return }
        
        Task {
            await MainActor.run {
                isProcessing = true
                error = nil
            }
            
            do {
                var updatedSession = session
                updatedSession.workoutName = editedWorkoutName
                
                try await dataManager.updateSession(clientId: session.client, session: updatedSession)
                
                await MainActor.run {
                    isProcessing = false
                    isEditing = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshClientData"),
                        object: nil
                    )
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    self.error = "Failed to save changes"
                    showingError = true
                }
            }
        }
    }
    
    private func groupedExercises() -> [[Exercise]] {
        var groups: [[Exercise]] = []
        var currentGroup: [Exercise] = []
        var currentGroupType: Exercise.GroupType?
        
        for exercise in exercises {
            if let groupType = exercise.groupType {
                if currentGroupType == groupType {
                    // Continue current group
                    currentGroup.append(exercise)
                } else {
                    // Start new group
                    if !currentGroup.isEmpty {
                        groups.append(currentGroup)
                    }
                    currentGroup = [exercise]
                    currentGroupType = groupType
                }
            } else {
                // No group type - standalone exercise
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                    currentGroup = []
                }
                groups.append([exercise])
                currentGroupType = nil
            }
        }
        
        // Add any remaining group
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    private func toggleCompletion() {
        Task {
            do {
                var updatedSession = session
                updatedSession.isCompleted.toggle()
                updatedSession.completedDate = updatedSession.isCompleted ? Date() : nil
                
                try await dataManager.updateSession(clientId: session.client, session: updatedSession)
                
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshClientData"),
                        object: nil
                    )
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to update session completion status"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtonsView: some View {
        HStack(spacing: 16) {
            if !isEditing {
                completeSessionButton
                    .frame(maxWidth: .infinity)
                editButton
                    .frame(width: 100)
            } else {
                editButton
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var completeSessionButton: some View {
        Button(action: toggleCompletion) {
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
            if isEditing {
                saveChangesWithNewExercises()
            } else {
                // Starting edit mode
                editedWorkoutName = session.workoutName
                isEditing = true
            }
        }) {
            if isEditing {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Colors.nasmBlue)
                    .cornerRadius(10)
            } else {
                Text("Edit")
                    .font(.headline)
                    .foregroundColor(Colors.nasmBlue)
                    .frame(width: 80)
                    .frame(height: 44)
                    .background(Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Colors.nasmBlue, lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Exercise Metric Helper
    private func exerciseMetric(
        icon: String,
        value: String,
        unit: String,
        binding: Binding<String>,
        isEditing: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Colors.nasmBlue)
                .imageScale(.large)
            
            if isEditing {
                TextField("", text: binding)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60, height: 32)
                    .font(.body.bold())
            } else {
                Text("\(value)\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.body.bold())
                    .foregroundColor(.primary)
            }
        }
    }
    
    private func ordinalNumber(_ number: Int) -> String {
        let num = number + 1  // Add 1 since we're 0-based
        switch num {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(num)th"
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
            session: session._id
        )
        
        withAnimation {
            exercises.append(newExercise)
            exerciseNames.append("")
            exerciseSets.append("")
            exerciseReps.append("")
        }
    }
    
    private func saveChangesWithNewExercises() {
        Task {
            do {
                // 1. Save session changes
                var updatedSession = session
                updatedSession.workoutName = editedWorkoutName
                try await dataManager.updateSession(clientId: session.client, session: updatedSession)
                
                // 2. Process all exercises
                for (index, exercise) in exercises.enumerated() {
                    if exercise._id.isEmpty {  // New exercise
                        if !exerciseNames[index].isEmpty && 
                           Int(exerciseSets[index]) ?? 0 > 0 &&
                           Int(exerciseReps[index]) ?? 0 > 0 {
                            
                            let newExercise = Exercise(
                                _id: "",
                                exerciseName: exerciseNames[index],
                                sets: Int(exerciseSets[index]) ?? 0,
                                reps: Int(exerciseReps[index]) ?? 0,
                                weight: 0,
                                time: nil,
                                groupType: nil,
                                session: session._id
                            )
                            
                            _ = try await dataManager.createExercise(exercise: newExercise)
                        }
                    } else {  // Existing exercise
                        var updatedExercise = exercise
                        updatedExercise.exerciseName = exerciseNames[index]
                        updatedExercise.sets = Int(exerciseSets[index]) ?? exercise.sets
                        updatedExercise.reps = Int(exerciseReps[index]) ?? exercise.reps
                        
                        _ = try await dataManager.updateExercise(updatedExercise)
                    }
                }
                
                // 3. Refresh exercises from backend
                await fetchExercises()
                
                await MainActor.run {
                    isEditing = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshClientData"),
                        object: nil
                    )
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to save changes"
                    showingError = true
                }
            }
        }
    }
    
    // Add this helper function to determine if an exercise is the first in its group
    private func isFirstInGroup(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentType = exercises[index].groupType
        let previousType = exercises[index - 1].groupType
        return currentType != previousType
    }
    
    // Add this helper function to get the display number for an exercise
    private func displayNumber(for index: Int) -> Int {
        var number = 1
        for i in 0..<index {
            if isFirstInGroup(at: i) {
                number += 1
            }
        }
        return number
    }
    
    // Update the GroupTypeHeader view
    private struct GroupTypeHeader: View {
        let type: Exercise.GroupType
        let sets: Int
        var isEditing: Bool
        @Binding var setsText: String
        
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
                
                // Sets display/input
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(Colors.nasmBlue)
                        .imageScale(.large)
                    
                    if isEditing {
                        TextField("", text: $setsText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60, height: 32)
                            .font(.body.bold())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .overlay(
                                Text("Sets")
                                    .font(.body.bold())
                                    .foregroundColor(Color(.placeholderText))
                                    .opacity(setsText.isEmpty ? 1 : 0)
                            )
                    } else if sets > 0 {
                        Text("\(sets) sets")
                            .font(.body.bold())
                    }
                }
            }
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exerciseName)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    if exercise.sets > 0 {
                        Label("\(exercise.sets) sets", systemImage: "number.square")
                    }
                    if exercise.reps > 0 {
                        Label("\(exercise.reps) reps", systemImage: "repeat")
                    }
                    if exercise.weight > 0 {
                        Label("\(Int(exercise.weight))kg", systemImage: "scalemass")
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct StatusPill: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SupersetGroupView: View {
    let exercises: [Exercise]
    let onDelete: (Exercise) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Superset header
            HStack {
                Label("Superset", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.bold())
                    .foregroundColor(Colors.nasmBlue)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Colors.nasmBlue.opacity(0.1))
            .cornerRadius(8, corners: [.topLeft, .topRight])
            
            // Exercise rows
            ForEach(exercises) { exercise in
                VStack {
                    if exercise != exercises.first {
                        Divider()
                            .padding(.leading)
                    }
                    
                    ExerciseRowView(exercise: exercise, onDelete: { onDelete(exercise) })
                        .background(Color.clear)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CircuitGroupView: View {
    let exercises: [Exercise]
    let onDelete: (Exercise) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Circuit header
            HStack {
                Label("Circuit", systemImage: "repeat.circle")
                    .font(.subheadline.bold())
                    .foregroundColor(Colors.nasmBlue)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Colors.nasmBlue.opacity(0.1))
            .cornerRadius(8, corners: [.topLeft, .topRight])
            
            // Exercise rows with round indicators
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                VStack {
                    if index != 0 {
                        Divider()
                            .padding(.leading)
                    }
                    
                    HStack {
                        Circle()
                            .fill(Colors.nasmBlue)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text("\(index + 1)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                            )
                            .padding(.trailing, 8)
                        
                        ExerciseRowView(exercise: exercise, onDelete: { onDelete(exercise) })
                            .background(Color.clear)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                               byRoundingCorners: corners,
                               cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

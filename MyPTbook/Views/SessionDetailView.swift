import SwiftUI

private enum ExerciseMetricType {
    case reps, time
}

private let weightsStorageKey = "session_weights_"

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
    @State private var exerciseMetricTypes: [ExerciseMetricType] = []
    @State private var exerciseWeights: [[String]] = []
    @FocusState private var focusedWeightField: Int?
    @State private var selectedExerciseType: ExerciseType = .single
    
    public init(session: Session) {
        self.session = session
    }
    
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
            .onTapGesture {
                focusedWeightField = nil  // Dismiss keyboard
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                              to: nil, from: nil, for: nil)
            }
            
            // Fixed bottom buttons
            if !session.isCompleted {
                bottomButtonsView
                    .background(Colors.background)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
        }
        .toolbarBackground(Colors.background)
        .toolbarColorScheme(.light)
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
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("UpdateExercise"),
                object: nil,
                queue: .main
            ) { notification in
                if let updatedExercise = notification.object as? Exercise {
                    if let index = exercises.firstIndex(where: { $0._id == updatedExercise._id }) {
                        exercises[index] = updatedExercise
                    }
                }
            }
        }
        .preferredColorScheme(.light)  // Force light mode for this view
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
                    // Show group header if this is the first exercise in a group
                    if let groupType = exercise.groupType,
                       isFirstInGroup(at: index) {
                        GroupTypeHeader(
                            type: groupType,
                            sets: exercise.sets,
                            isEditing: isEditing,
                            displayNumber: displayNumber(for: index),
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
                                          exercises[currentIndex].groupId == exercise.groupId {  // Compare groupId instead of groupType
                                        exerciseSets[currentIndex] = newValue
                                        currentIndex += 1
                                    }
                                }
                            )
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                    
                    exerciseRow(exercise: exercise, index: index)
                        .padding(.horizontal, 20)
                        .padding(.vertical, exercise.groupType != nil ? 4 : 8)
                    
                    // Show divider if:
                    // 1. Not the last exercise AND
                    // 2. Either:
                    //    a. Current exercise has no group OR
                    //    b. Next exercise has no group OR
                    //    c. Current and next exercises have different groupIds
                    if index < exercises.count - 1 &&
                        (exercise.groupType == nil ||
                         exercises[index + 1].groupType == nil ||
                         exercise.groupId != exercises[index + 1].groupId) {
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
            }
            
            // Add this new button when in editing mode
            if isEditing {
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
                            
                            // Add divider after first and second buttons
                            if type != .circuit {
                                Divider()
                                    .background(Colors.nasmBlue)  // Match the border color
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Colors.nasmBlue, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)
                    
                    // Add Exercise Button
                    Button(action: {
                        Task {
                            switch selectedExerciseType {
                            case .single:
                                await addNewExercise()
                            case .superset:
                                await addNewExerciseGroup(.superset)
                            case .circuit:
                                await addNewExerciseGroup(.circuit)
                            }
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
        }
    }
    
    private func exerciseRow(exercise: Exercise, index: Int) -> some View {
        Group {  // Wrap everything in a Group to ensure consistent return type
            if index < exerciseNames.count &&
               index < exerciseSets.count &&
               index < exerciseReps.count &&
               index < exerciseMetricTypes.count &&
               index < exerciseWeights.count {
                
                // Create bindings with bounds checking
                let exerciseNameBinding = Binding(
                    get: { exerciseNames[index] },
                    set: { exerciseNames[index] = $0 }
                )
                
                let exerciseSetsBinding = Binding(
                    get: { exerciseSets[index] },
                    set: { exerciseSets[index] = $0 }
                )
                
                let exerciseRepsBinding = Binding(
                    get: { exerciseReps[index] },
                    set: { exerciseReps[index] = $0 }
                )
                
                let exerciseMetricTypeBinding = Binding(
                    get: { exerciseMetricTypes[index] },
                    set: { exerciseMetricTypes[index] = $0 }
                )
                
                let exerciseWeightsBinding = Binding(
                    get: { exerciseWeights[index] },
                    set: { exerciseWeights[index] = $0 }
                )
                
                VStack(alignment: .leading, spacing: isEditing ? 6 : 2) {
                    // Exercise number and name
                    HStack(alignment: .center) {
                        if exercise.groupType == nil {
                            Text("\(displayNumber(for: index)).")
                                .font(.body.bold())
                                .frame(width: 30, alignment: .leading)
                        } else {
                            Text("•")
                                .font(.title2.bold())
                                .frame(width: 30, alignment: .leading)
                                .offset(y: -4)
                        }
                        
                        if isEditing {
                            TextField("Exercise Name", text: exerciseNameBinding)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.body.bold())
                            
                            // Add delete button
                            Button(action: {
                                Task {
                                    await deleteExercise(exercise)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 8)
                        } else {
                            Text(exerciseNames[index])
                                .font(.body.bold())
                        }
                        
                        Spacer()
                    }
                    
                    if exercise.groupType == nil {
                        ExerciseMetrics(
                            exercise: exercise,
                            index: index,
                            isEditing: isEditing,
                            exerciseSets: exerciseSetsBinding,
                            exerciseReps: exerciseRepsBinding,
                            exerciseMetricType: exerciseMetricTypeBinding,
                            updateExercise: updateExerciseOnServer
                        )
                        
                        // Keep the rest of your existing code for weights, etc.
                    } else {
                        // Only show reps/time for grouped exercises
                        HStack(spacing: DesignSystem.adaptiveSpacing) {
                            // Reps/Time
                            HStack(spacing: 8) {
                                Image(systemName: exerciseMetricTypes[index] == .reps ? 
                                      "figure.strengthtraining.traditional" : "clock")
                                    .foregroundColor(Colors.nasmBlue)
                                    .imageScale(.large)
                                
                                if isEditing {
                                    TextField("", text: exerciseRepsBinding)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 60, height: 32)
                                        .font(.body.bold())
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .focused($focusedRepsField, equals: index)
                                        .overlay(
                                            Text(exerciseMetricTypes[index] == .reps ? "Reps" : "Secs")
                                                .font(.body.bold())
                                                .foregroundColor(Color(.placeholderText))
                                                .opacity(exerciseReps[index].isEmpty && focusedRepsField != index ? 1 : 0)
                                        )
                                    
                                    // Add the type selector
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
                                                
                                                // Update on server
                                                Task {
                                                    await updateExerciseOnServer(updatedExercise)
                                                }
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
                                } else {
                                    if exerciseMetricTypes[index] == .reps {
                                        Text("\(exercise.reps) reps")
                                            .font(.body.bold())
                                    } else {
                                        Text("\(exercise.time ?? 0) secs")
                                            .font(.body.bold())
                                    }
                                }
                            }
                        }
                        .padding(.leading, 30)
                    }
                    
                    if !isEditing && index < exerciseWeights.count {
                        // Performance Boxes for weight tracking
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(0..<exercise.sets, id: \.self) { setIndex in
                                    if setIndex < exerciseWeightsBinding.wrappedValue.count {
                                        ZStack(alignment: .center) {
                                            if exerciseWeightsBinding.wrappedValue[setIndex].isEmpty && 
                                               focusedWeightField != (index * 1000 + setIndex) {
                                                Text(ordinalNumber(setIndex))
                                                    .font(.caption.bold())
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            TextField("", text: Binding(
                                                get: { exerciseWeightsBinding.wrappedValue[setIndex] },
                                                set: { newValue in
                                                    if index < exerciseWeights.count && setIndex < exerciseWeights[index].count {
                                                        exerciseWeightsBinding.wrappedValue[setIndex] = newValue
                                                        // Save to UserDefaults
                                                        if let encodedData = try? JSONEncoder().encode(exerciseWeights) {
                                                            UserDefaults.standard.set(encodedData, forKey: "\(weightsStorageKey)\(session._id)")
                                                        }
                                                    }
                                                }
                                            ))
                                            .focused($focusedWeightField, equals: (index * 1000 + setIndex))
                                            .multilineTextAlignment(.center)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .onSubmit {
                                                focusedWeightField = nil  // Dismiss keyboard when done
                                                saveChanges()
                                            }
                                        }
                                        .frame(width: 40, height: 28)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(Colors.nasmBlue.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                        .font(.footnote.bold())
                                        .keyboardType(.decimalPad)
                                        
                                        Text("kg")
                                            .font(.body.bold())
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.leading, 30)
                            .padding(.top, 4)
                        }
                    }
                    
                    if isEditing,
                       let groupType = exercise.groupType,
                       groupType == .circuit,
                       isLastInGroup(at: index) {
                        Button(action: {
                            Task {
                                await addExerciseToCircuit(afterIndex: index)
                            }
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
            } else {
                VStack(alignment: .leading, spacing: isEditing ? 6 : 2) { }
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: DesignSystem.isIPad ? 18 : 16, weight: .semibold))
                        Text("Back")
                            .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 18 : 16, weight: .semibold))
                    }
                    .foregroundColor(Colors.nasmBlue)
                }
            }
            
            // Add delete button
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
        error = nil  // Reset error state
        
        do {
            let maxRetries = 3
            var currentTry = 0
            var lastError: Error? = nil
            
            while currentTry < maxRetries {
                do {
                    exercises = try await dataManager.getSessionExercises(sessionId: session._id)
                    
                    // Initialize the state arrays with the fetched data
                    await MainActor.run {
                        exerciseNames = exercises.map { $0.exerciseName }
                        exerciseSets = exercises.map { String($0.sets) }
                        exerciseReps = exercises.map { exercise in 
                            if let time = exercise.time {
                                return String(time)
                            } else {
                                return String(exercise.reps)
                            }
                        }
                        // Initialize exerciseMetricTypes based on whether exercise has time or reps
                        exerciseMetricTypes = exercises.map { exercise in
                            exercise.time != nil ? .time : .reps
                        }
                        
                        // Load saved weights from UserDefaults
                        if let savedData = UserDefaults.standard.data(forKey: "\(weightsStorageKey)\(session._id)"),
                           let loadedWeights = try? JSONDecoder().decode([[String]].self, from: savedData) {
                            exerciseWeights = loadedWeights
                        } else {
                            // Initialize empty weights if none saved
                            exerciseWeights = exercises.map { exercise in
                                Array(repeating: "", count: max(1, exercise.sets))
                            }
                        }
                        
                        isLoading = false
                    }
                    return
                } catch {
                    lastError = error
                    currentTry += 1
                    if currentTry < maxRetries {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            }
            
            throw lastError ?? NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            
        } catch {
            await MainActor.run {
                self.error = "Failed to load exercises: \(error.localizedDescription)"
                showingError = true
                isLoading = false
                print("Exercise fetch error:", error)
            }
        }
    }
    
    private func deleteExercise(_ exercise: Exercise) async {
        do {
            try await dataManager.deleteExercise(exerciseId: exercise._id)
            if let index = exercises.firstIndex(where: { $0._id == exercise._id }) {
                exercises.remove(at: index)
                exerciseNames.remove(at: index)
                exerciseSets.remove(at: index)
                exerciseReps.remove(at: index)
                exerciseMetricTypes.remove(at: index)
                exerciseWeights.remove(at: index)
            }
        } catch {
            self.error = "Failed to delete exercise: \(error.localizedDescription)"
            showingError = true
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
    
    private func addNewExercise() async {
        await MainActor.run {
            let newExercise = Exercise(
                _id: UUID().uuidString,
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
                exerciseMetricTypes.append(.reps)
                exerciseWeights.append([])
            }
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
                    guard index < exerciseNames.count && index < exerciseSets.count && 
                          index < exerciseReps.count && index < exerciseMetricTypes.count else {
                        continue
                    }
                    
                    // Validate exercise data
                    guard !exerciseNames[index].isEmpty,
                          let sets = Int(exerciseSets[index]), sets > 0,
                          let value = Int(exerciseReps[index]), value > 0 else {
                        continue
                    }
                    
                    let isTimeBasedExercise = exerciseMetricTypes[index] == .time
                    
                    // Create base exercise data
                    var exerciseData: [String: Any] = [
                        "exerciseName": exerciseNames[index],
                        "sets": sets,
                        "reps": isTimeBasedExercise ? 0 : value,
                        "weight": 0,
                        "session": session._id
                    ]
                    
                    // Add optional fields
                    if isTimeBasedExercise {
                        exerciseData["time"] = value
                    }
                    if let groupType = exercise.groupType {
                        exerciseData["groupType"] = groupType.rawValue
                    }
                    if let groupId = exercise.groupId {
                        exerciseData["groupId"] = groupId
                    }
                    
                    if exercise._id.count == 36 {  // New exercise (UUID length is 36)
                        // Create new exercise
                        _ = try await dataManager.createExercise(exerciseData: exerciseData)
                    } else {  // Existing exercise
                        // Update existing exercise
                        _ = try await dataManager.updateExercise(
                            exerciseId: exercise._id,
                            exerciseData: exerciseData
                        )
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
                    self.error = "Failed to save changes: \(error.localizedDescription)"
                    showingError = true
                    print("Save error:", error)
                }
            }
        }
    }
    
    // Update the isFirstInGroup helper to use groupId
    private func isFirstInGroup(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentExercise = exercises[index]
        let previousExercise = exercises[index - 1]
        
        // If current exercise has no group type, it's the start of a new section
        guard let currentGroupType = currentExercise.groupType else {
            return true
        }
        
        // If previous exercise has no group type or different groupId, this is the start of a new group
        return previousExercise.groupType != currentGroupType ||
               currentExercise.groupId != previousExercise.groupId
    }
    
    // Update the isLastInGroup helper to use groupId
    private func isLastInGroup(at index: Int) -> Bool {
        guard index < exercises.count - 1 else { return true }
        let currentExercise = exercises[index]
        let nextExercise = exercises[index + 1]
        
        // If current exercise has no group type, it's a single exercise
        guard let currentGroupType = currentExercise.groupType else {
            return true
        }
        
        // If next exercise has no group type or different groupId, this is the end of the group
        return nextExercise.groupType != currentGroupType ||
               currentExercise.groupId != nextExercise.groupId
    }
    
    // Update the displayNumber function
    private func displayNumber(for index: Int) -> Int {
        var number = 0  // Start from 0 since we'll increment before returning
        
        for i in 0...index {  // Include the current index
            if i == index {  // When we reach our target index
                number += 1  // Always increment for the current item
                break
            }
            
            if exercises[i].groupType == nil {
                // For single exercises
                number += 1
            } else if i == 0 || // First exercise in array
                      exercises[i].groupId != exercises[i-1].groupId { // New group (different groupId)
                // Increment for the start of any new group, regardless of type
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
        let displayNumber: Int
        @Binding var setsText: String
        
        var body: some View {
            HStack(alignment: .center, spacing: 8) {
                // Exercise number
                Text("\(displayNumber).")
                    .font(.body.bold())
                    .frame(width: 30, alignment: .leading)
                
                // Group type indicator and sets
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
                
                Spacer()
            }
        }
    }
    
    private func addNewExerciseGroup(_ groupType: Exercise.GroupType) async {
        let groupId = UUID().uuidString
        let count = groupType == .superset ? 2 : 3
        
        await MainActor.run {
            withAnimation {
                for _ in 0..<count {
                    let newExercise = Exercise(
                        _id: UUID().uuidString,
                        exerciseName: "",
                        sets: 0,
                        reps: 0,
                        weight: 0,
                        time: nil,
                        groupType: groupType,
                        groupId: groupId,
                        session: session._id
                    )
                    
                    exercises.append(newExercise)
                    exerciseNames.append("")
                    exerciseSets.append("")
                    exerciseReps.append("")
                    exerciseMetricTypes.append(.reps)
                    exerciseWeights.append([])
                }
            }
        }
    }
    
    private func addExerciseToCircuit(afterIndex: Int) async {
        let groupId = exercises[afterIndex].groupId
        
        let newExercise = Exercise(
            _id: UUID().uuidString,  // Temporary ID for local tracking
            exerciseName: "",
            sets: exercises[afterIndex].sets,
            reps: 0,
            weight: 0,
            time: nil,
            groupType: .circuit,
            groupId: groupId,
            session: session._id
        )
        
        await MainActor.run {
            exercises.insert(newExercise, at: afterIndex + 1)
            exerciseNames.insert("", at: afterIndex + 1)
            exerciseSets.insert(String(exercises[afterIndex].sets), at: afterIndex + 1)
            exerciseReps.insert("", at: afterIndex + 1)
            exerciseMetricTypes.insert(.reps, at: afterIndex + 1)
            exerciseWeights.insert([], at: afterIndex + 1)
        }
    }
    
    // First, add a function to update exercise on the server
    private func updateExerciseOnServer(_ exercise: Exercise) async {
        do {
            let updatedExercise = try await dataManager.updateExercise(
                exerciseId: exercise._id,
                exerciseData: [
                    "exerciseName": exercise.exerciseName,
                    "sets": exercise.sets,
                    "reps": exercise.reps,
                    "weight": exercise.weight,
                    "time": exercise.time as Any,
                    "groupType": exercise.groupType?.rawValue as Any,
                    "groupId": exercise.groupId as Any
                ]
            )
            
            if let index = exercises.firstIndex(where: { $0._id == exercise._id }) {
                await MainActor.run {
                    exercises[index] = updatedExercise
                    // Update the metric type
                    exerciseMetricTypes[index] = updatedExercise.time != nil ? .time : .reps
                }
            }
        } catch {
            print("Error updating exercise:", error)
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

// First, create a new view for exercise metrics
private struct ExerciseMetrics: View {
    let exercise: Exercise
    let index: Int
    let isEditing: Bool
    @Binding var exerciseSets: String
    @Binding var exerciseReps: String
    @Binding var exerciseMetricType: ExerciseMetricType
    let updateExercise: (Exercise) async -> Void
    @FocusState private var localFocusedSetsField: Int?
    @FocusState private var localFocusedRepsField: Int?
    
    var body: some View {
        HStack(spacing: DesignSystem.adaptiveSpacing) {
            // Sets
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(Colors.nasmBlue)
                    .imageScale(.large)
                
                if isEditing {
                    TextField("", text: $exerciseSets)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60, height: 32)
                        .font(.body.bold())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($localFocusedSetsField, equals: index)
                        .overlay(
                            Text("Sets")
                                .font(.body.bold())
                                .foregroundColor(Color(.placeholderText))
                                .opacity(exerciseSets.isEmpty && localFocusedSetsField != index ? 1 : 0)
                        )
                } else {
                    Text("\(exercise.sets) sets")
                        .font(.body.bold())
                }
            }
            
            // Reps/Time
            HStack(spacing: 8) {
                Image(systemName: exerciseMetricType == .reps ? 
                      "figure.strengthtraining.traditional" : "clock")
                    .foregroundColor(Colors.nasmBlue)
                    .imageScale(.large)
                
                if isEditing {
                    TextField("", text: $exerciseReps)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60, height: 32)
                        .font(.body.bold())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($localFocusedRepsField, equals: index)
                        .overlay(
                            Text(exerciseMetricType == .reps ? "Reps" : "Secs")
                                .font(.body.bold())
                                .foregroundColor(Color(.placeholderText))
                                .opacity(exerciseReps.isEmpty && localFocusedRepsField != index ? 1 : 0)
                        )
                    
                    // Add the type selector
                    HStack(spacing: 0) {
                        ForEach([ExerciseMetricType.reps, .time], id: \.self) { type in
                            Button(action: {
                                exerciseMetricType = type
                                var updatedExercise = exercise
                                if type == .reps {
                                    updatedExercise.reps = Int(exerciseReps) ?? 0
                                    updatedExercise.time = nil
                                } else {
                                    updatedExercise.time = Int(exerciseReps)
                                    updatedExercise.reps = 0
                                }
                                
                                // Use the passed function
                                Task {
                                    await updateExercise(updatedExercise)
                                }
                            }) {
                                Text(type == .reps ? "Reps" : "Time")
                                    .font(.footnote.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(exerciseMetricType == type ? Colors.nasmBlue : Color.clear)
                                    .foregroundColor(exerciseMetricType == type ? .white : Colors.nasmBlue)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Colors.nasmBlue, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(width: 120)
                } else {
                    if exerciseMetricType == .reps {
                        Text("\(exercise.reps) reps")
                            .font(.body.bold())
                    } else {
                        Text("\(exercise.time ?? 0) secs")
                            .font(.body.bold())
                    }
                }
            }
        }
    }
}

import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataManager = DataManager.shared
    let session: Session
    
    @State private var exercises: [Exercise] = []
    @State private var isLoading = true
    @State private var showingAddExercise = false
    @State private var showingDeleteAlert = false
    @State private var isEditing = false
    @State private var editedWorkoutName = ""
    @State private var error: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Session Info Card
                    sessionInfoCard
                    
                    // Exercises Section
                    exercisesSection
                }
                .padding()
            }
            .background(Colors.background)
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
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView(session: session)
            }
            .task {
                await fetchExercises()
            }
            .onChange(of: showingAddExercise) { oldValue, newValue in
                if !newValue {
                    Task {
                        await fetchExercises()
                    }
                }
            }
        }
    }
    
    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isEditing {
                TextField("Workout Name", text: $editedWorkoutName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Text(session.workoutName)
                    .font(.title2.bold())
            }
            
            VStack(spacing: 12) {
                // Status pills in a row
                HStack(spacing: 16) {
                    if session.isCompleted {
                        StatusPill(
                            icon: "checkmark.circle.fill",
                            title: "Completed",
                            value: session.completedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Today",
                            color: .green
                        )
                    }
                }
                
                // Completion toggle button
                Button(action: toggleCompletion) {
                    HStack {
                        Image(systemName: session.isCompleted ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text(session.isCompleted ? "Mark as Incomplete" : "Mark as Complete")
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(session.isCompleted ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    )
                    .foregroundColor(session.isCompleted ? .red : .green)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                HStack {
                    Text("Exercises")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingAddExercise = true }) {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .foregroundColor(Colors.nasmBlue)
                    }
                }
                
                if exercises.isEmpty {
                    Text("No exercises added yet")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(Array(groupedExercises().enumerated()), id: \.offset) { _, group in
                        if group.count > 1 {
                            if group[0].groupType == .superset {
                                SupersetGroupView(exercises: group, onDelete: deleteExercise)
                            } else if group[0].groupType == .circuit {
                                CircuitGroupView(exercises: group, onDelete: deleteExercise)
                            }
                        } else {
                            ExerciseRowView(exercise: group[0], onDelete: { deleteExercise(group[0]) })
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") { dismiss() }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if isEditing {
                        Button("Save") { saveChanges() }
                    } else {
                        Button("Edit") { startEditing() }
                    }
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete Session", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func fetchExercises() async {
        isLoading = true
        do {
            exercises = try await dataManager.getSessionExercises(sessionId: session._id)
        } catch {
            self.error = "Failed to load exercises"
            showingError = true
        }
        isLoading = false
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
        Task {
            do {
                var updatedSession = session
                updatedSession.workoutName = editedWorkoutName
                try await dataManager.updateSession(clientId: session.client, session: updatedSession)
                await MainActor.run {
                    isEditing = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to update session"
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
                
                // Wait for the update to complete
                try await dataManager.updateSession(clientId: session.client, session: updatedSession)
                
                await MainActor.run {
                    // Post notification to refresh sessions list
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshClientData"),
                        object: nil,
                        userInfo: ["clientId": session.client]
                    )
                    
                    // Add a small delay before dismissing to ensure the notification is processed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to update session: \(error.localizedDescription)"
                    showingError = true
                    print("Error updating session:", error)
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

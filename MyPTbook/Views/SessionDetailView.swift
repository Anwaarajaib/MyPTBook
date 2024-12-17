import SwiftUI

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    let session: Session
    let clientId: UUID
    @State private var isEditing = false
    @State private var exercises: [Exercise]
    @State private var showingAddExercise = false
    @State private var showingDeleteAlert = false
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showingError = false
    
    // MARK: - Initialization
    init(session: Session, clientId: UUID) {
        self.session = session
        self.clientId = clientId
        _exercises = State(initialValue: session.exercises)
    }
    
    // MARK: - Main View
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
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                             to: nil, from: nil, for: nil)
            }
            
            // Fixed bottom buttons
            if !session.isCompleted {
                bottomButtonsView
                    .background(Color(UIColor.systemBackground))
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                        Text("Back")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Colors.nasmBlue)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isEditing {
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                    }
                }
            }
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteSession() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this session? This action cannot be undone.")
        }
        .tint(Colors.nasmBlue)
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(clientId: clientId) { exercise in
                print("SessionDetailView - Received exercise with sets: \(exercise.sets)")
                exercises.append(exercise)
                print("SessionDetailView - After append, exercise sets: \(exercises.last?.sets ?? 0)")
                saveChanges()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(error ?? "An unknown error occurred")
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(alignment: .center, spacing: 8) {
            // Session Title
            if let firstExercise = exercises.first,
               let circuitName = firstExercise.circuitName,
               circuitName.lowercased().contains("day") {
                Text(circuitName)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
            } else {
                Text("Session \(session.sessionNumber)")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Exercise List
    private var exerciseListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                VStack(spacing: 0) {
                    if exercise.isPartOfCircuit && (index == 0 || exercises[index - 1].circuitName != exercise.circuitName) {
                        if let circuitName = exercise.circuitName,
                           !circuitName.lowercased().contains("day") {
                            Text(circuitName)
                                .font(.headline)
                                .foregroundColor(Colors.nasmBlue)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Colors.nasmBlue.opacity(0.05))
                        }
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
        }
    }
    
    // MARK: - Exercise Row
    private func exerciseRow(exercise: Exercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: isEditing ? 2 : 2) {
            // Exercise Name Row
            HStack(alignment: .center, spacing: 8) {
                if !exercise.isPartOfCircuit {
                    Text("\(index + 1).")
                        .font(.body.bold())
                        .foregroundColor(Colors.nasmBlue)
                        .frame(width: 30, alignment: .leading)
                } else {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(Colors.nasmBlue)
                        .frame(width: 30, alignment: .leading)
                }
                
                if isEditing {
                    HStack {
                        TextField("Exercise name", text: Binding(
                            get: { exercise.name },
                            set: { newValue in
                                exercises[index].name = newValue
                                saveChanges()
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(height: 32)
                        .font(.body.bold())
                        
                        Button(action: {
                            exercises.remove(at: index)
                            saveChanges()
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 32, height: 32)
                        }
                    }
                } else {
                    Text(exercise.name)
                        .font(.body.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Sets and Reps Row
            if !exercise.name.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 24) {
                        Group {
                            // Sets
                            exerciseMetric(
                                icon: "square.stack.3d.up.fill",
                                value: String(exercise.sets),
                                unit: "sets",
                                binding: Binding(
                                    get: { String(exercise.sets) },
                                    set: { newValue in
                                        if let intValue = Int(newValue.trimmingCharacters(in: .whitespaces)) {
                                            exercises[index].sets = intValue
                                            saveChanges()
                                        }
                                    }
                                ),
                                isEditing: isEditing
                            )
                            
                            // Reps
                            exerciseMetric(
                                icon: "figure.strengthtraining.traditional",
                                value: isEditing ? exercise.reps.replacingOccurrences(of: " reps", with: "") : formatRepsDisplay(exercise.reps),
                                unit: "",
                                binding: Binding(
                                    get: { exercise.reps.replacingOccurrences(of: " reps", with: "") },
                                    set: { newValue in
                                        exercises[index].reps = validateAndFormatReps(newValue)
                                        saveChanges()
                                    }
                                ),
                                isEditing: isEditing
                            )
                        }
                        .padding(.vertical, 0)
                        
                        Spacer()
                    }
                    .padding(.leading, 30)
                    
                    // Performance Boxes
                    if !isEditing {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(0..<exercise.sets, id: \.self) { setIndex in
                                    HStack(spacing: 4) {
                                        ZStack(alignment: .center) {
                                            if exercises[index].setPerformances[setIndex].isEmpty {
                                                Text(ordinalNumber(setIndex))
                                                    .font(.caption.bold())
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            TextField("", text: Binding(
                                                get: { exercises[index].setPerformances[setIndex] },
                                                set: { newValue in
                                                    exercises[index].setPerformances[setIndex] = newValue
                                                    saveChanges()
                                                }
                                            ))
                                            .multilineTextAlignment(.center)
                                            .textFieldStyle(PlainTextFieldStyle())
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
                }
            }
        }
        .padding(.vertical, isEditing ? 4 : 8)
    }
    
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
    
    // MARK: - Bottom Buttons
    private var bottomButtonsView: some View {
        HStack(spacing: 16) {
            if isEditing {
                addExerciseButton
            } else {
                completeSessionButton
            }
            editButton
        }
        .padding(.horizontal, 16)
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
    
    // MARK: - Helper Functions
    private func saveChanges() {
        guard !isProcessing else { return }
        
        Task {
            await MainActor.run {
                isProcessing = true
                error = nil
            }
            
            do {
                var updatedSession = session
                updatedSession.exercises = exercises
                
                try await DataManager.shared.updateClientSession(
                    clientId: clientId,
                    session: updatedSession
                )
                
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
                    self.error = handleError(error)
                    showingError = true
                }
            }
        }
    }
    
    private func deleteSession() {
        guard !isProcessing else { return }
        
        Task {
            await MainActor.run {
                isProcessing = true
                error = nil
            }
            
            do {
                try await DataManager.shared.deleteClientSession(
                    clientId: clientId,
                    sessionId: session.id
                )
                
                await MainActor.run {
                    isProcessing = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    self.error = handleError(error)
                    showingError = true
                }
            }
        }
    }
    
    private func completeSession() {
        guard !isProcessing else { return }
        
        Task {
            await MainActor.run {
                isProcessing = true
                error = nil
            }
            
            do {
                var updatedSession = session
                updatedSession.isCompleted = true
                
                try await DataManager.shared.updateClientSession(
                    clientId: clientId,
                    session: updatedSession
                )
                
                await MainActor.run {
                    isProcessing = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshClientData"),
                        object: nil,
                        userInfo: ["clientId": clientId]
                    )
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    self.error = handleError(error)
                    showingError = true
                }
            }
        }
    }
    
    private func formatRepsDisplay(_ reps: String) -> String {
        let cleanReps = reps.trimmingCharacters(in: .whitespaces)
        if cleanReps.isEmpty {
            return ""
        }
        // Add "reps" suffix if it doesn't already contain it and isn't a special case
        if !cleanReps.lowercased().contains("rep") &&
           !cleanReps.contains("per leg") &&
           !cleanReps.contains("per side") &&
           !cleanReps.contains("seconds") {
            return "\(cleanReps) reps"
        }
        return cleanReps
    }
    
    private func validateAndFormatReps(_ input: String) -> String {
        return input.formatAsReps()
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
    
    private func handleError(_ error: Error) -> String {
        switch error {
        case APIError.unauthorized:
            return "Your session has expired. Please log in again"
        case APIError.serverError(let message):
            return "Server error: \(message)"
        case APIError.networkError:
            return "Network error. Please check your connection"
        default:
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

// Add Exercise View
struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sets = ""
    @State private var reps = ""
    let clientId: UUID
    var onAdd: (Exercise) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise Name", text: $name)
                TextField("Sets (e.g., 3)", text: $sets)
                    .keyboardType(.numberPad)
                TextField("Reps (e.g., 8-12)", text: $reps)
                    .onChange(of: reps) { oldValue, newValue in
                        // Clean up the input as the user types
                        let cleaned = newValue.replacingOccurrences(of: " reps", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        if cleaned != newValue {
                            reps = cleaned
                        }
                    }
                    .keyboardType(.asciiCapable)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Extract the number from formats like "4 sets" or "4x6-8"
                        let cleanSets = sets.trimmingCharacters(in: .whitespaces)
                        let setsNumber = cleanSets.split(separator: " ").first ?? ""
                        guard let setsValue = Int(String(setsNumber)) else { return }
                        
                        print("AddExerciseView - Initial sets value: \(setsValue)")
                        
                        // Ensure reps has a value
                        var repsValue = reps.trimmingCharacters(in: .whitespaces)
                        if repsValue.isEmpty {
                            repsValue = "12"
                        }
                        
                        // Handle "per leg" or similar suffixes
                        if repsValue.lowercased().contains("per leg") {
                            repsValue = repsValue.replacingOccurrences(of: "per leg", with: "per leg")
                        } else if repsValue.lowercased().contains("steps") {
                            repsValue = repsValue.replacingOccurrences(of: "steps", with: "steps")
                        } else if !repsValue.lowercased().contains("reps") {
                            repsValue += " reps"
                        }
                        
                        let exercise = Exercise(
                            name: cleanExerciseName(name),
                            sets: setsValue,
                            reps: repsValue,
                            setPerformances: Array(repeating: "", count: setsValue)
                        )
                        print("AddExerciseView - Exercise created with sets: \(exercise.sets)")
                        onAdd(exercise)
                        dismiss()
                    }
                    .disabled(name.isEmpty || sets.isEmpty)
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
    
    private func validateAndFormatReps(_ input: String) -> String {
        let cleaned = input.trimmingCharacters(in: .whitespaces)
        
        // Handle special cases
        if cleaned.lowercased().contains("per leg") {
            return cleaned
        }
        if cleaned.lowercased().contains("steps") {
            return cleaned
        }
        if cleaned.lowercased().contains("taps") {
            return cleaned
        }
        
        // Handle standard rep formats
        if cleaned.isEmpty {
            return "12 reps"
        }
        
        let formatted = cleaned.lowercased()
            .replacingOccurrences(of: " reps", with: "")
            .replacingOccurrences(of: "reps", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // Handle ranges
        if formatted.contains("-") {
            let components = formatted.components(separatedBy: "-")
            if components.count == 2,
               let first = components.first?.trimmingCharacters(in: .whitespaces),
               let second = components.last?.trimmingCharacters(in: .whitespaces) {
                return "\(first)-\(second) reps"
            }
        }
        
        return "\(formatted) reps"
    }
}

extension String {
    func formatAsReps() -> String {
        let cleaned = self.trimmingCharacters(in: .whitespaces)
        
        if cleaned.isEmpty {
            return ""
        }
        
        // Handle special cases
        let lower = cleaned.lowercased()
        if lower.contains("per leg") || 
           lower.contains("steps") || 
           lower.contains("taps") ||
           lower.contains("seconds") {
            return cleaned
        }
        
        // Remove existing "reps" suffix to avoid duplication
        let formatted = lower
            .replacingOccurrences(of: " reps", with: "")
            .replacingOccurrences(of: "reps", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // Handle ranges
        if formatted.contains("-") {
            let components = formatted.components(separatedBy: "-")
            if components.count == 2,
               let first = components.first?.trimmingCharacters(in: .whitespaces),
               let second = components.last?.trimmingCharacters(in: .whitespaces) {
                return "\(first)-\(second) reps"
            }
        }
        
        return formatted.isEmpty ? "" : "\(formatted) reps"
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

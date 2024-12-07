import SwiftUI

struct AddSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workoutText = ""
    @State private var isProcessing = false
    let client: Client
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Blank Note Card
                VStack {
                    TextEditor(text: $workoutText)
                        .font(.body)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                }
                .padding()
                
                // Add Session Button
                Button(action: {
                    guard !isProcessing else { return }
                    Task {
                        await addSessions()
                    }
                }) {
                    Text(isProcessing ? "Adding..." : "Add Session")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Colors.nasmBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(workoutText.isEmpty || isProcessing)
            }
            .background(Colors.background)
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled(isProcessing)
        }
    }
    
    private func addSessions() async {
        if Task.isCancelled { return }
        
        await MainActor.run {
            isProcessing = true
        }
        
        // Parse on background thread
        let sessions = await Task.detached(priority: .userInitiated) { 
            await parseWorkoutText(workoutText)
        }.value
        
        guard !sessions.isEmpty else {
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
            return
        }
        
        // Switch to main thread for UI updates
        await MainActor.run {
            // Update client's sessions
            var updatedClient = client
            updatedClient.sessions.append(contentsOf: sessions)
            
            // Save to DataManager
            var clients = DataManager.shared.getClients()
            if let index = clients.firstIndex(where: { $0.id == client.id }) {
                clients[index] = updatedClient
                DataManager.shared.saveClients(clients)
                
                // Post notification before dismissing
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshClientData"),
                    object: nil
                )
            }
            
            isProcessing = false
            dismiss()
        }
    }
    
    private func parseWorkoutText(_ text: String) -> [WorkoutSession] {
        var sessions: [WorkoutSession] = []
        
        // Split text into days
        let days = text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Get all existing session numbers
        let existingNumbers = Set(client.sessions.map { $0.sessionNumber })
        
        // Find the next available number
        var nextNumber = 1
        while existingNumbers.contains(nextNumber) {
            nextNumber += 1
        }
        
        for (index, dayText) in days.enumerated() {
            var exercises: [Exercise] = []
            let lines = dayText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            var currentExercise: Exercise?
            
            for line in lines {
                // Skip day headers
                if line.hasPrefix("Day") && line.contains(":") {
                    continue
                }
                
                // Handle numbered exercises and bullet points
                if line.range(of: #"^\d+\."#, options: .regularExpression) != nil || line.hasPrefix("•") {
                    // Save previous exercise if exists
                    if let exercise = currentExercise {
                        exercises.append(exercise)
                    }
                    
                    // Clean the line
                    let cleanLine = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: "^•\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    
                    // Parse the exercise
                    if let exercise = parseExercise(from: cleanLine) {
                        currentExercise = exercise
                    }
                }
                // Handle circuit items or additional notes
                else if !line.isEmpty {
                    if currentExercise == nil {
                        // Try to parse as a standalone exercise
                        if let exercise = parseExercise(from: line) {
                            exercises.append(exercise)
                        }
                    }
                }
            }
            
            // Add the last exercise
            if let exercise = currentExercise {
                exercises.append(exercise)
            }
            
            // Create session if we have exercises
            if !exercises.isEmpty {
                let session = WorkoutSession(
                    date: Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date(),
                    exercises: exercises,
                    isCompleted: false,
                    sessionNumber: nextNumber + index
                )
                sessions.append(session)
            }
        }
        
        return sessions
    }
    
    private func parseExercise(from text: String) -> Exercise? {
        // Try to extract exercise components
        let components = text.components(separatedBy: ":")
        guard components.count >= 1 else { return nil }
        
        let name = components[0].trimmingCharacters(in: .whitespaces)
        var sets = 3 // Default value
        var reps = "10" // Default value
        
        if components.count > 1 {
            let details = components[1].trimmingCharacters(in: .whitespaces)
            
            // Try to extract sets
            if let setsMatch = details.range(of: #"(\d+)\s*sets?"#, options: .regularExpression) {
                let setsStr = details[setsMatch].trimmingCharacters(in: .whitespaces)
                if let extractedSets = Int(setsStr.components(separatedBy: .whitespaces)[0]) {
                    sets = extractedSets
                }
            }
            
            // Try to extract reps
            if let repsMatch = details.range(of: #"(\d+(?:-\d+)?(?:\s*reps?)?(?:\s*per\s*(?:leg|side))?)"#, options: .regularExpression) {
                reps = String(details[repsMatch]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return Exercise(name: name, sets: sets, reps: reps, notes: nil)
    }
}

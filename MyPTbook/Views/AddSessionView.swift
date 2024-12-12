import SwiftUI

struct AddSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var Text = ""
    @State private var isProcessing = false
    let client: Client
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Blank Note Card
                VStack {
                    TextEditor(text: $Text)
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
                    SwiftUICore.Text(isProcessing ? "Adding..." : "Add Session")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Colors.nasmBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(Text.isEmpty || isProcessing)
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
            await parseText(Text)
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
    
    private func parseText(_ text: String) -> [Session] {
        var sessions: [Session] = []
        
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
                let session = Session(
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
        // Check for circuit/HIIT patterns
        let isCircuit = text.lowercased().contains("circuit") || 
                        text.lowercased().contains("hiit") ||
                        text.lowercased().contains("superset")
        
        var circuitName: String?
        var circuitRounds: Int?
        var workTime: String?
        var restTime: String?
        
        if isCircuit {
            // Extract circuit details
            if let circuitInfo = text.range(of: "(HIIT|Circuit|Superset).*?(?=:|\n|$)", options: .regularExpression) {
                circuitName = String(text[circuitInfo]).trimmingCharacters(in: .whitespaces)
                
                // Extract rounds
                if let roundsMatch = circuitName?.range(of: "\\((\\d+)\\s*[Rr]ounds?", options: .regularExpression) {
                    let roundsStr = String(circuitName?[roundsMatch] ?? "").replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                    circuitRounds = Int(roundsStr)
                }
                
                // Extract work/rest times for HIIT
                if let timeMatch = circuitName?.range(of: "(\\d+)\\s*seconds?\\s*work.*?(\\d+)\\s*seconds?\\s*rest", options: .regularExpression) {
                    let timeStr = String(circuitName?[timeMatch] ?? "")
                    let times = timeStr.components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .filter { !$0.isEmpty }
                    if times.count >= 2 {
                        workTime = "\(times[0]) seconds"
                        restTime = "\(times[1]) seconds"
                    }
                }
            }
        }
        
        // Split and clean exercise details
        let mainComponents = text.components(separatedBy: CharacterSet(charactersIn: "–-")).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let exerciseName = mainComponents.first else { return nil }
        
        let cleanName = processExerciseName(exerciseName)
        let sets = isCircuit ? (circuitRounds ?? 1) : extractSets(from: mainComponents)
        
        // Use workTime if it's a HIIT exercise
        var reps = ""
        if isCircuit && workTime != nil {
            reps = "\(workTime!)"
            if let rest = restTime {
                reps += " work / \(rest) rest"
            }
        } else {
            reps = extractReps(from: mainComponents)
        }
        
        return Exercise(
            name: cleanName,
            sets: sets,
            reps: reps.isEmpty ? "0 reps" : reps,
            isPartOfCircuit: isCircuit,
            circuitRounds: circuitRounds,
            circuitName: circuitName
        )
    }
    
    private func processExerciseName(_ rawName: String) -> String {
        // Step 1: Remove parenthetical equipment notes but preserve important ones
        let withoutParens = rawName.replacingOccurrences(
            of: "\\s*\\(((?!per|each|both|alternating|single).)*?\\)",
            with: "",
            options: [.regularExpression]
        )
        
        // Step 2: Handle common exercise name patterns
        var processedName = withoutParens.trimmingCharacters(in: .whitespaces)
        
        // Common exercise name corrections
        let corrections: [String: String] = [
            "Pull-Ups": "Pull-Ups",
            "Chin-Ups": "Chin-Ups",
            "Push-Ups": "Push-Ups",
            "Sit-Ups": "Sit-Ups",
            "dips": "Dips",
            "db": "Dumbbell",
            "bb": "Barbell",
            "kb": "Kettlebell",
        ]
        
        // Apply corrections
        for (shortForm, fullForm) in corrections {
            let pattern = "\\b\(shortForm)\\b"
            processedName = processedName.replacingOccurrences(
                of: pattern,
                with: fullForm,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Step 3: Handle special formatting cases
        processedName = processedName
            .components(separatedBy: .whitespaces)
            .map { word in
                // Don't capitalize certain words
                let lowercaseWords = ["and", "with", "to", "the", "on", "in", "at", "by", "for", "of"]
                if lowercaseWords.contains(word.lowercased()) {
                    return word.lowercased()
                }
                
                // Special case for "x" reps/sets indicator
                if word.lowercased() == "x" {
                    return "×"
                }
                
                return word.capitalized
            }
            .joined(separator: " ")
        
        // Step 4: Handle compound exercise names
        let compoundPatterns = [
            "([A-Za-z]+)-to-([A-Za-z]+)": "$1 to $2",
            "([A-Za-z]+)\\s*\\+\\s*([A-Za-z]+)": "$1 + $2"
        ]
        
        for (pattern, replacement) in compoundPatterns {
            processedName = processedName.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        
        // Step 5: Clean up any double spaces and trim
        return processedName
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func extractSets(from components: [String]) -> Int {
        guard components.count > 1 else { return 3 }
        let details = components[1].lowercased()
        
        // Patterns to match sets
        let patterns = [
            "\\b(\\d+)\\s*(?:sets?|x|×)\\b",    // "3 sets", "3x", "3×"
            "\\b(\\d+)(?=x\\d)",                // "3x10"
            "\\b(\\d+)\\s*rounds?\\b",          // "3 rounds"
            "\\b(\\d+)\\s*circuits?\\b"         // "3 circuits"
        ]
        
        for pattern in patterns {
            if let match = details.range(of: pattern, options: .regularExpression) {
                let setsStr = String(details[match]).replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                if let sets = Int(setsStr) {
                    return sets
                }
            }
        }
        
        return 3 // Default value
    }
    
    private func extractReps(from components: [String]) -> String {
        guard components.count > 1 else { return "0 reps" }
        let details = components[1].lowercased()
        
        // Time-based patterns
        let timePatterns = [
            "\\b(\\d+)\\s*(?:sec|s|seconds?)\\b",           // "30 seconds", "30s"
            "hold\\s*(?:for\\s*)?(\\d+)\\s*(?:sec|s|seconds?)\\b"  // "hold 30 seconds"
        ]
        
        for pattern in timePatterns {
            if let match = details.range(of: pattern, options: .regularExpression) {
                let timeStr = String(details[match]).replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                return "\(timeStr) seconds"
            }
        }
        
        // Reps patterns
        let repsPatterns = [
            "\\b(\\d+(?:-\\d+)?)\\s*(?:reps?|repetitions?)(?:\\s*(?:per|each)\\s*(?:side|leg|arm))?\\b",
            "(?:x|×)\\s*(\\d+(?:-\\d+)?)\\b",
            "\\b(\\d+(?:-\\d+)?)\\s*(?:times|counts)\\b",
            "sets?\\s+(?:of\\s+)?(\\d+(?:-\\d+)?)\\b"
        ]
        
        for pattern in repsPatterns {
            if let match = details.range(of: pattern, options: .regularExpression) {
                let repsValue = String(details[match]).replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)
                
                // Add appropriate suffix
                if details.contains("per side") {
                    return "\(repsValue) reps per side"
                } else if details.contains("per leg") {
                    return "\(repsValue) reps per leg"
                } else if details.contains("per arm") {
                    return "\(repsValue) reps per arm"
                } else if details.contains("each side") {
                    return "\(repsValue) reps each side"
                } else {
                    return "\(repsValue) reps"
                }
            }
        }
        
        return "0 reps"
    }
}

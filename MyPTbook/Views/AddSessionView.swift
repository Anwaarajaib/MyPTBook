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
            let exercises = parseProgram(from: dayText)
            
            // Create session if we have exercises
            if !exercises.isEmpty {
                // Extract session type from the day header
                let lines = dayText.components(separatedBy: .newlines)
                var sessionType: String? = nil
                
                // Look for day header that contains workout type
                if let firstLine = lines.first?.trimmingCharacters(in: .whitespaces),
                   firstLine.lowercased().contains("day") {
                    print("Found day header: \(firstLine)")
                    // Extract the workout type after "Day N:"
                    if let colonIndex = firstLine.firstIndex(of: ":"),
                       colonIndex < firstLine.endIndex {
                        let startIndex = firstLine.index(after: colonIndex)
                        sessionType = String(firstLine[startIndex...]).trimmingCharacters(in: .whitespaces)
                        print("Extracted session type: \(String(describing: sessionType))")
                    }
                }
                
                let session = Session(
                    date: Calendar.current.date(byAdding: .day, value: index, to: Date()) ?? Date(),
                    exercises: exercises,
                    type: sessionType,
                    isCompleted: false,
                    sessionNumber: nextNumber + index
                )
                print("Created session with type: \(String(describing: session.type))")
                sessions.append(session)
            }
        }
        
        return sessions
    }
    
    private func parseProgram(from text: String) -> [Exercise] {
        var exercises: [Exercise] = []
        var currentSection: String?
        var isInCircuit = false
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmedLine.isEmpty { continue }
            
            // Check for day header
            if trimmedLine.lowercased().contains("day") {
                currentSection = trimmedLine
                isInCircuit = false
                continue
            }
            
            // Check for circuit/superset/giant set header
            if trimmedLine.range(of: "(?:Core|HIIT|Circuit|Superset|Giant Set).*?\\((\\d+)\\s*Rounds?.*?\\)", options: .regularExpression) != nil {
                currentSection = trimmedLine
                isInCircuit = true
                continue
            }
            
            // Parse exercise line
            if let exercise = parseExercise(from: trimmedLine, section: currentSection) {
                var mutableExercise = exercise
                mutableExercise.isPartOfCircuit = isInCircuit
                mutableExercise.circuitName = currentSection  // Store section header in circuitName
                exercises.append(mutableExercise)
            }
        }
        
        return exercises
    }
    
    private func parseExercise(from text: String, section: String?) -> Exercise? {
        let parser = WorkoutProgramParser.parseExercise(text)
        let programType = section.flatMap { WorkoutProgramParser.parseProgram($0) }
        
        let reps: String
        if parser.isTime {
            reps = parser.duration ?? "30 seconds"
        } else {
            reps = parser.reps.isEmpty ? "12-15 reps" : parser.reps  // Keep the original format
        }
        
        return Exercise(
            name: parser.name,
            sets: parser.sets,
            reps: reps,
            isPartOfCircuit: programType?.type != .regular,
            circuitRounds: programType?.type.rounds,
            circuitName: programType?.name
        )
    }
}

// MARK: - Workout Program Parser
struct WorkoutProgramParser {
    // Program Types
    enum ProgramType: Equatable {
        case regular
        case circuit(rounds: Int)
        case hiit(rounds: Int, workTime: Int, restTime: Int)
        case superset(rounds: Int)
        
        // Implement custom Equatable if needed
        static func == (lhs: ProgramType, rhs: ProgramType) -> Bool {
            switch (lhs, rhs) {
            case (.regular, .regular):
                return true
            case let (.circuit(r1), .circuit(r2)):
                return r1 == r2
            case let (.hiit(r1, w1, rest1), .hiit(r2, w2, rest2)):
                return r1 == r2 && w1 == w2 && rest1 == rest2
            case let (.superset(r1), .superset(r2)):
                return r1 == r2
            default:
                return false
            }
        }
    }
    
    // Exercise Components
    struct ExerciseComponents {
        var name: String
        var sets: Int
        var reps: String
        var duration: String?
        var perSide: Bool
        var isTime: Bool
    }
    
    // Common patterns
    static let programPatterns: [(pattern: String, type: String)] = [
        ("HIIT\\s*Circuit.*?\\((\\d+)\\s*Rounds?,?\\s*(\\d+)\\s*seconds?\\s*work.*?(\\d+)\\s*seconds?\\s*rest\\)", "hiit"),
        ("Circuit.*?\\((\\d+)\\s*Rounds?\\)", "circuit"),
        ("Superset.*?\\((\\d+)\\s*Rounds?\\)", "superset"),
        ("\\bDay\\s*\\d+:?\\s*([\\w\\s&]+)", "day")
    ]
    
    static let exercisePatterns: [(pattern: String, component: String)] = [
        // Time-based patterns
        ("(\\d+)\\s*(?:seconds?|sec|s)(?:\\s*(?:hold|each\\s*side)?)", "time"),
        ("hold\\s*(?:for\\s*)?(\\d+)\\s*(?:seconds?|sec|s)", "time"),
        
        // Reps patterns
        ("(\\d+(?:-\\d+)?)\\s*(?:reps?|repetitions?)", "reps"),
        ("(\\d+)\\s*(?:times|counts)", "reps"),
        
        // Sets patterns
        ("(\\d+)\\s*(?:sets?|x|×)", "sets"),
        
        // Per side/leg/arm patterns
        ("(?:per|each)\\s*(?:side|leg|arm|direction)", "perSide")
    ]
    
    static func parseProgram(_ text: String) -> (type: ProgramType, name: String)? {
        for (pattern, type) in programPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchText = String(text[match])
                
                switch type {
                case "hiit":
                    if let roundsMatch = matchText.range(of: "(\\d+)\\s*Rounds?", options: .regularExpression),
                       let workMatch = matchText.range(of: "(\\d+)\\s*seconds?\\s*work", options: .regularExpression),
                       let restMatch = matchText.range(of: "(\\d+)\\s*seconds?\\s*rest", options: .regularExpression) {
                        
                        let rounds = Int(matchText[roundsMatch].replacingOccurrences(of: "[^0-9]", with: "")) ?? 1
                        let workTime = Int(matchText[workMatch].replacingOccurrences(of: "[^0-9]", with: "")) ?? 30
                        let restTime = Int(matchText[restMatch].replacingOccurrences(of: "[^0-9]", with: "")) ?? 10
                        
                        return (.hiit(rounds: rounds, workTime: workTime, restTime: restTime), matchText)
                    }
                case "circuit", "superset":
                    if let roundsMatch = matchText.range(of: "(\\d+)\\s*Rounds?", options: .regularExpression) {
                        let rounds = Int(matchText[roundsMatch].replacingOccurrences(of: "[^0-9]", with: "")) ?? 1
                        return (type == "circuit" ? .circuit(rounds: rounds) : .superset(rounds: rounds), matchText)
                    }
                default:
                    return (.regular, matchText)
                }
            }
        }
        return nil
    }
    
    static func parseExercise(_ text: String) -> ExerciseComponents {
        var components = ExerciseComponents(name: "", sets: 3, reps: "", duration: nil, perSide: false, isTime: false)
        
        // Clean and extract exercise name with details in parentheses
        let cleanText = text.replacingOccurrences(of: "^[•\\-\\d\\.\\s]+", with: "", options: .regularExpression)
        let parts = cleanText.components(separatedBy: ["–", "-", "—"])  // Handle different dash types
        
        if let name = parts.first {
            components.name = name.trimmingCharacters(in: .whitespaces)
        }
        
        if parts.count > 1 {
            let details = parts.dropFirst().joined(separator: "-").lowercased().trimmingCharacters(in: .whitespaces)
            
            // First try to match the "NxM-K" pattern (e.g., "4x6-8")
            if let match = details.range(of: "(\\d+)\\s*x\\s*(\\d+)\\s*-\\s*(\\d+)", options: .regularExpression) {
                let matchText = String(details[match])
                let numbers = matchText.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Int($0) }
                
                if numbers.count == 3 {
                    components.sets = numbers[0]
                    components.reps = "\(numbers[1])-\(numbers[2]) reps"
                    return components  // Return early if we found this pattern
                }
            }
            
            // Then try to match just "NxM" pattern (e.g., "3x12")
            if let match = details.range(of: "(\\d+)\\s*x\\s*(\\d+)", options: .regularExpression) {
                let matchText = String(details[match])
                let numbers = matchText.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Int($0) }
                
                if numbers.count == 2 {
                    components.sets = numbers[0]
                    components.reps = "\(numbers[1]) reps"
                    return components
                }
            }
            
            // Pattern for "X sets of Y reps"
            if let match = details.range(of: "(\\d+)\\s*sets?\\s*of\\s*(\\d+(?:-\\d+)?)\\s*reps?", options: .regularExpression) {
                let setsRepsText = String(details[match])
                
                // Extract sets
                if let setsMatch = setsRepsText.range(of: "\\d+(?=\\s*sets?)", options: .regularExpression) {
                    components.sets = Int(String(setsRepsText[setsMatch])) ?? 3
                }
                
                // Extract reps with proper formatting
                if let repsMatch = setsRepsText.range(of: "(\\d+)-(\\d+)\\s*reps?", options: .regularExpression) {
                    let repsText = String(setsRepsText[repsMatch])
                    let numbers = repsText.components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .compactMap { Int($0) }
                    if numbers.count == 2 {
                        components.reps = "\(numbers[0])-\(numbers[1]) reps"
                    }
                } else if let singleRepsMatch = setsRepsText.range(of: "(\\d+)\\s*reps?", options: .regularExpression) {
                    let repsStr = String(setsRepsText[singleRepsMatch])
                        .replacingOccurrences(of: "reps", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    components.reps = "\(repsStr) reps"
                }
            }
            
            // If no reps were found, check for individual patterns
            if components.reps.isEmpty {
                // Look for reps pattern like "12 reps" or "10-12 reps"
                if let repsMatch = details.range(of: "(\\d+(?:-\\d+)?)\\s*reps?", options: .regularExpression) {
                    let repsText = String(details[repsMatch])
                    components.reps = repsText.formatAsReps()
                }
            }
            
            // Pattern for hold/time
            let holdPattern = "hold\\s*(?:for\\s*)?(\\d+)\\s*seconds?"
            if let timeMatch = details.range(of: holdPattern, options: .regularExpression) {
                let timeStr = String(details[timeMatch])
                if let seconds = timeStr.firstMatch(of: /\d+/)?.output {
                    components.duration = "\(seconds) seconds"
                    components.isTime = true
                }
            }
            
            // Check for per side/leg/arm
            if details.contains("per leg") {
                components.perSide = true
                if !components.reps.isEmpty {
                    components.reps += " per leg"
                }
            } else if details.contains("per side") {
                components.perSide = true
                if !components.reps.isEmpty {
                    components.reps += " per side"
                }
            }
        }
        
        // Ensure reps has a value and proper format
        if components.reps.isEmpty && !components.isTime {
            components.reps = "12-15 reps"  // Default value
        }
        
        return components
    }
}

// Helper extension
extension WorkoutProgramParser.ProgramType {
    var rounds: Int? {
        switch self {
        case .regular: return nil
        case .circuit(let rounds): return rounds
        case .hiit(let rounds, _, _): return rounds
        case .superset(let rounds): return rounds
        }
    }
}

// Add this extension at the bottom of the file
extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespaces)
    }
}

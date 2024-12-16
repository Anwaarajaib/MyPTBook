import Foundation
import UIKit

struct Client: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var phoneNumber: String
    var age: Int
    var height: Double
    var weight: Double
    var medicalHistory: String
    var notes: String
    var goals: String
    var goalsNotes: String
    var sessions: [Session]
    var profileImage: UIImage?
    var nutritionPlan: String
    
    init(id: UUID = UUID(), 
         name: String = "",
         email: String = "",
         phoneNumber: String = "",
         age: Int = 0,
         height: Double = 0.0,
         weight: Double = 0.0,
         medicalHistory: String = "",
         notes: String = "",
         goals: String = "",
         goalsNotes: String = "",
         sessions: [Session] = [],
         profileImage: UIImage? = nil,
         nutritionPlan: String = "") {
        self.id = id
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.age = age
        self.height = height
        self.weight = weight
        self.medicalHistory = medicalHistory
        self.notes = notes
        self.goals = goals
        self.goalsNotes = goalsNotes
        self.sessions = sessions
        self.profileImage = profileImage
        self.nutritionPlan = nutritionPlan
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, email, phoneNumber, age, height, weight, 
             medicalHistory, notes, goals, goalsNotes, sessions, nutritionPlan
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(age, forKey: .age)
        try container.encode(height, forKey: .height)
        try container.encode(weight, forKey: .weight)
        try container.encode(medicalHistory, forKey: .medicalHistory)
        try container.encode(notes, forKey: .notes)
        try container.encode(goals, forKey: .goals)
        try container.encode(goalsNotes, forKey: .goalsNotes)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(nutritionPlan, forKey: .nutritionPlan)
    }
}

struct Session: Codable, Identifiable {
    let id: UUID
    var date: Date
    var duration: TimeInterval
    var notes: String?
    var exercises: [Exercise]
    var type: String?
    var isCompleted: Bool
    var sessionNumber: Int
    
    init(id: UUID = UUID(),
         date: Date = Date(),
         duration: TimeInterval = 0,
         notes: String? = nil,
         exercises: [Exercise] = [],
         type: String? = nil,
         isCompleted: Bool = false,
         sessionNumber: Int = 1) {
        self.id = id
        self.date = date
        self.duration = duration
        self.notes = notes
        self.exercises = exercises
        self.type = type
        self.isCompleted = isCompleted
        self.sessionNumber = sessionNumber
    }
}

struct Exercise: Codable, Identifiable {
    let id: UUID
    var name: String
    var sets: Int
    var reps: String
    var weight: String
    var notes: String?
    var isPartOfCircuit: Bool
    var circuitRounds: Int?
    var circuitName: String?
    var setPerformances: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, sets, reps, weight, notes, isPartOfCircuit, circuitRounds, circuitName, setPerformances
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sets = try container.decode(Int.self, forKey: .sets)
        reps = try container.decode(String.self, forKey: .reps)
        weight = try container.decode(String.self, forKey: .weight)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isPartOfCircuit = try container.decode(Bool.self, forKey: .isPartOfCircuit)
        circuitRounds = try container.decodeIfPresent(Int.self, forKey: .circuitRounds)
        circuitName = try container.decodeIfPresent(String.self, forKey: .circuitName)
        // Handle missing setPerformances for backward compatibility
        setPerformances = (try? container.decodeIfPresent([String].self, forKey: .setPerformances)) ?? Array(repeating: "", count: sets)
    }
    
    init(id: UUID = UUID(),
         name: String = "",
         sets: Int = 0,
         reps: String = "",
         weight: String = "",
         notes: String? = nil,
         isPartOfCircuit: Bool = false,
         circuitRounds: Int? = nil,
         circuitName: String? = nil,
         setPerformances: [String] = []) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.notes = notes
        self.isPartOfCircuit = isPartOfCircuit
        self.circuitRounds = circuitRounds
        self.circuitName = circuitName
        self.setPerformances = setPerformances.count == sets ? setPerformances : Array(repeating: "", count: sets)
    }
}

// MARK: - Convenience Methods
extension Client {
    static func empty() -> Client {
        Client()
    }
}

// MARK: - Helper Methods
extension Session {
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
} 
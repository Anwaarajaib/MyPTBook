import Foundation
import UIKit

struct Client: Identifiable, Codable {
    let id: UUID
    var name: String
    var age: Int
    var height: Double
    var weight: Double
    var medicalHistory: String
    var goals: String
    var sessions: [Session]
    var nutritionPlan: String
    private var _profileImage: UIImage?
    
    var profileImage: UIImage? {
        get {
            _profileImage ?? DataManager.shared.getClientImage(clientId: id)
        }
        set {
            _profileImage = newValue
            DataManager.shared.saveClientImage(newValue, clientId: id)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, age, height, weight, 
             medicalHistory, goals, sessions, nutritionPlan
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let idString = try container.decode(String.self, forKey: .id)
        id = UUID(uuidString: idString) ?? UUID()
        
        name = try container.decode(String.self, forKey: .name)
        age = try container.decode(Int.self, forKey: .age)
        height = try container.decode(Double.self, forKey: .height)
        weight = try container.decode(Double.self, forKey: .weight)
        medicalHistory = try container.decode(String.self, forKey: .medicalHistory)
        goals = try container.decode(String.self, forKey: .goals)
        sessions = try container.decodeIfPresent([Session].self, forKey: .sessions) ?? []
        nutritionPlan = try container.decode(String.self, forKey: .nutritionPlan)
        _profileImage = nil
    }
    
    init(id: UUID = UUID(), 
         name: String = "",
         age: Int = 0,
         height: Double = 0.0,
         weight: Double = 0.0,
         medicalHistory: String = "",
         goals: String = "",
         sessions: [Session] = [],
         profileImage: UIImage? = nil,
         nutritionPlan: String = "") {
        self.id = id
        self.name = name
        self.age = age
        self.height = height
        self.weight = weight
        self.medicalHistory = medicalHistory
        self.goals = goals
        self.sessions = sessions
        self._profileImage = profileImage
        self.nutritionPlan = nutritionPlan
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(age, forKey: .age)
        try container.encode(height, forKey: .height)
        try container.encode(weight, forKey: .weight)
        try container.encode(medicalHistory, forKey: .medicalHistory)
        try container.encode(goals, forKey: .goals)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(nutritionPlan, forKey: .nutritionPlan)
    }
}

struct Session: Codable, Identifiable {
    let id: UUID
    var date: Date
    var duration: TimeInterval
    var exercises: [Exercise]
    var type: String?
    var isCompleted: Bool
    var sessionNumber: Int
    
    init(id: UUID = UUID(),
         date: Date = Date(),
         duration: TimeInterval = 0,
         exercises: [Exercise] = [],
         type: String? = nil,
         isCompleted: Bool = false,
         sessionNumber: Int = 1) {
        self.id = id
        self.date = date
        self.duration = duration
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
    var isPartOfCircuit: Bool
    var circuitRounds: Int?
    var circuitName: String?
    var setPerformances: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, sets, reps, weight, isPartOfCircuit, circuitRounds, circuitName, setPerformances
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sets = try container.decode(Int.self, forKey: .sets)
        reps = try container.decode(String.self, forKey: .reps)
        weight = try container.decode(String.self, forKey: .weight)
        isPartOfCircuit = try container.decode(Bool.self, forKey: .isPartOfCircuit)
        circuitRounds = try container.decodeIfPresent(Int.self, forKey: .circuitRounds)
        circuitName = try container.decodeIfPresent(String.self, forKey: .circuitName)
        setPerformances = (try? container.decodeIfPresent([String].self, forKey: .setPerformances)) ?? Array(repeating: "", count: sets)
    }
    
    init(id: UUID = UUID(),
         name: String = "",
         sets: Int = 0,
         reps: String = "",
         weight: String = "",
         isPartOfCircuit: Bool = false,
         circuitRounds: Int? = nil,
         circuitName: String? = nil,
         setPerformances: [String] = []) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
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
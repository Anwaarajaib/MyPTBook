import Foundation

struct Session: Codable, Identifiable {
    let _id: String
    var id: String { _id }
    var workoutName: String
    var client: String
    var completedDate: Date?
    var exercises: [Exercise]
    var isCompleted: Bool
    
    private enum CodingKeys: String, CodingKey {
        case _id, workoutName, client, completedDate, exercises, isCompleted
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(String.self, forKey: ._id)
        workoutName = try container.decode(String.self, forKey: .workoutName)
        client = try container.decode(String.self, forKey: .client)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        
        // Handle date decoding first
        if let dateString = try container.decodeIfPresent(String.self, forKey: .completedDate),
           !dateString.isEmpty {
            let formatter = ISO8601DateFormatter()
            completedDate = formatter.date(from: dateString)
        } else {
            completedDate = nil
        }
        
        // Handle exercises separately to avoid capture before initialization
        let sessionId = _id // Capture the ID locally
        if let exerciseObjects = try? container.decode([Exercise].self, forKey: .exercises) {
            exercises = exerciseObjects
        } else if let exerciseIds = try? container.decode([String].self, forKey: .exercises) {
            exercises = exerciseIds.map { id in
                Exercise(_id: id, exerciseName: "", sets: 0, reps: 0, weight: 0, session: sessionId)
            }
        } else {
            exercises = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_id, forKey: ._id)
        try container.encode(workoutName, forKey: .workoutName)
        try container.encode(client, forKey: .client)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(exercises.map { $0._id }, forKey: .exercises)
        
        if let date = completedDate {
            try container.encode(date.ISO8601Format(), forKey: .completedDate)
        } else {
            try container.encode("", forKey: .completedDate)
        }
    }
}
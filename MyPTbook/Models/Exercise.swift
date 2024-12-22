import Foundation

struct Exercise: Codable, Identifiable, Equatable {
    let _id: String
    var id: String { _id }
    var exerciseName: String
    var sets: Int
    var reps: Int
    var weight: Double
    var time: Int?
    var groupType: GroupType?
    var session: String
    
    enum GroupType: String, Codable {
        case superset
        case circuit
    }
    
    private enum CodingKeys: String, CodingKey {
        case _id, exerciseName, sets, reps, weight, time, groupType, session
    }
    
    init(_id: String = "",
         exerciseName: String,
         sets: Int,
         reps: Int,
         weight: Double,
         time: Int? = nil,
         groupType: GroupType? = nil,
         session: String = "") {
        self._id = _id
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.time = time
        self.groupType = groupType
        self.session = session
    }
    
    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        lhs._id == rhs._id
    }
}
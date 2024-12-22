import Foundation

struct Client: Codable, Identifiable {
    let _id: String
    var name: String
    var age: Int
    var height: Double
    var weight: Double
    var medicalHistory: String
    var goals: String
    var clientImage: String
    var user: String?
    var sessions: [Session]?
    
    var id: String { _id }
    
    init(name: String, age: Int, height: Double, weight: Double, medicalHistory: String, goals: String, clientImage: String, user: String? = nil) {
        self._id = UUID().uuidString
        self.name = name
        self.age = age
        self.height = height
        self.weight = weight
        self.medicalHistory = medicalHistory
        self.goals = goals
        self.clientImage = clientImage
        self.user = user
        self.sessions = nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case _id
        case name
        case age
        case height
        case weight
        case medicalHistory
        case goals
        case clientImage
        case user
        case sessions
    }
}
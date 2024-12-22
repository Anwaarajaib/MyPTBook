import Foundation

struct Trainer: Codable {
    let _id: String
    var id: String { _id }
    let name: String
    let email: String
    let userImage: String?
    
    private enum CodingKeys: String, CodingKey {
        case _id, name, email, userImage
    }
} 
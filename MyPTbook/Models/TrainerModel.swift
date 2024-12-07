import SwiftUI

class TrainerModel: ObservableObject {
    @Published var name: String = "Your Name"
    @Published var profileImage: UIImage?
} 
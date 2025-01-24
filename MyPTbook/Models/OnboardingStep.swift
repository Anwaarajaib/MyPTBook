import Foundation

struct OnboardingStep: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
} 
import Foundation

extension UserDefaults {
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
    
    var hasCompletedOnboarding: Bool {
        get {
            bool(forKey: Keys.hasCompletedOnboarding)
        }
        set {
            set(newValue, forKey: Keys.hasCompletedOnboarding)
        }
    }
} 
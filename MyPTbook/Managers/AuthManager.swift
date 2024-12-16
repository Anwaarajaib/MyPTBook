import Foundation

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool {
        didSet {
            UserDefaults.standard.set(isAuthenticated, forKey: "isAuthenticated")
        }
    }
    
    init() {
        // Load saved authentication state when initializing
        self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
    }
    
    func login(email: String, password: String) async throws {
        // Add your login logic here
        // For now, we'll just simulate a successful login
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
        isAuthenticated = true
    }
    
    func register(email: String, password: String) async throws {
        // Add registration logic here
        // For now, we'll just simulate a successful registration
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
        isAuthenticated = true
    }
    
    func logout() {
        isAuthenticated = false
        // Clear any stored user data if needed
        UserDefaults.standard.removeObject(forKey: "userEmail")
    }
} 
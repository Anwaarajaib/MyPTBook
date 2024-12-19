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
        let token = try await APIClient.shared.login(email: email, password: password)
        await MainActor.run {
            isAuthenticated = true
            DataManager.shared.saveAuthToken(token)
        }
    }
    
    func register(email: String, password: String, name: String = "") async throws {
        let token = try await APIClient.shared.register(email: email, password: password, name: name)
        await MainActor.run {
            isAuthenticated = true
            DataManager.shared.saveAuthToken(token)
        }
    }
    
    func logout() {
        isAuthenticated = false
        // Clear any stored user data if needed
        UserDefaults.standard.removeObject(forKey: "userEmail")
    }
} 
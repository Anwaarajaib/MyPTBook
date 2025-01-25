import Foundation

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    private let dataManager = DataManager.shared
    
    static let shared = AuthManager()
    
    private init() {
        isAuthenticated = dataManager.isLoggedIn()
        print("AuthManager: Initialized - isAuthenticated:", isAuthenticated)
        if isAuthenticated {
            print("AuthManager: Current user - Name:", dataManager.userName, "Email:", dataManager.userEmail)
        }
    }
    
    func login(email: String, password: String) async throws {
        print("AuthManager: Attempting login for email:", email)
        let response = try await APIClient.shared.login(email: email, password: password)
        
        await MainActor.run {
            dataManager.handleLoginSuccess(response: response)
            isAuthenticated = true
            print("AuthManager: Login successful - User:", response.user.name, "Email:", response.user.email)
        }
    }
    
    func register(name: String, email: String, password: String) async throws {
        print("AuthManager: Attempting registration - Name:", name, "Email:", email)
        let response = try await APIClient.shared.register(name: name, email: email, password: password)
        
        await MainActor.run {
            dataManager.handleLoginSuccess(response: response)
            isAuthenticated = true
            print("AuthManager: Registration successful - User:", response.user.name, "Email:", response.user.email)
        }
    }
    
    func logout() {
        print("AuthManager: Logging out user - Name:", dataManager.userName, "Email:", dataManager.userEmail)
        dataManager.logout()
        isAuthenticated = false
        print("AuthManager: Logout successful")
    }
} 
import Foundation

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case unauthorized
    case serverError(String)
    case validationError([String])
    case networkError(Error)
}

class APIClient {
    static let shared = APIClient()
    
    #if DEBUG
    private let baseURL = "http://192.168.0.109:5001/api"  // Your actual IP address
    #else
    private let baseURL = "https://your-production-server.com/api"  // Replace with your production URL when ready
    #endif
    
    private var authToken: String? {
        get {
            let token = DataManager.shared.getAuthToken()
            #if DEBUG
            print("APIClient: Retrieved token: \(token ?? "nil")")
            #endif
            return token
        }
        set {
            #if DEBUG
            print("APIClient: Setting token: \(newValue ?? "nil")")
            #endif
            if let token = newValue {
                DataManager.shared.saveAuthToken(token)
            } else {
                DataManager.shared.removeAuthToken()
            }
        }
    }
    
    // Add timeout and retry configuration
    private func configuredURLRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        #if DEBUG
        print("Making request to: \(url.absoluteString)")
        #endif
        
        return request
    }
    
    // Update isAuthenticated to check for valid token
    func isAuthenticated() -> Bool {
        return DataManager.shared.getAuthToken() != nil
    }
    
    // Update verifyToken to be more robust
    func verifyToken() async throws -> Bool {
        guard let token = authToken else {
            #if DEBUG
            print("No token available for verification")
            #endif
            return false
        }
        
        // If there's a stored token and we can't reach the server,
        // assume the token is valid to allow offline access
        do {
            guard let url = URL(string: "\(baseURL)/auth/status") else { // Changed endpoint to /auth/status
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            switch httpResponse.statusCode {
            case 200:
                return true
            case 401:
                authToken = nil
                return false
            default:
                // If we can't reach the server or get an unexpected response,
                // keep the user logged in if they have a token
                return true
            }
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    // Allow offline access if there's a stored token
                    return true
                default:
                    throw error
                }
            }
            throw error
        }
    }
    
    // Update logout to be more thorough
    func logout() {
        authToken = nil  // This will trigger the setter to remove from UserDefaults
        NotificationCenter.default.post(name: NSNotification.Name("LogoutNotification"), object: nil)
    }
    
    // Update fetchClients to handle server-side data
    func fetchClients() async throws -> [Client] {
        guard let token = authToken else {
            throw APIError.unauthorized
        }
        
        guard let url = URL(string: "\(baseURL)/clients") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            let clients = try JSONDecoder().decode([Client].self, from: data)
            DataManager.shared.saveClients(clients) // Cache clients locally
            return clients
        case 401:
            authToken = nil // Clear invalid token
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    // Login method
    func login(email: String, password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw APIError.invalidURL
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email.lowercased(), "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Invalid response")
            }
            
            switch httpResponse.statusCode {
            case 200, 201:
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.authToken = tokenResponse.token
                return tokenResponse.token
            case 401:
                throw APIError.unauthorized
            case 400:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw APIError.validationError(errorResponse.errors)
                }
                throw APIError.serverError("Invalid request")
            default:
                throw APIError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch {
            throw handleNetworkError(error)
        }
    }
    
    // Register method with improved error handling
    func register(email: String, password: String, name: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            throw APIError.invalidURL
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password, "name": name]
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Invalid response")
            }
            
            switch httpResponse.statusCode {
            case 200, 201:
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.authToken = tokenResponse.token
                return tokenResponse.token
            case 400:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw APIError.validationError(errorResponse.errors)
                }
                throw APIError.serverError("Invalid request")
            case 500...599:
                throw APIError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw APIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }
        } catch let error {
            throw handleNetworkError(error)
        }
    }
    
    // Add other API methods as needed...
    
    private func handleNetworkError(_ error: Error) -> APIError {
        #if DEBUG
        print("Network error: \(error.localizedDescription)")
        if let urlError = error as? URLError {
            print("URL Error code: \(urlError.code.rawValue)")
            print("URL Error description: \(urlError.localizedDescription)")
        }
        #endif
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return .networkError(urlError)
            case .timedOut:
                return .networkError(urlError)
            case .cannotConnectToHost:
                return .serverError("""
                    Cannot connect to server. Please ensure:
                    1. You're connected to the same WiFi as the development machine
                    2. The backend server is running
                    3. The IP address is correct (\(self.baseURL))
                    """)
            default:
                return .networkError(urlError)
            }
        }
        return .serverError(error.localizedDescription)
    }
}

struct ErrorResponse: Codable {
    let errors: [String]
}

struct TokenResponse: Codable {
    let token: String
}

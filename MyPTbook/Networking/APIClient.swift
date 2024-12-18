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
    
    private let baseURL = "https://my-pt-book-app-backend.vercel.app/api"
    
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
        guard let url = URL(string: "\(baseURL)/clients") else {
            throw APIError.invalidURL
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "GET"
        
        // Log the auth token being used
        print("Using auth token:", authToken ?? "No token")
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        
        print("Fetching clients from:", url.absoluteString)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        print("Client response status:", httpResponse.statusCode)
        if let responseString = String(data: data, encoding: .utf8) {
            print("Client response data:", responseString)
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            
            // Create custom date decoder that handles multiple formats
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try ISO8601 first
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    return date
                }
                
                // Try timestamp
                if let timestamp = Double(dateString) {
                    return Date(timeIntervalSince1970: timestamp)
                }
                
                // Try custom format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
            }
            
            do {
                let clients = try decoder.decode([Client].self, from: data)
                print("Successfully decoded \(clients.count) clients")
                clients.forEach { client in
                    print("Client: \(client.id) - \(client.name)")
                }
                return clients
            } catch {
                print("Decoding error:", error)
                print("Decoding error details:", (error as? DecodingError).map { "\($0)" } ?? "Unknown error")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("Raw data:", dataString)
                }
                throw error
            }
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    // Login method
    func login(email: String, password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            print("Invalid URL: \(baseURL)/auth/login")
            throw APIError.invalidURL
        }
        
        print("Attempting to connect to: \(url.absoluteString)")
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginData = ["email": email.lowercased(), "password": password]
        request.httpBody = try JSONEncoder().encode(loginData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                throw APIError.serverError("Invalid response")
            }
            
            print("Response status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response data: \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                self.authToken = loginResponse.token
                return loginResponse.token
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
        } catch let error as URLError {
            print("URLError: \(error.localizedDescription)")
            print("Error code: \(error.code)")
            throw APIError.networkError(error)
        } catch {
            print("Other error: \(error.localizedDescription)")
            throw error
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
    
    // MARK: - Client Methods
    func createClient(_ client: Client) async throws -> Client {
        guard let url = URL(string: "\(baseURL)/clients") else {
            throw APIError.invalidURL
        }
        
        guard let token = authToken else {
            throw APIError.unauthorized
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(client)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 201:
            return try JSONDecoder().decode(Client.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func updateClient(_ client: Client) async throws -> Client {
        guard let url = URL(string: "\(baseURL)/clients/\(client.id)") else {
            throw APIError.invalidURL
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(client)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(Client.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func deleteClient(id: UUID) async throws {
        guard let url = URL(string: "\(baseURL)/clients/\(id.uuidString)") else {
            throw APIError.invalidURL
        }
        
        print("Deleting client with ID:", id.uuidString) // Debug log
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        print("Delete response code:", httpResponse.statusCode) // Debug log
        if let responseString = String(data: data, encoding: .utf8) {
            print("Response data:", responseString) // Debug log
        }
        
        switch httpResponse.statusCode {
        case 200:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.serverError("Client not found")
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - Session Methods
    func fetchClientSessions(clientId: UUID) async throws -> [Session] {
        guard let url = URL(string: "\(baseURL)/clients/\(clientId)/sessions") else {
            throw APIError.invalidURL
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode([Session].self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func createSessions(clientId: UUID, sessions: [Session]) async throws -> [Session] {
        guard let url = URL(string: "\(baseURL)/clients/\(clientId)/sessions") else {
            throw APIError.invalidURL
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create encoder with custom date encoding strategy
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Transform sessions to ensure IDs are included
        let sessionsToSend = sessions.map { session in
            var mutableSession = session
            if mutableSession.id == UUID() {
                mutableSession = Session(
                    id: UUID(), // Generate new UUID if none exists
                    date: session.date,
                    duration: session.duration,
                    exercises: session.exercises,
                    type: session.type,
                    isCompleted: session.isCompleted,
                    sessionNumber: session.sessionNumber
                )
            }
            return mutableSession
        }
        
        let payload = ["sessions": sessionsToSend]
        let encodedData = try encoder.encode(payload)
        
        if let jsonString = String(data: encodedData, encoding: .utf8) {
            print("Session payload:", jsonString)
        }
        
        request.httpBody = encodedData
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 201:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Session].self, from: responseData)
        case 401:
            throw APIError.unauthorized
        default:
            if let errorString = String(data: responseData, encoding: .utf8) {
                print("Server error response:", errorString)
            }
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func updateSession(clientId: UUID, session: Session) async throws -> Session {
        guard let url = URL(string: "\(baseURL)/clients/\(clientId)/sessions/\(session.id)") else {
            throw APIError.invalidURL
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(session)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(Session.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func deleteSession(clientId: UUID, sessionId: UUID) async throws {
        guard let url = URL(string: "\(baseURL)/clients/\(clientId)/sessions/\(sessionId)") else {
            throw APIError.invalidURL
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            return
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    // Add to APIClient class
    func updateUserProfile(name: String) async throws -> UserResponse {
        guard let url = URL(string: "\(baseURL)/auth/profile") else {
            throw APIError.invalidURL
        }
        
        var request = configuredURLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": name]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(UserResponse.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
}

struct ErrorResponse: Codable {
    let errors: [String]
}

struct TokenResponse: Codable {
    let token: String
}

struct LoginResponse: Codable {
    let token: String
    let user: UserResponse
}

struct UserResponse: Codable {
    let id: String
    let name: String
    let email: String
}

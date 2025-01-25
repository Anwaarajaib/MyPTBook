import Foundation
import UIKit

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
    // Make sure this IP matches your computer's local IP address
    private let baseURL = "https://my-pt-book-phi.vercel.app/api"  // For the device
    #else
    private let baseURL = "http://localhost:5001/api"  // For simulator
    #endif
    
    // Add network configuration
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    // MARK: - Auth Endpoints
    
    func login(email: String, password: String) async throws -> LoginResponse {
        print("APIClient: Attempting login for email:", email)
        let url = URL(string: "\(baseURL)/user/login")!
        let body = ["email": email.lowercased(), "password": password]
        
        print("APIClient: Making login request to:", url)
        let response: LoginResponse = try await post(url: url, body: body)
        print("APIClient: Login successful - User:", response.user.name)
        print("APIClient: Profile image URL:", response.user.profileImage ?? "none")
        return response
    }
    
    func register(name: String, email: String, password: String) async throws -> LoginResponse {
        let url = URL(string: "\(baseURL)/user/register")!
        let body = ["name": name, "email": email.lowercased(), "password": password]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            return try decoder.decode(LoginResponse.self, from: data)
        case 400:
            if let errorResponse = try? JSONDecoder().decode(ValidationErrorResponse.self, from: data) {
                throw APIError.validationError([errorResponse.message])
            }
            throw APIError.serverError("Invalid request")
        default:
            if (try? JSONDecoder().decode(ErrorResponse.self, from: data)) != nil {
                throw APIError.serverError("Server error: \(httpResponse.statusCode)")
            }
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func updateUserProfile(name: String) async throws -> UserResponse {
        let url = URL(string: "\(baseURL)/user/profile")!
        let body = ["name": name]
        
        print("APIClient: Updating user profile - Name:", name)
        let response: UserResponse = try await put(url: url, body: body)
        print("APIClient: Profile update response - Name:", response.name, "Email:", response.email)
        return response
    }
    
    // MARK: - Client Endpoints
    
    func fetchClients() async throws -> [Client] {
        let url = URL(string: "\(baseURL)/client")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("APIClient: Fetching clients")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "", code: -1))
            }
            
            print("APIClient: Response status code:", httpResponse.statusCode)
            if let responseString = String(data: data, encoding: .utf8) {
                print("APIClient: Raw response:", responseString)
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                do {
                    let clients = try decoder.decode([Client].self, from: data)
                    print("APIClient: Successfully decoded \(clients.count) clients")
                    print("APIClient: Client images:", clients.map { $0.clientImage })
                    return clients
                } catch {
                    print("APIClient: Decoding error:", error)
                    throw error
                }
            case 401:
                throw APIError.unauthorized
            default:
                throw APIError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch {
            print("APIClient: Network or decoding error:", error)
            throw error
        }
    }
    
    func createClient(_ client: Client) async throws -> Client {
        print("APIClient: Creating client")
        let url = URL(string: "\(baseURL)/client")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create an encodable struct that matches backend expectations
        struct CreateClientRequest: Encodable {
            let name: String
            let age: Int
            let height: Double
            let weight: Double
            let medicalHistory: String
            let goals: String
            let clientImage: String
            let userId: String  // Keep this as userId
        }
        
        // Create the request body
        let requestBody = CreateClientRequest(
            name: client.name,
            age: client.age,
            height: client.height,
            weight: client.weight,
            medicalHistory: client.medicalHistory,
            goals: client.goals,
            clientImage: client.clientImage,
            userId: client.userId ?? ""  // Use userId instead of user
        )
        
        print("APIClient: Creating client with request body:", requestBody)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        print("APIClient: Sending request to create client with userId:", client.userId ?? "no user")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        print("APIClient: Response status code:", httpResponse.statusCode)
        if let responseString = String(data: data, encoding: .utf8) {
            print("APIClient: Raw response:", responseString)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let createdClient = try decoder.decode(Client.self, from: data)
            print("APIClient: Client created successfully")
            return createdClient
        case 401:
            throw APIError.unauthorized
        default:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.message)
            }
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func updateClient(_ client: Client) async throws -> Client {
        let url = URL(string: "\(baseURL)/client/\(client._id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(client)
        
        print("APIClient: Updating client")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let updatedClient = try decoder.decode(Client.self, from: data)
            print("APIClient: Client updated successfully")
            return updatedClient
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func deleteClient(id: String) async throws {
        let url = URL(string: "\(baseURL)/client/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("APIClient: Deleting client")
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            print("APIClient: Client deleted successfully")
            return
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - Session Endpoints
    
    func createSessions(clientId: String, sessions: [Session]) async throws -> [Session] {
        let url = URL(string: "\(baseURL)/session")!
        return try await post(url: url, body: sessions)
    }
    
    func fetchClientSessions(clientId: String) async throws -> [Session] {
        let url = URL(string: "\(baseURL)/session/client/\(clientId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("APIClient: Fetching sessions for client:", clientId)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        print("APIClient: Response status code:", httpResponse.statusCode)
        if let responseString = String(data: data, encoding: .utf8) {
            print("APIClient: Raw response:", responseString)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let sessions = try decoder.decode([Session].self, from: data)
                print("APIClient: Successfully decoded \(sessions.count) sessions")
                return sessions
            } catch {
                print("APIClient: Decoding error:", error)
                throw APIError.decodingError
            }
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func updateSession(clientId: String, session: Session) async throws -> Session {
        let url = URL(string: "\(baseURL)/session/\(session._id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Only send the fields we want to update
        let updateData: [String: Any] = [
            "workoutName": session.workoutName,
            "isCompleted": session.isCompleted,
            "completedDate": session.completedDate?.ISO8601Format() ?? NSNull(),
            "client": session.client,
            "exercises": session.exercises.map { $0._id } // Send exercise IDs
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: updateData)
        request.httpBody = jsonData
        
        print("APIClient: Updating session with data:", String(data: jsonData, encoding: .utf8) ?? "")
        let (data, response) = try await self.session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        print("APIClient: Response status code:", httpResponse.statusCode)
        if let responseString = String(data: data, encoding: .utf8) {
            print("APIClient: Raw response:", responseString)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let updatedSession = try decoder.decode(Session.self, from: data)
            
            // Preserve the full exercise objects from the original session
            var sessionWithExercises = updatedSession
            sessionWithExercises.exercises = session.exercises
            return sessionWithExercises
            
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func deleteSession(clientId: String, sessionId: String) async throws {
        let url = URL(string: "\(baseURL)/session/\(sessionId)")!
        try await delete(url: url)
    }
    
    // MARK: - Exercise Endpoints
    
    func createExercise(exerciseData: [String: Any]) async throws -> Exercise {
        let url = URL(string: "\(baseURL)/exercise")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add logging to verify the data being sent
        print("APIClient: Creating exercise with data:", exerciseData)
        
        let jsonData = try JSONSerialization.data(withJSONObject: exerciseData)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        // Add logging to verify the response
        if let responseString = String(data: data, encoding: .utf8) {
            print("APIClient: Raw response:", responseString)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let createdExercise = try decoder.decode(Exercise.self, from: data)
            print("APIClient: Exercise created successfully with groupId:", createdExercise.groupId ?? "nil")
            return createdExercise
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func deleteExercise(exerciseId: String) async throws {
        let url = URL(string: "\(baseURL)/exercise/\(exerciseId)")!
        try await delete(url: url)
    }
    
    func fetchSessionExercises(sessionId: String) async throws -> [Exercise] {
        let url = URL(string: "\(baseURL)/exercise/session/\(sessionId)")!
        return try await get(url: url)
    }
    
    // MARK: - Generic Network Methods
    
    private func get<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            return try decoder.decode(T.self, from: data)
        case 404:
            // For nutrition endpoint, return empty nutrition plan
            if T.self == Nutrition.self {
                return Nutrition(_id: "", client: "", meals: []) as! T
            }
            throw APIError.serverError("Not found")
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    private func post<T: Encodable, U: Decodable>(url: URL, body: T) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            return try decoder.decode(U.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    private func put<T: Encodable, U: Decodable>(url: URL, body: T) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            return try decoder.decode(U.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    private func delete(url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func verifyToken() async throws -> Bool {
        guard let token = DataManager.shared.getAuthToken() else {
            return false
        }
        
        let url = URL(string: "\(baseURL)/user/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200
    }
    
    func getProfile() async throws -> UserResponse {
        let url = URL(string: "\(baseURL)/user/profile")!
        return try await get(url: url)
    }
    
    func uploadClientImage(clientId: String, imageData: Data) async throws -> String {
        let url = URL(string: "\(baseURL)/client/\(clientId)/image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let result = try decoder.decode([String: String].self, from: data)
            return result["imageUrl"] ?? ""
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func createSession(clientId: String, sessionData: [String: Any]) async throws -> Session {
        let url = URL(string: "\(baseURL)/session")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: sessionData)
        request.httpBody = jsonData
        
        print("APIClient: Creating session")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        print("APIClient: Response status code:", httpResponse.statusCode)
        if let responseString = String(data: data, encoding: .utf8) {
            print("APIClient: Raw response:", responseString)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let createdSession = try decoder.decode(Session.self, from: data)
            print("APIClient: Session created successfully")
            return createdSession
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func createNutrition(clientId: String, meals: [Nutrition.Meal]) async throws -> Nutrition {
        let url = URL(string: "\(baseURL)/nutrition")!
        
        // Create a dictionary that matches the expected backend format
        let body: [String: Any] = [
            "client": clientId,
            "meals": meals.map { meal in
                [
                    "mealName": meal.mealName,
                    "items": meal.items.map { item in
                        [
                            "name": item.name,
                            "quantity": item.quantity
                        ]
                    }
                ]
            }
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            return try decoder.decode(Nutrition.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func getNutritionForClient(clientId: String) async throws -> Nutrition {
        let url = URL(string: "\(baseURL)/nutrition/client/\(clientId)")!
        return try await get(url: url)
    }
    
    func updateNutrition(nutritionId: String, meals: [Nutrition.Meal]) async throws -> Nutrition {
        let url = URL(string: "\(baseURL)/nutrition/\(nutritionId)")!
        
        // Create a dictionary that matches the expected backend format
        let body: [String: Any] = [
            "meals": meals.map { meal in
                [
                    "mealName": meal.mealName,
                    "items": meal.items.map { item in
                        [
                            "name": item.name,
                            "quantity": item.quantity
                        ]
                    }
                ]
            }
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            return try decoder.decode(Nutrition.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func deleteNutrition(nutritionId: String) async throws {
        let url = URL(string: "\(baseURL)/nutrition/\(nutritionId)")!
        try await delete(url: url)
    }
    
    func uploadImage(_ imageData: Data) async throws -> String {
        print("APIClient: Starting image upload to Cloudinary...")
        // Use the same endpoint that works for client images
        let url = URL(string: "\(baseURL)/client/upload-image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create multipart form data
        var body = Data()
        print("APIClient: Creating multipart form data...")
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("APIClient: Sending image upload request...")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("APIClient: Invalid response type")
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        print("APIClient: Image upload response status:", httpResponse.statusCode)
        if let responseString = String(data: data, encoding: .utf8) {
            print("APIClient: Upload response:", responseString)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let result = try decoder.decode(ImageUploadResponse.self, from: data)
            print("APIClient: Image uploaded successfully:", result.imageUrl)
            return result.imageUrl
        case 401:
            print("APIClient: Unauthorized upload attempt")
            throw APIError.unauthorized
        default:
            print("APIClient: Upload failed with status code:", httpResponse.statusCode)
            throw APIError.serverError("Upload failed: \(httpResponse.statusCode)")
        }
    }
    
    func uploadUserProfileImage(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw APIError.serverError("Could not process image")
        }
        
        // Use the existing image upload endpoint that connects to Cloudinary
        return try await uploadImage(imageData)
    }
    
    func updateUserProfileWithImage(name: String, profileImage: String) async throws -> UserResponse {
        let url = URL(string: "\(baseURL)/user/profile")!
        let body = [
            "name": name,
            "userImage": profileImage  // Changed from profileImage to userImage to match backend
        ]
        return try await put(url: url, body: body)
    }
    
    func updateExercise(exerciseId: String, exerciseData: [String: Any]) async throws -> Exercise {
        let url = URL(string: "\(baseURL)/exercise/\(exerciseId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = DataManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("APIClient: Updating exercise with data:", exerciseData)
        let jsonData = try JSONSerialization.data(withJSONObject: exerciseData)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let updatedExercise = try decoder.decode(Exercise.self, from: data)
            print("APIClient: Exercise updated successfully")
            return updatedExercise
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Response Types
struct LoginResponse: Codable {
    let token: String
    let user: UserResponse
}

struct UserResponse: Codable {
    let id: String
    let name: String
    let email: String
    let profileImage: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case profileImage = "userImage"  // Match the backend field name
    }
}

struct ValidationErrorResponse: Codable {
    let message: String
}

struct ErrorResponse: Codable {
    let message: String
}

struct ImageUploadResponse: Codable {
    let imageUrl: String
}

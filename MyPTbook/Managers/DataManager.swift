import Foundation
import UIKit
import SwiftUI

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    // Add user email tracking
    @Published private(set) var userEmail: String = ""
    
    // MARK: - Published Properties
    @Published var clients: [Client] = []
    @Published private(set) var userName: String {
        didSet {
            print("DataManager: userName updated to:", userName)
        }
    }
    @Published private(set) var clientNutrition: Nutrition?
    private var nutritionFetchTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - UserDefaults Keys
    private let defaults = UserDefaults.standard
    private let isLoggedInKey = "isLoggedIn"
    private let userNameKey = "userName"
    private let userEmailKey = "userEmail"  // Add email key
    private let authTokenKey = "authToken"
    private let userIdKey = "userId"
    
    // MARK: - File Management
    private let fileManager = FileManager.default
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    // Add userId property
    @Published private(set) var userId: String = ""
    
    private init() {
        // Initialize with stored value
        self.userName = defaults.string(forKey: userNameKey) ?? "Your Name"
        self.userEmail = defaults.string(forKey: userEmailKey) ?? ""
        print("DataManager: Initialized with user:", userName, "email:", userEmail)
    }
    
    // MARK: - Client CRUD Operations
    func fetchClients() async throws {
        print("DataManager: Fetching clients")
        let fetchedClients = try await APIClient.shared.fetchClients()
        print("DataManager: Fetched \(fetchedClients.count) clients")
        await MainActor.run {
            self.clients = fetchedClients
            print("DataManager: Updated clients in state")
        }
    }
    
    func addClient(_ client: Client) async throws -> Client {
        print("DataManager: Creating client:", client.name)
        guard let userId = getUserId() else {
            print("DataManager: No user ID found")
            throw APIError.unauthorized
        }
        
        // Create a client with the user ID
        let clientWithUser = Client(
            name: client.name,
            age: client.age,
            height: client.height,
            weight: client.weight,
            medicalHistory: client.medicalHistory,
            goals: client.goals,
            clientImage: client.clientImage,
            user: userId  // Add the user ID here
        )
        
        let savedClient = try await APIClient.shared.createClient(clientWithUser)
        await MainActor.run {
            clients.append(savedClient)
        }
        return savedClient
    }
    
    func updateClient(_ client: Client) async throws {
        print("DataManager: Updating client:", client._id)
        let updatedClient = try await APIClient.shared.updateClient(client)
        print("DataManager: Client updated successfully")
        
        await MainActor.run {
            if let index = self.clients.firstIndex(where: { $0._id == client._id }) {
                self.clients[index] = updatedClient
                print("DataManager: Updated client in local state")
            }
        }
    }
    
    func deleteClient(_ client: Client) async throws {
        print("DataManager: Deleting client:", client._id)
        try await APIClient.shared.deleteClient(id: client._id)
        print("DataManager: Client deleted successfully")
        
        await MainActor.run {
            self.clients.removeAll { $0._id == client._id }
            print("DataManager: Removed client from local state")
        }
    }
    
    // MARK: - Session Management
    func deleteSession(clientId: String, sessionId: String) async throws {
        try await APIClient.shared.deleteSession(clientId: clientId, sessionId: sessionId)
        await MainActor.run {
            if let clientIndex = self.clients.firstIndex(where: { $0._id == clientId }) {
                var updatedClient = self.clients[clientIndex]
                var sessions = updatedClient.sessions ?? []
                sessions.removeAll { $0._id == sessionId }
                updatedClient.sessions = sessions
                self.clients[clientIndex] = updatedClient
            }
        }
    }

    func createSession(for clientId: String, workoutName: String, isCompleted: Bool = false, completedDate: Date? = nil) async throws -> Session {
        let sessionData = [
            "workoutName": workoutName,
            "client": clientId,
            "completedDate": completedDate?.ISO8601Format() ?? "",
            "isCompleted": isCompleted,
            "exercises": []
        ] as [String: Any]
        
        print("DataManager: Creating session with data:", sessionData)
        
        let createdSession = try await APIClient.shared.createSession(clientId: clientId, sessionData: sessionData)
        print("DataManager: Session created successfully")
        
        await MainActor.run {
            if let index = clients.firstIndex(where: { $0._id == clientId }) {
                var updatedClient = clients[index]
                var sessions = updatedClient.sessions ?? []
                sessions.append(createdSession)
                updatedClient.sessions = sessions
                clients[index] = updatedClient
                print("DataManager: Updated client with new session")
            }
        }
        return createdSession
    }

    func updateSession(clientId: String, session: Session) async throws {
        print("DataManager: Updating session:", session._id)
        let updatedSession = try await APIClient.shared.updateSession(clientId: clientId, session: session)
        print("DataManager: Session updated successfully")
        
        await MainActor.run {
            if let clientIndex = clients.firstIndex(where: { $0._id == clientId }) {
                var updatedClient = clients[clientIndex]
                if var sessions = updatedClient.sessions {
                    if let sessionIndex = sessions.firstIndex(where: { $0._id == session._id }) {
                        sessions[sessionIndex] = updatedSession
                        updatedClient.sessions = sessions
                        clients[clientIndex] = updatedClient
                        print("DataManager: Updated client's session in local state")
                    }
                }
            }
        }
    }
    
    // Helper method to safely update client sessions
    private func updateClientSessions(clientId: String, update: ([Session]) -> [Session]) {
        if let index = clients.firstIndex(where: { $0._id == clientId }) {
            var updatedClient = clients[index]
            let currentSessions = updatedClient.sessions ?? []
            updatedClient.sessions = update(currentSessions)
            clients[index] = updatedClient
        }
    }
    
    // Error handling helper
    private func handleSessionError(_ error: Error) -> Error {
        switch error {
        case APIError.unauthorized:
            return APIError.unauthorized
        case APIError.networkError(let underlyingError):
            print("Session network error:", underlyingError)
            return APIError.networkError(underlyingError)
        case APIError.serverError(let message):
            print("Session server error:", message)
            return APIError.serverError("Session operation failed: \(message)")
        default:
            print("Unexpected session error:", error)
            return APIError.serverError("An unexpected error occurred")
        }
    }
    
    // MARK: - Exercise Operations
    func createExercise(exercise: Exercise) async throws -> Exercise {
        print("DataManager: Creating exercise:", exercise.exerciseName)
        let exerciseData = [
            "exerciseName": exercise.exerciseName,
            "sets": exercise.sets,
            "reps": exercise.reps,
            "weight": exercise.weight,
            "time": exercise.time as Any,
            "groupType": exercise.groupType?.rawValue as Any,
            "session": exercise.session
        ] as [String: Any]
        
        print("DataManager: Exercise data:", exerciseData)
        let createdExercise = try await APIClient.shared.createExercise(exerciseData: exerciseData)
        print("DataManager: Exercise created successfully:", createdExercise)
        
        // Update the local session with the new exercise
        await MainActor.run {
            if let clientIndex = clients.firstIndex(where: { client in
                client.sessions?.contains(where: { $0._id == exercise.session }) ?? false
            }) {
                var updatedClient = clients[clientIndex]
                if var sessions = updatedClient.sessions {
                    if let sessionIndex = sessions.firstIndex(where: { $0._id == exercise.session }) {
                        var updatedSession = sessions[sessionIndex]
                        updatedSession.exercises.append(createdExercise)
                        sessions[sessionIndex] = updatedSession
                        updatedClient.sessions = sessions
                        clients[clientIndex] = updatedClient
                    }
                }
            }
        }
        
        return createdExercise
    }
    
    func deleteExercise(_ exercise: Exercise) async throws {
        try await APIClient.shared.deleteExercise(exerciseId: exercise._id)
    }
    
    func getSessionExercises(sessionId: String) async throws -> [Exercise] {
        return try await APIClient.shared.fetchSessionExercises(sessionId: sessionId)
    }
    
    // MARK: - Auth Operations
    func handleLoginSuccess(response: LoginResponse) {
        print("DataManager: Handling login success")
        print("DataManager: User info - Name:", response.user.name, "Email:", response.user.email)
        saveAuthToken(response.token)
        saveUserName(response.user.name)
        saveUserEmail(response.user.email)
        saveUserId(response.user.id)
        setLoggedIn(true)
        print("DataManager: Login data saved successfully")
    }
    
    func logout() {
        print("DataManager: Logging out user - Email:", getUserEmail())
        clearAllData()
        NotificationCenter.default.post(name: NSNotification.Name("LogoutNotification"), object: nil)
        print("DataManager: User logged out successfully")
    }
    
    // MARK: - User Profile Operations
    func updateUserProfile(name: String) async throws {
        print("DataManager: Updating profile for user - Email:", getUserEmail())
        let response = try await APIClient.shared.updateUserProfile(name: name)
        await MainActor.run {
            saveUserName(response.name)
            print("DataManager: Profile updated successfully for user - Email:", getUserEmail())
        }
    }
    
    // MARK: - Helper Methods
    func setLoggedIn(_ value: Bool) {
        defaults.set(value, forKey: isLoggedInKey)
    }
    
    func isLoggedIn() -> Bool {
        defaults.bool(forKey: isLoggedInKey)
    }
    
    func saveAuthToken(_ token: String) {
        defaults.set(token, forKey: authTokenKey)
    }
    
    func getAuthToken() -> String? {
        return defaults.string(forKey: authTokenKey)
    }
    
    func removeAuthToken() {
        defaults.removeObject(forKey: authTokenKey)
        setLoggedIn(false)
    }
    
    func saveUserName(_ name: String) {
        print("DataManager: Saving user name:", name)
        defaults.set(name, forKey: userNameKey)
        // Update the published property on the main thread
        DispatchQueue.main.async {
            self.userName = name
            self.objectWillChange.send()
        }
    }
    
    func getUserName() -> String {
        let name = defaults.string(forKey: userNameKey) ?? "Your Name"
        print("DataManager: Retrieved user name:", name)
        return name
    }
    
    func clearAllData() {
        print("DataManager: Clearing all data")
        print("DataManager: Previous user info - Name:", userName, "Email:", userEmail)
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        clients = []
        userName = "Your Name"
        userEmail = ""
        clientNutrition = nil
        print("DataManager: All data cleared")
    }
    
    func updateClientInList(_ updatedClient: Client) {
        if let index = clients.firstIndex(where: { $0._id == updatedClient._id }) {
            clients[index] = updatedClient
        }
    }
    
    func getUserId() -> String? {
        let id = defaults.string(forKey: userIdKey)
        print("DataManager: Retrieved user ID:", id ?? "nil")
        return id
    }
    
    func saveUserId(_ id: String) {
        print("DataManager: Saving user ID:", id)
        defaults.set(id, forKey: userIdKey)
        userId = id
    }
    
    func uploadClientImage(_ image: UIImage, clientId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw APIError.serverError("Failed to convert image to data")
        }
        
        return try await APIClient.shared.uploadClientImage(clientId: clientId, imageData: imageData)
    }
    
    func fetchClientSessions(for client: Client) async throws {
        print("DataManager: Starting to fetch sessions for client:", client._id)
        let sessions = try await APIClient.shared.fetchClientSessions(clientId: client._id)
        print("DataManager: Successfully fetched \(sessions.count) sessions")
        
        await MainActor.run {
            if let index = clients.firstIndex(where: { $0._id == client._id }) {
                var updatedClient = clients[index]
                updatedClient.sessions = sessions
                clients[index] = updatedClient
                print("DataManager: Updated client with \(sessions.count) sessions")
                objectWillChange.send()  // Force UI update
            }
        }
    }
    
    func fetchNutrition(for client: Client) async throws {
        // Cancel any existing fetch task for this client
        nutritionFetchTasks[client._id]?.cancel()
        
        // Create new task
        let task = Task { @MainActor in
            do {
                print("DataManager: Fetching nutrition for client:", client._id)
                let nutrition = try await APIClient.shared.getNutritionForClient(clientId: client._id)
                if !Task.isCancelled {
                    self.clientNutrition = nutrition
                    print("DataManager: Successfully fetched nutrition plan")
                }
            } catch {
                print("Error fetching nutrition:", error)
                if !Task.isCancelled {
                    self.clientNutrition = nil
                }
            }
            nutritionFetchTasks[client._id] = nil
        }
        
        nutritionFetchTasks[client._id] = task
    }
    
    // Add cleanup method
    func cancelNutritionFetch(for clientId: String) {
        nutritionFetchTasks[clientId]?.cancel()
        nutritionFetchTasks[clientId] = nil
    }
    
    // Add email management functions
    func saveUserEmail(_ email: String) {
        print("DataManager: Saving user email:", email)
        defaults.set(email, forKey: userEmailKey)
        userEmail = email
    }
    
    func getUserEmail() -> String {
        let email = defaults.string(forKey: userEmailKey) ?? ""
        print("DataManager: Retrieved user email:", email)
        return email
    }
    
    // Add function to check current user status
    func getCurrentUserInfo() -> (name: String, email: String) {
        let name = getUserName()
        let email = getUserEmail()
        print("DataManager: Current user info - Name:", name, "Email:", email)
        return (name, email)
    }
}
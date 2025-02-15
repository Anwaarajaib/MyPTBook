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
    
    @Published private(set) var userProfileImageUrl: String? {
        didSet {
            print("DataManager: Profile image URL updated to:", userProfileImageUrl ?? "nil")
        }
    }
    
    // Add at the top with other properties
    private let cache = NSCache<NSString, AnyObject>()
    private let lastFetchTimeKey = "lastFetchTime_"
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    // Add to existing properties
    private let localStorage = LocalStorage.shared
    
    // Add new property at the top
    private let sessionCache: [String: [Session]] = [:]
    
    // Add new property
    private let tokenRefreshKey = "tokenLastRefresh"
    private let tokenRefreshInterval: TimeInterval = 30 * 24 * 3600 // 30 days
    
    private init() {
        // Initialize with stored values
        self.userName = defaults.string(forKey: userNameKey) ?? "Your Name"
        self.userEmail = defaults.string(forKey: userEmailKey) ?? ""
        self.userProfileImageUrl = defaults.string(forKey: "userProfileImageUrl")
        print("DataManager: Initialized with user:", userName, "email:", userEmail)
        print("DataManager: Initial profile image URL:", userProfileImageUrl ?? "none")
    }
    
    // MARK: - Client CRUD Operations
    func fetchClients() async throws {
        let cacheKey = "clients"
        
        // Check if token is expired
        if !isTokenValid() {
            // Try to refresh token or force logout
            print("DataManager: Token expired, logging out")
            await MainActor.run {
                logout()
            }
            throw APIError.unauthorized
        }
        
        // Check memory cache first
        if !shouldRefetch(forKey: cacheKey),
           let cachedClients: [Client] = getCachedData(forKey: cacheKey) {
            print("DataManager: Using memory cached clients")
            await MainActor.run {
                self.clients = cachedClients
            }
            return
        }
        
        // Check local storage next
        if let storedClients: [Client] = localStorage.load(forKey: cacheKey) {
            print("DataManager: Using locally stored clients")
            await MainActor.run {
                self.clients = storedClients
            }
        }
        
        // Fetch from API
        do {
            print("DataManager: Fetching clients from API")
            let fetchedClients = try await APIClient.shared.fetchClients()
            
            await MainActor.run {
                self.clients = fetchedClients
                self.cacheData(fetchedClients, forKey: cacheKey)
                self.localStorage.save(fetchedClients, forKey: cacheKey)
            }
        } catch {
            print("DataManager: Error fetching clients:", error)
            // If we have local data, don't throw the error
            if !self.clients.isEmpty {
                return
            }
            throw error
        }
    }
    
    func addClient(_ client: Client) async throws -> Client {
        print("DataManager: Creating client:", client.name)
        guard let userId = getUserId() else {
            print("DataManager: No user ID found")
            throw APIError.unauthorized
        }
        
        // Create a client with the user ID
        let clientWithUserId = Client(
            name: client.name,
            age: client.age,
            height: client.height,
            weight: client.weight,
            medicalHistory: client.medicalHistory,
            goals: client.goals,
            clientImage: client.clientImage,
            userId: userId  // Use userId to match the Client model
        )
        
        print("DataManager: Creating client with userId:", userId)
        let savedClient = try await APIClient.shared.createClient(clientWithUserId)
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
                
                // Update cache
                updateSessionCache(clientId: clientId, sessions: sessions)
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
        
        let createdSession = try await APIClient.shared.createSession(clientId: clientId, sessionData: sessionData)
        
        await MainActor.run {
            if let index = clients.firstIndex(where: { $0._id == clientId }) {
                var updatedClient = clients[index]
                var sessions = updatedClient.sessions ?? []
                sessions.append(createdSession)
                updatedClient.sessions = sessions
                clients[index] = updatedClient
                
                // Update cache
                updateSessionCache(clientId: clientId, sessions: sessions)
            }
        }
        return createdSession
    }

    func updateSession(clientId: String, session: Session) async throws {
        let updatedSession = try await APIClient.shared.updateSession(clientId: clientId, session: session)
        
        await MainActor.run {
            if let clientIndex = clients.firstIndex(where: { $0._id == clientId }) {
                var updatedClient = clients[clientIndex]
                if var sessions = updatedClient.sessions {
                    if let sessionIndex = sessions.firstIndex(where: { $0._id == session._id }) {
                        sessions[sessionIndex] = updatedSession
                        updatedClient.sessions = sessions
                        clients[clientIndex] = updatedClient
                        
                        // Update cache
                        updateSessionCache(clientId: clientId, sessions: sessions)
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
    func createExercise(exerciseData: [String: Any]) async throws -> Exercise {
        return try await APIClient.shared.createExercise(exerciseData: exerciseData)
    }
    
    func deleteExercise(exerciseId: String) async throws {
        print("DataManager: Deleting exercise:", exerciseId)
        try await APIClient.shared.deleteExercise(exerciseId: exerciseId)
        print("DataManager: Exercise deleted successfully")
    }
    
    func getSessionExercises(sessionId: String) async throws -> [Exercise] {
        return try await APIClient.shared.fetchSessionExercises(sessionId: sessionId)
    }
    
    // MARK: - Auth Operations
    func handleLoginSuccess(response: LoginResponse) {
        print("DataManager: Handling login success")
        print("DataManager: User info - Name:", response.user.name, "Email:", response.user.email)
        print("DataManager: Profile image URL from login:", response.user.profileImage ?? "none")
        
        saveAuthToken(response.token)
        saveUserName(response.user.name)
        saveUserEmail(response.user.email)
        saveUserId(response.user.id)
        
        // Save token refresh time
        defaults.set(Date(), forKey: tokenRefreshKey)
        
        if let profileImage = response.user.profileImage {
            print("DataManager: Saving profile image URL from login:", profileImage)
            saveProfileImageUrl(profileImage)
        } else {
            print("DataManager: No profile image URL in login response")
        }
        
        setLoggedIn(true)
        print("DataManager: Login data saved successfully")
    }
    
    func logout() {
        print("DataManager: Logging out user - Email:", getUserEmail())
        clearAllData()
        clearCache()
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
        print("DataManager: Previous profile image URL:", userProfileImageUrl ?? "none")
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        clients = []
        userName = "Your Name"
        userEmail = ""
        userProfileImageUrl = nil
        clientNutrition = nil
        defaults.removeObject(forKey: tokenRefreshKey)
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
        let cacheKey = "sessions_\(client._id)"
        
        // First check memory cache
        if !shouldRefetch(forKey: cacheKey),
           let cachedSessions: [Session] = getCachedData(forKey: cacheKey) {
            print("DataManager: Using memory cached sessions for client:", client._id)
            await MainActor.run {
                if let index = clients.firstIndex(where: { $0._id == client._id }) {
                    var updatedClient = clients[index]
                    updatedClient.sessions = cachedSessions
                    clients[index] = updatedClient
                }
            }
            return
        }
        
        // Then check local storage
        if let storedSessions: [Session] = localStorage.load(forKey: cacheKey) {
            print("DataManager: Using locally stored sessions for client:", client._id)
            await MainActor.run {
                if let index = clients.firstIndex(where: { $0._id == client._id }) {
                    var updatedClient = clients[index]
                    updatedClient.sessions = storedSessions
                    clients[index] = updatedClient
                }
            }
            // Only return if we're not due for a refresh
            if !shouldRefetch(forKey: cacheKey) {
                return
            }
        }
        
        // Fetch from API
        do {
            print("DataManager: Fetching sessions from API for client:", client._id)
            let sessions = try await APIClient.shared.fetchClientSessions(clientId: client._id)
            
            await MainActor.run {
                if let index = clients.firstIndex(where: { $0._id == client._id }) {
                    var updatedClient = clients[index]
                    updatedClient.sessions = sessions
                    clients[index] = updatedClient
                    self.cacheData(sessions, forKey: cacheKey)
                    self.localStorage.save(sessions, forKey: cacheKey)
                }
            }
        } catch {
            print("DataManager: Error fetching sessions:", error)
            // If we have cached data, don't throw the error
            if let index = clients.firstIndex(where: { $0._id == client._id }),
               clients[index].sessions != nil {
                return
            }
            throw error
        }
    }
    
    func fetchNutrition(for client: Client) async throws {
        let cacheKey = "nutrition_\(client._id)"
        
        if !shouldRefetch(forKey: cacheKey),
           let cachedNutrition: Nutrition = getCachedData(forKey: cacheKey) {
            print("DataManager: Using cached nutrition for client:", client._id)
            await MainActor.run {
                self.clientNutrition = cachedNutrition
            }
            return
        }
        
        // Cancel any existing fetch task for this client
        nutritionFetchTasks[client._id]?.cancel()
        
        let task = Task { @MainActor in
            do {
                print("DataManager: Fetching nutrition from API for client:", client._id)
                let nutrition = try await APIClient.shared.getNutritionForClient(clientId: client._id)
                if !Task.isCancelled {
                    self.clientNutrition = nutrition
                    self.cacheData(nutrition, forKey: cacheKey)
                }
            } catch {
                print("DataManager: Error fetching nutrition:", error)
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
    
    // Add these methods to DataManager
    func saveProfileImageUrl(_ url: String) {
        print("DataManager: Saving profile image URL:", url)
        defaults.set(url, forKey: "userProfileImageUrl")
        DispatchQueue.main.async {
            self.userProfileImageUrl = url
            self.objectWillChange.send()
            print("DataManager: Profile image URL updated in state")
        }
    }
    
    // Add this function to DataManager
    func updateExercise(exerciseId: String, exerciseData: [String: Any]) async throws -> Exercise {
        print("DataManager: Updating exercise:", exerciseId)
        return try await APIClient.shared.updateExercise(exerciseId: exerciseId, exerciseData: exerciseData)
    }
    
    // Add these new methods
    private func getCachedData<T: Codable>(forKey key: String) -> T? {
        if let cachedData = cache.object(forKey: key as NSString) as? Data {
            return try? JSONDecoder().decode(T.self, from: cachedData)
        }
        return nil
    }

    private func cacheData<T: Codable>(_ data: T, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(data) {
            cache.setObject(encoded as NSObject, forKey: key as NSString)
            defaults.set(Date(), forKey: lastFetchTimeKey + key)
        }
    }

    private func shouldRefetch(forKey key: String) -> Bool {
        guard let lastFetch = defaults.object(forKey: lastFetchTimeKey + key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastFetch) > cacheExpirationInterval
    }
    
    // Add method to clear cache
    func clearCache() {
        print("DataManager: Clearing cache")
        cache.removeAllObjects()
        _ = Bundle.main.bundleIdentifier!
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.filter { $0.hasPrefix(lastFetchTimeKey) }.forEach { key in
            defaults.removeObject(forKey: key)
        }
        
        // Clear local storage
        localStorage.clearAll()
    }

    // Add method to update session cache after modifications
    func updateSessionCache(clientId: String, sessions: [Session]) {
        let cacheKey = "sessions_\(clientId)"
        cacheData(sessions, forKey: cacheKey)
        localStorage.save(sessions, forKey: cacheKey)
    }
    
    // Add method to check token validity
    private func isTokenValid() -> Bool {
        // Always return true to prevent auto logout
        return true
    }
    
    // Add this method
    func refreshTokenIfNeeded() async throws {
        let lastRefresh = defaults.double(forKey: tokenRefreshKey)
        let now = Date().timeIntervalSince1970
        
        if now - lastRefresh >= tokenRefreshInterval {
            guard let _ = defaults.string(forKey: authTokenKey) else {
                throw APIError.unauthorized
            }
            
            // For now, just update the refresh time
            print("DataManager: Refreshing token")
            defaults.set(now, forKey: tokenRefreshKey)
            
            // TODO: In future, add actual token refresh API call:
            // let newToken = try await APIClient.shared.refreshToken(token)
            // defaults.set(newToken, forKey: authTokenKey)
        }
    }
}

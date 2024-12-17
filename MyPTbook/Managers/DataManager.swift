import Foundation
import UIKit
import SwiftUI

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    // Keys for UserDefaults
    private let isLoggedInKey = "isLoggedIn"
    private let userNameKey = "userName"
    private let userImageKey = "userImage"
    private let authTokenKey = "authToken"
    
    // Add a published property for clients
    @Published var clients: [Client] = []
    @Published var userName: String = "Your Name"
    
    private init() {
        // No need for local storage initialization anymore
    }
    
    // MARK: - Login State
    func setLoggedIn(_ value: Bool) {
        defaults.set(value, forKey: isLoggedInKey)
    }
    
    func isLoggedIn() -> Bool {
        defaults.bool(forKey: isLoggedInKey)
    }
    
    // MARK: - Auth Token
    func saveAuthToken(_ token: String) {
        defaults.set(token, forKey: authTokenKey)
        setLoggedIn(true)
    }
    
    func getAuthToken() -> String? {
        return defaults.string(forKey: authTokenKey)
    }
    
    func removeAuthToken() {
        defaults.removeObject(forKey: authTokenKey)
        setLoggedIn(false)
    }
    
    // MARK: - Trainer Data
    func saveUserName(_ name: String) {
        defaults.set(name, forKey: userNameKey)
    }
    
    func getUserName() -> String {
        defaults.string(forKey: userNameKey) ?? "Your Name"
    }
    
    func saveUserImage(_ image: UIImage?) {
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            let imageUrl = documentsPath.appendingPathComponent("user_profile.jpg")
            try? imageData.write(to: imageUrl)
            defaults.set(true, forKey: userImageKey)
        } else {
            defaults.set(false, forKey: userImageKey)
            let imageUrl = documentsPath.appendingPathComponent("user_profile.jpg")
            try? fileManager.removeItem(at: imageUrl)
        }
    }
    
    func getUserImage() -> UIImage? {
        if defaults.bool(forKey: userImageKey) {
            let imageUrl = documentsPath.appendingPathComponent("user_profile.jpg")
            return UIImage(contentsOfFile: imageUrl.path)
        }
        return nil
    }
    
    // MARK: - Clients Data
    func fetchClients() async throws -> [Client] {
        let fetchedClients = try await APIClient.shared.fetchClients()
        await MainActor.run {
            self.clients = fetchedClients
        }
        return fetchedClients
    }
    
    func addClient(_ client: Client) async throws -> Client {
        let createdClient = try await APIClient.shared.createClient(client)
        await MainActor.run {
            self.clients.append(createdClient)
        }
        return createdClient
    }
    
    func updateClient(_ client: Client) async throws {
        let updatedClient = try await APIClient.shared.updateClient(client)
        await MainActor.run {
            if let index = self.clients.firstIndex(where: { $0.id == client.id }) {
                self.clients[index] = updatedClient
            }
        }
    }
    
    func deleteClient(_ client: Client) async throws {
        try await APIClient.shared.deleteClient(id: client.id)
        await MainActor.run {
            self.clients.removeAll { $0.id == client.id }
        }
    }
    
    // MARK: - Sessions Data
    func saveClientSessions(clientId: UUID, sessions: [Session]) async throws {
        let createdSessions = try await APIClient.shared.createSessions(clientId: clientId, sessions: sessions)
        await MainActor.run {
            if let index = self.clients.firstIndex(where: { $0.id == clientId }) {
                self.clients[index].sessions = createdSessions
            }
        }
    }
    
    func getClientSessions(clientId: UUID) async throws -> [Session] {
        let sessions = try await APIClient.shared.fetchClientSessions(clientId: clientId)
        return sessions
    }
    
    func updateClientSession(clientId: UUID, session: Session) async throws {
        let updatedSession = try await APIClient.shared.updateSession(clientId: clientId, session: session)
        await MainActor.run {
            if let clientIndex = self.clients.firstIndex(where: { $0.id == clientId }),
               let sessionIndex = self.clients[clientIndex].sessions.firstIndex(where: { $0.id == session.id }) {
                self.clients[clientIndex].sessions[sessionIndex] = updatedSession
            }
        }
    }
    
    func deleteClientSession(clientId: UUID, sessionId: UUID) async throws {
        try await APIClient.shared.deleteSession(clientId: clientId, sessionId: sessionId)
        await MainActor.run {
            if let clientIndex = self.clients.firstIndex(where: { $0.id == clientId }) {
                self.clients[clientIndex].sessions.removeAll { $0.id == sessionId }
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshClientData"),
                    object: nil,
                    userInfo: ["clientId": clientId]
                )
            }
        }
    }
    
    func deleteClientSessions(clientId: UUID, sessionNumbers: [Int]) async throws {
        // You'll need to implement this in your backend or make multiple delete calls
        for sessionNumber in sessionNumbers {
            if let session = clients.first(where: { $0.id == clientId })?
                .sessions.first(where: { $0.sessionNumber == sessionNumber }) {
                try await deleteClientSession(clientId: clientId, sessionId: session.id)
            }
        }
    }
    
    func clearAllData() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        
        // Remove user profile image
        let userImage = documentsPath.appendingPathComponent("user_profile.jpg")
        try? fileManager.removeItem(at: userImage)
        
        // Clear clients array
        clients = []
    }
    
    func clearAuthToken() {
        removeAuthToken()
    }
    
    // Add these methods to DataManager
    func saveClientImage(_ image: UIImage?, clientId: UUID) {
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            let imageUrl = documentsPath.appendingPathComponent("client_\(clientId.uuidString).jpg")
            try? imageData.write(to: imageUrl)
        } else {
            let imageUrl = documentsPath.appendingPathComponent("client_\(clientId.uuidString).jpg")
            try? fileManager.removeItem(at: imageUrl)
        }
    }
    
    func getClientImage(clientId: UUID) -> UIImage? {
        let imageUrl = documentsPath.appendingPathComponent("client_\(clientId.uuidString).jpg")
        return UIImage(contentsOfFile: imageUrl.path)
    }
    
    func deleteClientImage(clientId: UUID) {
        let imageUrl = documentsPath.appendingPathComponent("client_\(clientId.uuidString).jpg")
        try? fileManager.removeItem(at: imageUrl)
    }
    
    // MARK: - Auth and Trainer Data
    func handleLoginSuccess(response: LoginResponse) {
        saveAuthToken(response.token)
        saveUserName(response.user.name)
        setLoggedIn(true)
    }
    
    func logout() {
        clearAllData()
        NotificationCenter.default.post(name: NSNotification.Name("LogoutNotification"), object: nil)
    }
    
    // MARK: - Trainer Profile Methods
    func updateUserProfile(name: String, image: UIImage?) async throws {
        let response = try await APIClient.shared.updateUserProfile(name: name)
        
        await MainActor.run {
            saveUserName(response.name)
            saveUserImage(image)
        }
    }
}
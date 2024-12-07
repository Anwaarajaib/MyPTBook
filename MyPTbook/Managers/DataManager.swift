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
    private let trainerNameKey = "trainerName"
    private let trainerImageKey = "trainerImage"
    private let authTokenKey = "authToken"
    
    // Add a published property for clients
    @Published var clients: [Client] = []
    
    private init() {
        createDirectoryIfNeeded()
        loadClients()
    }
    
    private func createDirectoryIfNeeded() {
        let clientsDirectory = documentsPath.appendingPathComponent("clients")
        if !fileManager.fileExists(atPath: clientsDirectory.path) {
            try? fileManager.createDirectory(at: clientsDirectory, withIntermediateDirectories: true)
        }
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
    func saveTrainerName(_ name: String) {
        defaults.set(name, forKey: trainerNameKey)
    }
    
    func getTrainerName() -> String {
        defaults.string(forKey: trainerNameKey) ?? "Your Name"
    }
    
    func saveTrainerImage(_ image: UIImage?) {
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            let imageUrl = documentsPath.appendingPathComponent("trainer_profile.jpg")
            try? imageData.write(to: imageUrl)
            defaults.set(true, forKey: trainerImageKey)
        } else {
            defaults.set(false, forKey: trainerImageKey)
            let imageUrl = documentsPath.appendingPathComponent("trainer_profile.jpg")
            try? fileManager.removeItem(at: imageUrl)
        }
    }
    
    func getTrainerImage() -> UIImage? {
        if defaults.bool(forKey: trainerImageKey) {
            let imageUrl = documentsPath.appendingPathComponent("trainer_profile.jpg")
            return UIImage(contentsOfFile: imageUrl.path)
        }
        return nil
    }
    
    // MARK: - Clients Data
    func saveClients(_ clients: [Client]) {
        self.clients = clients
        let clientsDirectory = documentsPath.appendingPathComponent("clients")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: clientsDirectory, withIntermediateDirectories: true)
        
        // Clear existing files
        if let files = try? fileManager.contentsOfDirectory(at: clientsDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        
        // Save new client data
        for client in clients {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(client)
                let file = clientsDirectory.appendingPathComponent("\(client.id.uuidString).json")
                try data.write(to: file)
                
                // Save profile image if exists
                if let image = client.profileImage,
                   let imageData = image.jpegData(compressionQuality: 0.8) {
                    let imageFile = clientsDirectory.appendingPathComponent("\(client.id.uuidString).jpg")
                    try imageData.write(to: imageFile)
                }
            } catch {
                print("Error saving client \(client.id): \(error)")
            }
        }
    }
    
    func getClients() -> [Client] {
        let clientsDirectory = documentsPath.appendingPathComponent("clients")
        var clients: [Client] = []
        
        guard let files = try? fileManager.contentsOfDirectory(at: clientsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        // Load each client from their JSON file
        for file in files where file.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: file)
                let decoder = JSONDecoder()
                var client = try decoder.decode(Client.self, from: data)
                
                // Load profile image if it exists
                let imageFile = file.deletingPathExtension().appendingPathExtension("jpg")
                if fileManager.fileExists(atPath: imageFile.path) {
                    client.profileImage = UIImage(contentsOfFile: imageFile.path)
                }
                
                clients.append(client)
            } catch {
                print("Error loading client from \(file): \(error)")
            }
        }
        
        self.clients = clients.sorted { $0.name < $1.name }
        return self.clients
    }
    
    func clearAllData() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        
        // Remove all files in documents directory
        let clientsDirectory = documentsPath.appendingPathComponent("clients")
        try? fileManager.removeItem(at: clientsDirectory)
        let trainerImage = documentsPath.appendingPathComponent("trainer_profile.jpg")
        try? fileManager.removeItem(at: trainerImage)
        
        // Recreate clients directory
        createDirectoryIfNeeded()
    }
    
    func fetchClients() async throws -> [Client] {
        // For now, return the locally stored clients
        // Later you can implement API fetching here
        return getClients()
    }
    
    func addClient(_ client: Client) {
        clients.append(client)
        saveClients(clients)
    }
    
    // Load clients from local storage
    private func loadClients() {
        let clientsDirectory = documentsPath.appendingPathComponent("clients")
        
        guard let files = try? fileManager.contentsOfDirectory(at: clientsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files where file.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: file)
                let decoder = JSONDecoder()
                var client = try decoder.decode(Client.self, from: data)
                
                // Load profile image if it exists
                let imageFile = file.deletingPathExtension().appendingPathExtension("jpg")
                if fileManager.fileExists(atPath: imageFile.path) {
                    client.profileImage = UIImage(contentsOfFile: imageFile.path)
                }
                
                clients.append(client)
            } catch {
                print("Error loading client from \(file): \(error)")
            }
        }
    }
    
    // Save clients to local storage
    func saveClients() {
        let clientsDirectory = documentsPath.appendingPathComponent("clients")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: clientsDirectory, withIntermediateDirectories: true)
        
        // Clear existing files
        if let files = try? fileManager.contentsOfDirectory(at: clientsDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        
        // Save new client data
        for client in clients {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(client)
                let file = clientsDirectory.appendingPathComponent("\(client.id.uuidString).json")
                try data.write(to: file)
                
                // Save profile image if exists
                if let image = client.profileImage,
                   let imageData = image.jpegData(compressionQuality: 0.8) {
                    let imageFile = clientsDirectory.appendingPathComponent("\(client.id.uuidString).jpg")
                    try imageData.write(to: imageFile)
                }
            } catch {
                print("Error saving client \(client.id): \(error)")
            }
        }
    }
}
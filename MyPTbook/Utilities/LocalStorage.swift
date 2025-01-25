import Foundation

class LocalStorage {
    static let shared = LocalStorage()
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private init() {}
    
    func save<T: Encodable>(_ data: T, forKey key: String) {
        let url = documentsDirectory.appendingPathComponent("\(key).json")
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(data)
            try data.write(to: url)
            print("LocalStorage: Saved data for key:", key)
        } catch {
            print("LocalStorage: Error saving data:", error)
        }
    }
    
    func load<T: Decodable>(forKey key: String) -> T? {
        let url = documentsDirectory.appendingPathComponent("\(key).json")
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(T.self, from: data)
            print("LocalStorage: Loaded data for key:", key)
            return decoded
        } catch {
            print("LocalStorage: Error loading data:", error)
            return nil
        }
    }
    
    func clearAll() {
        let urls = try? fileManager.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: nil
        )
        urls?.forEach { url in
            try? fileManager.removeItem(at: url)
        }
        print("LocalStorage: Cleared all stored data")
    }
} 
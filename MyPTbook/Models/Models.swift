import Foundation

// This enum provides namespacing for our model types
enum Models {
    // These types are now unambiguous because they're in separate files
    typealias Client = MyPTbook.Client
    typealias Session = MyPTbook.Session
    typealias Exercise = MyPTbook.Exercise
    typealias Trainer = MyPTbook.Trainer
}

struct Nutrition: Codable, Identifiable {
    let _id: String
    let client: String
    var meals: [Meal]
    
    var id: String { _id }
    
    private enum CodingKeys: String, CodingKey {
        case _id, client, meals
    }
    
    struct Meal: Codable, Identifiable {
        let mealName: String
        var items: [MealItem]
        
        var id: String { mealName }
        
        private enum CodingKeys: String, CodingKey {
            case mealName, items
        }
        
        init(mealName: String, items: [MealItem] = []) {
            self.mealName = mealName
            self.items = items
        }
    }
    
    struct MealItem: Codable, Identifiable {
        let name: String
        let quantity: String
        
        var id: String { name }
        
        private enum CodingKeys: String, CodingKey {
            case name, quantity
        }
        
        init(name: String, quantity: String) {
            self.name = name
            self.quantity = quantity
        }
    }
}

// Note: UserResponse is now defined in APIClient.swift
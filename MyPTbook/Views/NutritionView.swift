import SwiftUI

struct NutritionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NutritionViewModel()
    let client: Client
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Meal sections
                    ForEach(viewModel.meals) { meal in
                        MealSection(meal: meal, viewModel: viewModel)
                    }
                    
                    // Add meal button
                    Button(action: { viewModel.showingAddMeal = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Meal")
                        }
                        .font(.headline)
                        .foregroundColor(Colors.nasmBlue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Colors.nasmBlue.opacity(0.3), lineWidth: 2)
                                .background(Color.white)
                        )
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Colors.background)
            .navigationTitle("Nutrition Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveNutrition()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddItem) {
            AddMealItemView(viewModel: viewModel)
        }
        .alert("Add Meal", isPresented: $viewModel.showingAddMeal) {
            TextField("Meal Name", text: $viewModel.newMealName)
            Button("Cancel", role: .cancel) { }
            Button("Add") { viewModel.addMeal() }
        }
        .task {
            await viewModel.loadNutrition(for: client)
        }
    }
}

struct MealSection: View {
    let meal: Nutrition.Meal
    @ObservedObject var viewModel: NutritionViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Meal header
            HStack {
                Label(meal.mealName, systemImage: getMealIcon(meal.mealName))
                    .font(.headline)
                Spacer()
                Button(action: { 
                    viewModel.selectedMeal = meal
                    viewModel.showingAddItem = true 
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Colors.nasmBlue)
                }
            }
            
            // Meal items
            if meal.items.isEmpty {
                Text("No items added")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                ForEach(meal.items) { item in
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        Text(item.quantity)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func getMealIcon(_ mealName: String) -> String {
        switch mealName.lowercased() {
        case "breakfast": return "sun.rise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snacks": return "leaf.fill"
        default: return "fork.knife"
        }
    }
}

struct AddMealItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: NutritionViewModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item Name", text: $viewModel.newItemName)
                    TextField("Quantity (e.g., 100g, 1 cup)", text: $viewModel.newItemQuantity)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        viewModel.addItem()
                        dismiss()
                    }
                    .bold()
                    .disabled(viewModel.newItemName.isEmpty || viewModel.newItemQuantity.isEmpty)
                }
            }
        }
    }
}

class NutritionViewModel: ObservableObject {
    @Published var meals: [Nutrition.Meal] = []
    @Published var showingAddMeal = false
    @Published var showingAddItem = false
    @Published var newMealName = ""
    @Published var newItemName = ""
    @Published var newItemQuantity = ""
    @Published var selectedMeal: Nutrition.Meal?
    @Published var error: String?
    @Published var isLoading = false
    
    private var nutritionId: String?
    private var clientId: String = ""
    private var loadTask: Task<Void, Never>?
    
    func loadNutrition(for client: Client) {
        // Cancel any existing load task
        loadTask?.cancel()
        
        loadTask = Task { @MainActor in
            isLoading = true
            clientId = client._id
            do {
                let nutrition = try await APIClient.shared.getNutritionForClient(clientId: client._id)
                if !Task.isCancelled {
                    self.meals = nutrition.meals
                    self.nutritionId = nutrition._id
                }
            } catch {
                print("Error loading nutrition:", error)
                if !Task.isCancelled {
                    self.meals = []
                    self.error = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
    
    deinit {
        loadTask?.cancel()
    }
    
    @MainActor
    func addMeal() {
        guard !newMealName.isEmpty else { return }
        let newMeal = Nutrition.Meal(mealName: newMealName)
        meals.append(newMeal)
        newMealName = ""
        Task {
            await saveNutrition()
        }
    }
    
    @MainActor
    func addItem() {
        guard let selectedMeal = selectedMeal,
              let index = meals.firstIndex(where: { $0.mealName == selectedMeal.mealName }),
              !newItemName.isEmpty,
              !newItemQuantity.isEmpty else { return }
        
        let newItem = Nutrition.MealItem(name: newItemName, quantity: newItemQuantity)
        meals[index].items.append(newItem)
        newItemName = ""
        newItemQuantity = ""
        Task {
            await saveNutrition()
        }
    }
    
    @MainActor
    func deleteMealItem(from meal: Nutrition.Meal, at indices: IndexSet) {
        guard let mealIndex = meals.firstIndex(where: { $0.mealName == meal.mealName }) else { return }
        meals[mealIndex].items.remove(atOffsets: indices)
        Task {
            await saveNutrition()
        }
    }
    
    func saveNutrition() async {
        do {
            let updatedMeals = meals // Capture current state
            if let nutritionId = nutritionId {
                let updatedNutrition = try await APIClient.shared.updateNutrition(
                    nutritionId: nutritionId,
                    meals: updatedMeals
                )
                await MainActor.run {
                    self.meals = updatedNutrition.meals
                }
            } else {
                let newNutrition = try await APIClient.shared.createNutrition(
                    clientId: clientId,
                    meals: updatedMeals
                )
                await MainActor.run {
                    self.meals = newNutrition.meals
                    self.nutritionId = newNutrition._id
                }
            }
        } catch {
            print("Error saving nutrition:", error)
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
} 
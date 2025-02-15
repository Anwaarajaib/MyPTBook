import SwiftUI

// Add this extension to make Nutrition.Meal conform to Equatable
extension Nutrition.Meal: Equatable {
    static func == (lhs: Nutrition.Meal, rhs: Nutrition.Meal) -> Bool {
        return lhs.mealName == rhs.mealName && lhs.items == rhs.items
    }
}

// Also need to make Nutrition.MealItem conform to Equatable
extension Nutrition.MealItem: Equatable {
    static func == (lhs: Nutrition.MealItem, rhs: Nutrition.MealItem) -> Bool {
        return lhs.name == rhs.name && lhs.quantity == rhs.quantity
    }
}

struct NutritionView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = NutritionViewModel()
    let client: Client
    @State private var keyboardHeight: CGFloat = 0
    @State private var isEditing = false
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        ZStack {
            // Add a background color with tap gesture
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        // Left side with icon and title
                        HStack(spacing: 12) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    .linearGradient(
                                        colors: [Colors.nasmBlue, Colors.nasmBlue.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Nutrition Plan")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Show Save button when there are unsaved changes
                        if viewModel.hasUnsavedChanges {
                            Button("Save") {
                                Task {
                                    await viewModel.saveNutrition()
                                }
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Colors.nasmBlue)
                        } else if !viewModel.meals.isEmpty {
                            // Show Edit button only for existing plans
                            Button(isEditing ? "Save" : "Edit") {
                                if isEditing {
                                    Task {
                                        await viewModel.saveNutrition()
                                        isEditing = false
                                    }
                                } else {
                                    isEditing = true
                                }
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Colors.nasmBlue)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            if viewModel.meals.isEmpty {
                                // Show add meal section by default when empty
                                AddNewMealDirectView(viewModel: viewModel)
                                    .padding(.vertical, 16)
                            } else {
                                // Meal sections
                                ForEach(viewModel.meals) { meal in
                                    MealSection(
                                        meal: meal, 
                                        viewModel: viewModel, 
                                        isEditing: isEditing || viewModel.meals.count == 1,
                                        showAddItem: viewModel.shouldShowAddItem(for: meal)
                                    )
                                }
                                
                                // Show new meal option after adding items or when editing
                                if viewModel.showNewMealAfterItem || isEditing {
                                    AddNewMealDirectView(viewModel: viewModel)
                                        .padding(.vertical, 16)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                // Share button overlay
                if !viewModel.meals.isEmpty {
                    Button(action: sharePDF) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Colors.nasmBlue)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .shadow(
                                        color: Color.black.opacity(0.1),
                                        radius: 8,
                                        x: 0,
                                        y: 4
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Colors.nasmBlue.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 48, 392))
            .frame(height: keyboardHeight > 0 ? 500 : 700, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Colors.background)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.none, value: keyboardHeight)
        .contentShape(Rectangle())
        .task {
            do {
                try await viewModel.loadNutrition(for: client)
            } catch {
                print("Error loading nutrition:", error)
            }
        }
        .onAppear {
            setupKeyboardNotifications()
        }
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    // Add PDF sharing function
    private func sharePDF() {
        // Create a Nutrition object from the current meals
        let nutrition = Nutrition(
            _id: viewModel.nutritionId ?? "",
            client: client._id,
            meals: viewModel.meals
        )
        
        if let pdfData = PDFGenerator.generateNutritionPDF(
            clientName: client.name,
            nutrition: nutrition
        ) {
            // Create a sanitized filename by removing/replacing invalid characters
            let sanitizedName = client.name
                .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ")).inverted)
                .joined()
                .replacingOccurrences(of: " ", with: "_")
            
            let fileName = "MyPTbook_\(sanitizedName)_NutritionPlan.pdf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try pdfData.write(to: tempURL)
                let activityVC = UIActivityViewController(
                    activityItems: [tempURL],
                    applicationActivities: nil
                )
                
                // Get the root view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    // For iPad
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = rootVC.view
                        popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2,
                                                  y: UIScreen.main.bounds.height / 2,
                                                  width: 0,
                                                  height: 0)
                        popover.permittedArrowDirections = []
                    }
                    rootVC.present(activityVC, animated: true)
                }
            } catch {
                print("Error saving PDF: \(error)")
            }
        }
    }
}

struct MealSection: View {
    let meal: Nutrition.Meal
    @ObservedObject var viewModel: NutritionViewModel
    let isEditing: Bool
    let showAddItem: Bool
    @State private var hideAddItem = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Meal header with divider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label {
                        Text(meal.mealName)
                            .font(.headline)
                            .foregroundColor(Colors.nasmBlue)
                    } icon: {
                        Image(systemName: getMealIcon(meal.mealName))
                            .font(.system(size: 20))
                            .foregroundColor(Colors.nasmBlue)
                    }
                    
                    Spacer()
                    
                    // Only show +/- buttons in edit mode
                    if isEditing {
                        if !hideAddItem {
                            Button(action: { hideAddItem = true }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Colors.nasmBlue)
                            }
                        } else {
                            Button(action: { hideAddItem = false }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Colors.nasmBlue)
                            }
                        }
                    }
                }
                
                Rectangle()
                    .fill(Colors.nasmBlue.opacity(0.2))
                    .frame(height: 1)
            }
            
            // Meal items
            if !meal.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(meal.items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            // Bullet point
                            Circle()
                                .fill(Colors.nasmBlue.opacity(0.3))
                                .frame(width: 4, height: 4)
                                .padding(.top, 8)
                            
                            Text(item.name)
                                .font(.body)
                            
                            Spacer()
                            
                            if !item.quantity.isEmpty {
                                Text(item.quantity)
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            
            // Show add item section only in edit mode or for newly added meals
            if (isEditing || meal.mealName == viewModel.lastAddedMeal?.mealName) && !hideAddItem {
                AddMealItemDirectView(viewModel: viewModel, meal: meal)
            }
        }
        .padding(.vertical, 12)
    }
    
    private func getMealIcon(_ mealName: String) -> String {
        switch mealName.lowercased() {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snacks": return "leaf.fill"
        case "pre workout": return "figure.run"
        case "post workout": return "figure.cooldown"
        case "supplements": return "pills.fill"
        default: return "fork.knife.circle.fill"
        }
    }
}

struct AddMealItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: NutritionViewModel
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                // Left side with icon and title
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [Colors.nasmBlue, Colors.nasmBlue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Add Item")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button("Save") {
                    viewModel.addItem()
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Colors.nasmBlue)
                .disabled(viewModel.newItemName.isEmpty || viewModel.newItemQuantity.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            VStack(spacing: 16) {
                // Item Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item Name")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    TextField("Enter item name", text: $viewModel.newItemName)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                // Quantity Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quantity")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    TextField("e.g., 100g, 1 cup", text: $viewModel.newItemQuantity)
                        .textFieldStyle(CustomTextFieldStyle())
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width - 48, 392))
        .frame(height: 300)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Colors.background)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
    }
}

// Custom TextField Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
    }
}

// Add this new view for adding meals and items directly in the UI
struct AddMealItemDirectView: View {
    @ObservedObject var viewModel: NutritionViewModel
    let meal: Nutrition.Meal
    @State private var newItemName = ""
    @State private var newItemQuantity = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Item name field
            TextField("Item Name", text: $newItemName)
                .textFieldStyle(CustomTextFieldStyle())
                .frame(maxWidth: .infinity)
            
            // Quantity field
            TextField("Quantity", text: $newItemQuantity)
                .textFieldStyle(CustomTextFieldStyle())
                .frame(width: 100)
            
            // Add button with proper styling
            Button(action: {
                addItem()
                // Clear fields after adding
                newItemName = ""
                newItemQuantity = ""
                // Show new meal option after adding item
                viewModel.showNewMealAfterItem = true
            }) {
                Text("Add")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(newItemName.isEmpty || newItemQuantity.isEmpty ? 
                                Colors.nasmBlue.opacity(0.5) : Colors.nasmBlue)
                    )
            }
            .disabled(newItemName.isEmpty || newItemQuantity.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func addItem() {
        viewModel.addItemDirect(to: meal, name: newItemName, quantity: newItemQuantity)
    }
}

struct AddNewMealDirectView: View {
    @ObservedObject var viewModel: NutritionViewModel
    @State private var newMealName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon and text field
            HStack {
                Label {
                    TextField("Breakfast, Lunch, Meal 1,2, etc", text: $newMealName)
                        .textFieldStyle(.plain)
                        .font(.headline)
                } icon: {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18))
                        .foregroundColor(Colors.nasmBlue)
                }
                
                Spacer()
                
                Button(action: addMeal) {
                    Text("Add Meal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Colors.nasmBlue)
                }
                .disabled(newMealName.isEmpty)
            }
            
            // Divider line matching meal sections
            Rectangle()
                .fill(Colors.nasmBlue.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.vertical, 12)
    }
    
    private func addMeal() {
        viewModel.addMealDirect(name: newMealName)
        newMealName = ""
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
    @Published var lastAddedMeal: Nutrition.Meal?
    @Published var showNewMealAfterItem = false
    @Published var hasUnsavedChanges = false
    
    var nutritionId: String?
    private var clientId: String = ""
    private var loadTask: Task<Void, Never>?
    
    func loadNutrition(for client: Client) async throws {
        loadTask?.cancel()
        
        await MainActor.run {
            isLoading = true
        }
        
        clientId = client._id
        do {
            let nutrition = try await APIClient.shared.getNutritionForClient(clientId: client._id)
            if !Task.isCancelled {
                await MainActor.run {
                    self.meals = nutrition.meals
                    self.nutritionId = nutrition._id
                    self.isLoading = false
                }
            }
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.meals = []
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
            throw error
        }
    }
    
    @MainActor
    func saveNutrition() async {
        print("Starting to save nutrition plan")
        do {
            let updatedMeals = meals
            print("Meals to save:", updatedMeals)
            
            // Check if nutritionId is valid (not empty string)
            if let nutritionId = nutritionId, !nutritionId.isEmpty {
                print("Updating existing nutrition plan with ID:", nutritionId)
                let updatedNutrition = try await APIClient.shared.updateNutrition(
                    nutritionId: nutritionId,
                    meals: updatedMeals
                )
                self.meals = updatedNutrition.meals
                print("Successfully updated nutrition plan")
            } else {
                print("Creating new nutrition plan for client:", clientId)
                let newNutrition = try await APIClient.shared.createNutrition(
                    clientId: clientId,
                    meals: updatedMeals
                )
                self.meals = newNutrition.meals
                self.nutritionId = newNutrition._id
                print("Successfully created new nutrition plan with ID:", newNutrition._id)
            }
            hasUnsavedChanges = false
            
            // Notify that nutrition data has changed
            NotificationCenter.default.post(
                name: NSNotification.Name("RefreshClientData"),
                object: nil,
                userInfo: ["clientId": clientId]
            )
        } catch {
            print("Error saving nutrition plan:", error)
            self.error = error.localizedDescription
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
    
    @MainActor
    func addMealDirect(name: String) {
        guard !name.isEmpty else { return }
        let newMeal = Nutrition.Meal(mealName: name)
        meals.append(newMeal)
        lastAddedMeal = newMeal
        hasUnsavedChanges = true  // Mark as having unsaved changes
    }
    
    @MainActor
    func addItemDirect(to meal: Nutrition.Meal, name: String, quantity: String) {
        guard let index = meals.firstIndex(where: { $0.mealName == meal.mealName }),
              !name.isEmpty,
              !quantity.isEmpty else { return }
        
        let newItem = Nutrition.MealItem(name: name, quantity: quantity)
        meals[index].items.append(newItem)
        showNewMealAfterItem = true
        hasUnsavedChanges = true  // Mark as having unsaved changes
    }
    
    func shouldShowAddItem(for meal: Nutrition.Meal) -> Bool {
        // Show add item if this is the last added meal and it has no items
        return meal.items.isEmpty && meal.mealName == lastAddedMeal?.mealName
    }
} 
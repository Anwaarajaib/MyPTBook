import SwiftUI
import Foundation
import UIKit

struct ClientDetailView: View {
    @ObservedObject var dataManager: DataManager
    let client: Client
    @State private var showingAddSession = false
    @State private var isEditing = false
    @State private var isLoadingSessions = false
    
    // Edit mode states
    @State private var editedName: String = ""
    @State private var editedAge: String = ""
    @State private var editedHeight: String = ""
    @State private var editedWeight: String = ""
    @State private var editedMedicalHistory: String = ""
    @State private var editedGoals: String = ""
    @State private var editedClientImage: String = ""
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    
    // Constants
    private let cardPadding: CGFloat = 24
    private let contentSpacing: CGFloat = 20
    private let cornerRadius: CGFloat = 16
    private let shadowRadius: CGFloat = 10
    private let minimumTapTarget: CGFloat = 44
    
    // State variables
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingNutritionNote = false
    @State private var error: String?
    @State private var showingError = false
    @State private var showingNutritionView = false
    @State private var selectedImage: UIImage?
    
    init(dataManager: DataManager, client: Client) {
        self.dataManager = dataManager
        self.client = client
        
        // Single notification observer for session updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshClientData"),
            object: nil,
            queue: .main
        ) { [weak dataManager] notification in
            if let clientId = notification.userInfo?["clientId"] as? String,
               clientId == client._id {
                Task { @MainActor in
                    do {
                        guard let dataManager = dataManager else { return }
                        try await dataManager.fetchClientSessions(for: client)
                        try await dataManager.fetchNutrition(for: client)
                    } catch {
                        print("Error refreshing client data:", error)
                    }
                }
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: contentSpacing) {
                TopSpacerView()
                clientDetailsCard
                
                // Add Nutrition section here, before sessions
                if !isEditing {
                    nutritionSection
                    
                    SessionsListView(client: client, showingAddSession: $showingAddSession)
                        .padding(.horizontal, cardPadding)
                }
                if isEditing {
                    DeleteButton(action: { showingDeleteAlert = true })
                }
            }
            .padding(.horizontal, cardPadding)
            .animation(.easeInOut(duration: 0.3), value: isEditing)
        }
        .background(Colors.background)
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .alert("Delete Client", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteClient()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingAddSession) {
            AddSessionView(client: client)
        }
        .sheet(isPresented: $showingNutritionView) {
            NutritionView(client: client)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                image: $selectedImage,
                sourceType: .photoLibrary,
                showAlert: $showAlert,
                alertMessage: $alertMessage
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(
                image: $selectedImage,
                sourceType: .camera,
                showAlert: $showAlert,
                alertMessage: $alertMessage
            )
        }
        .alert("Camera Access", isPresented: $showAlert) {
            Button("Settings", action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            })
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .task {
            await fetchClientData()
        }
        .onDisappear {
            dataManager.cancelNutritionFetch(for: client._id)
        }
        .refreshable {
            await fetchClientData()
        }
    }
    
    // MARK: - Subviews
    private struct TopSpacerView: View {
        var body: some View {
            Color.clear.frame(height: 80)
        }
    }
    
    private var clientDetailsCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 16) {
                ZStack {
                    if !client.clientImage.isEmpty {
                        ClientImageView(imageUrl: client.clientImage, size: 100)
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    
                    if isEditing {
                        Button(action: { showingActionSheet = true }) {
                            Circle()
                                .fill(Colors.nasmBlue)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .offset(x: 35, y: 35)
                    }
                }
                
                VStack(alignment: .center, spacing: 16) {
                    if isEditing {
                        TextField("Name", text: $editedName)
                            .font(.title2.bold())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .multilineTextAlignment(.center)
                    } else {
                        Text(client.name)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: contentSpacing) {
                        MetricView(
                            title: "Age",
                            value: isEditing ? $editedAge : .constant(String(client.age)),
                            unit: "years",
                            isEditing: isEditing
                        )
                        MetricView(
                            title: "Height",
                            value: isEditing ? $editedHeight : .constant(String(format: "%.0f", client.height)),
                            unit: "cm",
                            isEditing: isEditing
                        )
                        MetricView(
                            title: "Weight",
                            value: isEditing ? $editedWeight : .constant(String(format: "%.0f", client.weight)),
                            unit: "kg",
                            isEditing: isEditing
                        )
                    }
                }
            }
            .padding(.horizontal, cardPadding)
            .padding(.top, cardPadding)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoSection(
                    title: "Medical History",
                    text: isEditing ? $editedMedicalHistory : .constant(client.medicalHistory),
                    isEditing: isEditing
                )
                
                InfoSection(
                    title: "Goals",
                    text: isEditing ? $editedGoals : .constant(client.goals),
                    isEditing: isEditing
                )
            }
            .padding(.horizontal, cardPadding)
            .padding(.bottom, cardPadding)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: shadowRadius, x: 0, y: 4)
        .confirmationDialog("Change Profile Picture", isPresented: $showingActionSheet) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose from Library") { showingImagePicker = true }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private struct DeleteButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(role: .destructive, action: action) {
                Text("Delete Client")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .transition(.opacity)
        }
    }
    
    // MARK: - Helper Views
    private var toolbarContent: some ToolbarContent {
        Group {
            if !showingNutritionNote {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                            Text("Back")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(Colors.nasmBlue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            Task {
                                await saveChanges()
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isEditing.toggle()
                                }
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                startEditing()
                                isEditing.toggle()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Colors.nasmBlue)
                }
            }
        }
    }
    
    private func startEditing() {
        editedName = client.name
        editedAge = String(client.age)
        editedHeight = String(format: "%.0f", client.height)
        editedWeight = String(format: "%.0f", client.weight)
        editedMedicalHistory = client.medicalHistory
        editedGoals = client.goals
        editedClientImage = client.clientImage
    }
    
    private func saveChanges() async {
        do {
            var updatedClient = client
            updatedClient.name = editedName
            updatedClient.age = Int(editedAge) ?? client.age
            updatedClient.height = Double(editedHeight) ?? client.height
            updatedClient.weight = Double(editedWeight) ?? client.weight
            updatedClient.medicalHistory = editedMedicalHistory
            updatedClient.goals = editedGoals
            updatedClient.clientImage = editedClientImage
            
            try await dataManager.updateClient(updatedClient)
            
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshClientData"),
                    object: nil,
                    userInfo: ["clientId": client._id]
                )
            }
        } catch {
            await MainActor.run {
                self.error = handleError(error)
                showingError = true
            }
        }
    }
    
    private func deleteClient() async {
        do {
            // Then delete the client from the backend
            try await dataManager.deleteClient(client)
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = handleError(error)
                showingError = true
            }
        }
    }
    
    private func handleError(_ error: Error) -> String {
        switch error {
        case APIError.unauthorized:
            return "Your session has expired. Please log in again"
        case APIError.serverError(let message):
            return "Server error: \(message)"
        case APIError.networkError:
            return "Network error. Please check your connection"
        default:
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    private func fetchClientData() async {
        isLoadingSessions = true
        do {
            async let sessionsFetch = dataManager.fetchClientSessions(for: client)
            async let nutritionFetch = dataManager.fetchNutrition(for: client)
            try await (sessionsFetch, nutritionFetch)
        } catch {
            print("Error fetching client data:", error)
        }
        isLoadingSessions = false
    }
    
    private func toggleSessionCompletion(_ session: Session) {
        Task {
            do {
                var updatedSession = session
                updatedSession.isCompleted.toggle()
                updatedSession.completedDate = updatedSession.isCompleted ? Date() : nil
                
                try await dataManager.updateSession(clientId: client._id, session: updatedSession)
                // Immediately refresh sessions after updating
                try await dataManager.fetchClientSessions(for: client)
            } catch {
                print("Error toggling session completion:", error)
            }
        }
    }
    
    private var nutritionSection: some View {
        VStack(spacing: 12) {
            Button(action: { showingNutritionView = true }) {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 24))
                        Text("Nutrition Plan")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Colors.nasmBlue)
                    
                    if let nutrition = dataManager.clientNutrition {
                        if nutrition.meals.isEmpty {
                            Text("No meals added")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            HStack(spacing: 20) {
                                ForEach(nutrition.meals.prefix(3)) { meal in
                                    VStack(spacing: 4) {
                                        Text(meal.mealName)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(meal.items.count)")
                                            .font(.caption.bold())
                                            .foregroundColor(.primary)
                                        + Text(" items")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
        .padding(.horizontal, cardPadding)
    }
    
    private func uploadImage(_ image: UIImage) {
        Task {
            do {
                if let imageData = image.jpegData(compressionQuality: 0.7) {
                    let imageUrl = try await APIClient.shared.uploadImage(imageData)
                    // Update client with new image URL
                    var updatedClient = client
                    updatedClient.clientImage = imageUrl
                    try await dataManager.updateClient(updatedClient)
                    // Refresh client data
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshClientData"),
                        object: nil,
                        userInfo: ["clientId": client._id]
                    )
                }
            } catch {
                print("Error uploading image:", error)
                await MainActor.run {
                    self.error = handleError(error)
                    showingError = true
                }
            }
        }
    }
}

// Add this button style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

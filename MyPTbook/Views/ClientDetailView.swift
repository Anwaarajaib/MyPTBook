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
    @State private var showingPopover = false
    
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
                
                if !isEditing {
                    SessionsListView(client: client, showingAddSession: $showingAddSession)
                        .transition(.opacity)
                }
                
                if isEditing {
                    DeleteButton(action: { showingDeleteAlert = true })
                }
            }
            .padding(.horizontal, cardPadding)
            .animation(.easeInOut(duration: 0.3), value: isEditing)
        }
        .background(Colors.background)
        .toolbar {
            toolbarContent
        }
        .toolbarBackground(Colors.background)
        .toolbarColorScheme(.light)
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .if(!DesignSystem.isIPad) { view in
            view.confirmationDialog("Change Profile Picture", isPresented: $showingActionSheet) {
                Button("Take Photo") { showingCamera = true }
                Button("Choose from Library") { showingImagePicker = true }
                Button("Cancel", role: .cancel) { }
            }
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
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
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
        .overlay {
            if showingNutritionView {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingNutritionView = false
                    }
                
                NutritionView(isPresented: $showingNutritionView, client: client)
            }
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
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                print("ClientDetailView: New image selected, updating UI")
                // Update the client image immediately for preview
                editedClientImage = "preview"  // This will trigger the preview mode
                // Store the image for later upload
                selectedImage = image
            }
        }
    }
    
    // MARK: - Subviews
    private struct TopSpacerView: View {
        var body: some View {
            Color.clear.frame(height: DesignSystem.isIPad ? 60 : 80)
        }
    }
    
    private var clientDetailsCard: some View {
        VStack(spacing: 12) {
            // Profile Image and Name Section
            HStack(alignment: .top, spacing: DesignSystem.isIPad ? contentSpacing * 3 : contentSpacing * 2) {
                // Left side - Profile Image
                ZStack {
                    if !client.clientImage.isEmpty && editedClientImage != "preview" {
                        ClientImageView(imageUrl: client.clientImage, size: DesignSystem.isIPad ? 120 : 80)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else if editedClientImage == "preview", let previewImage = selectedImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: DesignSystem.isIPad ? 120 : 80, height: DesignSystem.isIPad ? 120 : 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: DesignSystem.isIPad ? 120 : 80, height: DesignSystem.isIPad ? 120 : 80)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    
                    if isEditing {
                        Button(action: {
                            if DesignSystem.isIPad {
                                showingPopover = true
                            } else {
                                showingActionSheet = true
                            }
                        }) {
                            Image(systemName: "camera")
                                .font(.system(size: DesignSystem.isIPad ? 24 : 18))
                                .foregroundColor(Colors.nasmBlue)
                                .padding(7)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .offset(x: DesignSystem.isIPad ? 38 : 26, 
                               y: DesignSystem.isIPad ? 38 : 26)
                        .popover(isPresented: $showingPopover,
                                 attachmentAnchor: .point(.topTrailing),
                                 arrowEdge: .leading) {
                            VStack(spacing: 0) {
                                Button(action: { 
                                    showingPopover = false
                                    showingCamera = true 
                                }) {
                                    Text("Take Photo")
                                        .font(.system(size: 17))
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                
                                Divider()
                                
                                Button(action: { 
                                    showingPopover = false
                                    showingImagePicker = true 
                                }) {
                                    Text("Choose from Library")
                                        .font(.system(size: 17))
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                            }
                            .background(Color(UIColor.systemBackground))
                            .frame(width: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .frame(width: DesignSystem.isIPad ? minimumTapTarget * 1.5 : minimumTapTarget, 
                       height: DesignSystem.isIPad ? minimumTapTarget * 1.5 : minimumTapTarget)
                .padding(.top, DesignSystem.isIPad ? 12 : 7)
                .padding(.leading, DesignSystem.isIPad ? 12 : 7)
                
                // Right side - Name and Metrics
                VStack(alignment: .leading, spacing: 16) {
                    if isEditing {
                        TextField("Name", text: $editedName)
                            .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 24 : 22, weight: .bold))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(client.name)
                            .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 24 : 22, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.top, -5)
                    }
                    
                    // Metrics in horizontal layout
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
                .padding(.top, DesignSystem.isIPad ? 0 : -5)
            }
            .padding(.horizontal, DesignSystem.isIPad ? cardPadding * 1.5 : cardPadding)
            .padding(.top, DesignSystem.isIPad ? cardPadding : cardPadding)
            .padding(.bottom, DesignSystem.isIPad ? 16 : 8)
            
            // Medical History and Goals with Nutrition Note
            HStack(alignment: .top, spacing: contentSpacing) {
                // Info Sections
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
                .frame(maxWidth: .infinity)
                
                // Nutrition Note Button
                if !isEditing {
                    Button(action: { showingNutritionView = true }) {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    .frame(width: 70, height: 90)
                                
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(Colors.nasmBlue.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Image(systemName: "doc.plaintext.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Colors.nasmBlue)
                                        )
                                    
                                    Text("Nutrition")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Colors.nasmBlue)
                                }
                            }
                        }
                        .frame(width: 70)
                        .frame(height: 100)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, cardPadding)
            .padding(.bottom, cardPadding)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: shadowRadius, x: 0, y: 4)
    }
    
    private struct DeleteButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(role: .destructive, action: action) {
                Text("Delete Client")
                    .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 18 : 17, weight: .semibold))
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: DesignSystem.isIPad ? 16 : 16, weight: .semibold))
                        Text("Back")
                            .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 16 : 16, weight: .semibold))
                    }
                    .foregroundColor(Colors.nasmBlue)
                }
                .disabled(showingNutritionView)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if isEditing {
                        Task {
                            await saveChanges()
                        }
                    } else {
                        startEditing()
                    }
                    isEditing.toggle()
                }) {
                    Text(isEditing ? "Save" : "Edit")
                        .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 18 : 16, weight: .medium))
                        .foregroundColor(Colors.nasmBlue)
                }
                .disabled(showingNutritionView)
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
    
    private func processImageForUpload(_ image: UIImage) -> Data? {
        // Calculate target size (20% of original)
        let scale = 0.2
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Compress to JPEG with moderate compression
        return resizedImage?.jpegData(compressionQuality: 0.7)
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
            
            // If there's a new image selected, process and upload it first
            if let newImage = selectedImage,
               let processedImageData = processImageForUpload(newImage) {
                let imageUrl = try await APIClient.shared.uploadImage(processedImageData)
                updatedClient.clientImage = imageUrl
            }
            
            // Update the client with all changes
            try await dataManager.updateClient(updatedClient)
            
            await MainActor.run {
                selectedImage = nil
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
            try await dataManager.fetchClientSessions(for: client)
            try await dataManager.fetchNutrition(for: client)
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
                            .font(.system(size: DesignSystem.isIPad ? 26 : 24))
                        Text("Nutrition Plan")
                            .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 18 : 17, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: DesignSystem.isIPad ? 16 : 14, weight: .semibold))
                    }
                    .foregroundColor(Colors.nasmBlue)
                    
                    if let nutrition = dataManager.clientNutrition {
                        if nutrition.meals.isEmpty {
                            Text("No meals added")
                                .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 15 : 14, weight: .regular))
                                .foregroundColor(.gray)
                        } else {
                            HStack(spacing: 20) {
                                ForEach(nutrition.meals.prefix(3)) { meal in
                                    VStack(spacing: 4) {
                                        Text(meal.mealName)
                                            .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 14 : 12, weight: .regular))
                                            .foregroundColor(.gray)
                                        Text("\(meal.items.count)")
                                            .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 14 : 12, weight: .bold))
                                            .foregroundColor(.primary)
                                        + Text(" items")
                                            .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 14 : 12, weight: .regular))
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
        selectedImage = image  // Store the selected image
        // The actual upload will happen in saveChanges() when "Done" is tapped
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

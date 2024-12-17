import SwiftUI
import Foundation
import UIKit

struct ClientDetailView: View {
    @ObservedObject var dataManager: DataManager
    let client: Client
    @State private var showingAddSession = false
    @State private var isEditing = false
    
    // Edit mode states
    @State private var editedName: String = ""
    @State private var editedAge: String = ""
    @State private var editedHeight: String = ""
    @State private var editedWeight: String = ""
    @State private var editedMedicalHistory: String = ""
    @State private var editedGoals: String = ""
    @State private var editedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    
    // Add these constants at the top of the file
    private let cardPadding: CGFloat = 24
    private let contentSpacing: CGFloat = 20
    private let cornerRadius: CGFloat = 16
    private let shadowRadius: CGFloat = 10
    private let minimumTapTarget: CGFloat = 44
    
    // Add these state variables at the top with other @State properties
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingNutritionNote = false
    @State private var nutritionPlan: String = ""
    @State private var error: String?
    @State private var showingError = false
    
    // Initialize nutritionPlan with client's value
    init(dataManager: DataManager, client: Client) {
        self.dataManager = dataManager
        self.client = client
        // Initialize the State property with client's nutrition plan
        _nutritionPlan = State(initialValue: client.nutritionPlan)
        
        // Add observer for session deletion
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DeleteSessionCard"),
            object: nil,
            queue: .main
        ) { [weak dataManager] notification in
            if let sessionNumbers = notification.userInfo?["sessionNumbers"] as? [Int],
               let clientId = notification.userInfo?["clientId"] as? UUID,
               clientId == client.id {
                Task { @MainActor in
                    do {
                        guard let dataManager = dataManager else { return }
                        for sessionNumber in sessionNumbers {
                            if let session = client.sessions.first(where: { $0.sessionNumber == sessionNumber }) {
                                try await dataManager.deleteClientSession(clientId: client.id, sessionId: session.id)
                            }
                        }
                    } catch {
                        print("Error deleting sessions: \(error)")
                    }
                }
            }
        }
        
        // Update the refresh notification observer
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshClientData"),
            object: nil,
            queue: .main
        ) { [weak dataManager] notification in
            if let notificationClientId = notification.userInfo?["clientId"] as? UUID,
               notificationClientId == client.id {
                Task { @MainActor in
                    do {
                        guard let dataManager = dataManager else { return }
                        // Force refresh the view
                        dataManager.objectWillChange.send()
                        
                        // Fetch updated client data
                        let clients = try await dataManager.fetchClients()
                        if let updatedClient = clients.first(where: { $0.id == client.id }),
                           let index = dataManager.clients.firstIndex(where: { $0.id == client.id }) {
                            dataManager.clients[index] = updatedClient
                        }
                    } catch {
                        print("Error refreshing client data: \(error)")
                    }
                }
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: contentSpacing) {
                // Refined top spacing
                Color.clear.frame(height: 80)
                
                // White Card Section for Client Details
                VStack(spacing: 12) {
                    // Profile Image and Name Section
                    HStack(alignment: .top, spacing: contentSpacing * 2) {
                        // Left side - Profile Image
                        Button(action: { 
                            if isEditing {
                                showingActionSheet = true
                            }
                        }) {
                            ZStack {
                                if let displayImage = isEditing ? editedImage : client.profileImage {
                                    Image(uiImage: displayImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 80, height: 80)
                                        .foregroundColor(.gray.opacity(0.3))
                                }
                                
                                if isEditing {
                                    Image(systemName: "camera")
                                        .font(.system(size: 18))
                                        .foregroundColor(Colors.nasmBlue)
                                        .padding(7)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
                                        .offset(x: 26, y: 26)
                                }
                            }
                        }
                        .frame(width: minimumTapTarget, height: minimumTapTarget)
                        .disabled(!isEditing)
                        .padding(.top, 7)
                        .padding(.leading, 7)
                        
                        // Right side - Name and Metrics
                        VStack(alignment: .leading, spacing: 16) {
                            // Name
                            if isEditing {
                                TextField("Name", text: $editedName)
                                    .font(.title2.bold())
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                Text(client.name)
                                    .font(.title2.bold())
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
                        .padding(.top, -5)
                    }
                    .padding(.horizontal, cardPadding)
                    .padding(.top, cardPadding)
                    .padding(.bottom, 8)
                    
                    // Medical History and Goals with Note
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
                            Button(action: {
                                showingNutritionNote = true
                            }) {
                                VStack(spacing: 4) {
                                    ZStack {
                                        // Background card
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white)
                                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                            .frame(width: 70, height: 90)
                                        
                                        VStack(spacing: 8) {
                                            // Icon container
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
                
                // Sessions and Delete Button
                if !isEditing {
                    SessionsListView(client: client, showingAddSession: $showingAddSession)
                        .transition(.opacity)
                }
                
                if isEditing {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
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
            .padding(.horizontal, cardPadding)
            .animation(.easeInOut(duration: 0.3), value: isEditing)
        }
        .background(Colors.background)
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .tint(Colors.nasmBlue)
        .toolbar {
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
        .alert("Delete Client", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteClient()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this client? This action cannot be undone.")
        }
        .tint(Colors.nasmBlue)
        .sheet(isPresented: $showingAddSession) {
            AddSessionView(client: client)
        }
        .confirmationDialog("Change Profile Picture", isPresented: $showingActionSheet) {
            Button {
                showingCamera = true
            } label: {
                Text("Take Photo")
                    .foregroundColor(Colors.nasmBlue)
            }
            
            Button {
                showingImagePicker = true
            } label: {
                Text("Choose from Library")
                    .foregroundColor(Colors.nasmBlue)
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .tint(Colors.nasmBlue)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                image: $editedImage, 
                sourceType: .photoLibrary,
                showAlert: $showAlert,
                alertMessage: $alertMessage
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(
                image: $editedImage, 
                sourceType: .camera,
                showAlert: $showAlert,
                alertMessage: $alertMessage
            )
        }
        .alert("Camera Access", isPresented: $showAlert) {
            Button("OK") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .overlay {
            if showingNutritionNote {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingNutritionNote = false
                    }
                
                NutritionNoteView(
                    nutritionPlan: $nutritionPlan,
                    dataManager: dataManager,
                    client: client,
                    isPresented: $showingNutritionNote
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showingNutritionNote)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(error ?? "An unknown error occurred")
        }
    }
    
    private func startEditing() {
        editedName = client.name
        editedAge = String(client.age)
        editedHeight = String(format: "%.0f", client.height)
        editedWeight = String(format: "%.0f", client.weight)
        editedMedicalHistory = client.medicalHistory
        editedGoals = client.goals
        editedImage = client.profileImage
        nutritionPlan = client.nutritionPlan
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
            updatedClient.profileImage = editedImage
            updatedClient.nutritionPlan = nutritionPlan
            
            // Save the image first
            if editedImage != client.profileImage {
                DataManager.shared.saveClientImage(editedImage, clientId: client.id)
            }
            
            try await dataManager.updateClient(updatedClient)
            
            await MainActor.run {
                // Update the client's image in memory
                if let index = dataManager.clients.firstIndex(where: { $0.id == client.id }) {
                    dataManager.clients[index].profileImage = editedImage
                }
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshClientData"),
                    object: nil
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
            // Delete the client's image first
            DataManager.shared.deleteClientImage(clientId: client.id)
            
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
}

// Add this button style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

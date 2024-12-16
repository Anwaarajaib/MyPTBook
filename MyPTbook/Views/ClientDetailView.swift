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
        ) { notification in
            if let sessionNumbers = notification.userInfo?["sessionNumbers"] as? [Int],
               let clientId = notification.userInfo?["clientId"] as? UUID,
               clientId == client.id {
                var updatedClient = client
                updatedClient.sessions.removeAll { session in
                    sessionNumbers.contains(session.sessionNumber)
                }
                
                // Update client in DataManager
                if let index = dataManager.clients.firstIndex(where: { $0.id == client.id }) {
                    dataManager.clients[index] = updatedClient
                    dataManager.saveClients()
                    
                    // Post notification to refresh data
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshClientData"), object: nil)
                }
            }
        }
        
        // Update the notification observer in ClientDetailView init
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshClientData"),
            object: nil,
            queue: .main
        ) { [weak dataManager] notification in
            if let notificationClientId = notification.userInfo?["clientId"] as? UUID,
               notificationClientId == client.id {
                // Force refresh the view
                dataManager?.objectWillChange.send()
                
                // Get updated client data
                if let updatedClient = dataManager?.getClients().first(where: { $0.id == client.id }) {
                    if let index = dataManager?.clients.firstIndex(where: { $0.id == client.id }) {
                        dataManager?.clients[index] = updatedClient
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
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                            Text("Delete Client")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: minimumTapTarget)
                        .background(Color.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .shadow(color: .red.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
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
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if isEditing {
                                saveChanges()
                            } else {
                                startEditing()
                            }
                            isEditing.toggle()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Colors.nasmBlue)
                }
            }
        }
        .alert("Delete Client", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteClient()
                dismiss()
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
    
    private func saveChanges() {
        var updatedClient = client
        updatedClient.name = editedName
        updatedClient.age = Int(editedAge) ?? client.age
        updatedClient.height = Double(editedHeight) ?? client.height
        updatedClient.weight = Double(editedWeight) ?? client.weight
        updatedClient.medicalHistory = editedMedicalHistory
        updatedClient.goals = editedGoals
        updatedClient.profileImage = editedImage
        updatedClient.nutritionPlan = nutritionPlan
        
        // Update the client in DataManager
        if let index = dataManager.clients.firstIndex(where: { $0.id == client.id }) {
            dataManager.clients[index] = updatedClient
            dataManager.saveClients()
            
            // Post notification to refresh data
            NotificationCenter.default.post(name: NSNotification.Name("RefreshClientData"), object: nil)
        }
    }
    
    private func deleteClient() {
        if let index = dataManager.clients.firstIndex(where: { $0.id == client.id }) {
            dataManager.clients.remove(at: index)
            dataManager.saveClients()
        }
    }
}

struct MetricView: View {
    let title: String
    @Binding var value: String
    let unit: String
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            if isEditing {
                HStack(spacing: 4) {
                    TextField("0", text: $value)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                    Text(unit)
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .fixedSize()
                }
            } else {
                Text("\(value) \(unit)")
                    .font(.body.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoSection: View {
    let title: String
    @Binding var text: String
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            if isEditing {
                TextEditor(text: $text)
                    .frame(height: 60)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                Text(text)
                    .font(.body.bold())
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

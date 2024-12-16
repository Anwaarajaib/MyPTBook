import SwiftUI
import PhotosUI

struct TrainerProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @Binding var name: String
    @Binding var profileImage: UIImage?
    
    @State private var tempName: String
    @State private var tempImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    @State private var isEditing = false
    @State private var isAuthenticated: Bool = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(name: Binding<String>, profileImage: Binding<UIImage?>) {
        self._name = name
        self._profileImage = profileImage
        _tempName = State(initialValue: name.wrappedValue)
        _tempImage = State(initialValue: profileImage.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                mainContent
            }
            .background(Colors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog("Change Profile Picture", isPresented: $showingActionSheet) {
                dialogButtons
            }
            .tint(Colors.nasmBlue)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(
                    image: $tempImage,
                    sourceType: .photoLibrary,
                    showAlert: $showAlert,
                    alertMessage: $alertMessage
                )
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(
                    image: $tempImage,
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
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 24) {
            profileCard
            logoutButton
        }
        .padding(20)
    }
    
    private var profileCard: some View {
        VStack(spacing: 24) {
            profileImageSection
            nameSection
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var profileImageSection: some View {
        Button(action: { }) {
            ZStack {
                if let profileImage = tempImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray.opacity(0.5))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
                }
                
                if isEditing {
                    cameraButton
                }
            }
        }
    }
    
    private var cameraButton: some View {
        Image(systemName: "camera")
            .font(.system(size: 18))
            .foregroundColor(Colors.nasmBlue)
            .padding(7)
            .background(Color.white)
            .clipShape(Circle())
            .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
            .offset(x: 35, y: 35)
            .onTapGesture { showingActionSheet = true }
    }
    
    private var nameSection: some View {
        VStack(alignment: .center, spacing: 8) {
            if isEditing {
                TextField("Enter your name", text: $tempName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.title2)
                    .multilineTextAlignment(.center)
            } else {
                Text(tempName.isEmpty ? name : tempName)
                    .font(.title2)
                    .foregroundColor(.black)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var logoutButton: some View {
        Button(action: performLogout) {
            Text("Logout")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 24)
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { 
                    dismiss() 
                }
                .foregroundColor(Colors.nasmBlue)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Save" : "Edit") {
                    handleEditSave()
                }
                .foregroundColor(Colors.nasmBlue)
            }
        }
    }
    
    private var dialogButtons: some View {
        Group {
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
    }
    
    private func handleEditSave() {
        if isEditing {
            name = tempName
            profileImage = tempImage
            DataManager.shared.saveTrainerName(tempName)
            DataManager.shared.saveTrainerImage(tempImage)
            dismiss()
        }
        withAnimation {
            isEditing.toggle()
        }
    }
    
    private func performLogout() {
        APIClient.shared.logout()
        authManager.isAuthenticated = false
        DataManager.shared.clearAuthToken()
        dismiss()
    }
} 

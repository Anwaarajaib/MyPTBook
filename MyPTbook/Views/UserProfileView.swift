import SwiftUI

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var dataManager = DataManager.shared
    
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    @State private var selectedImage: UIImage?
    @State private var profileImage: Image?
    @State private var profileImageUrl: String?
    @State private var error: String?
    @State private var showAlert = false
    @State private var isLoading = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                mainContent
            }
            .background(Colors.background)
            .navigationTitle("User Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog("Change Profile Picture", isPresented: $showingActionSheet) {
                Button("Take Photo") { showingCamera = true }
                Button("Choose Photo") { showingImagePicker = true }
                Button("Cancel", role: .cancel) { }
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
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    print("UserProfileView: New image selected, updating UI")
                    profileImage = Image(uiImage: image)
                }
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
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "An unknown error occurred")
            }
            .task {
                await fetchUserProfile()
                if let imageUrl = dataManager.userProfileImageUrl {
                    await loadProfileImage(from: imageUrl)
                }
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
        VStack(spacing: 32) {
            profileImageSection
            
            VStack(spacing: 16) {
                nameSection
                
                Divider()
                    .background(Colors.nasmBlue.opacity(0.1))
                    .padding(.horizontal, -24)
                
                InfoRow(
                    title: "Email",
                    value: dataManager.userEmail,
                    icon: "envelope.fill"
                )
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 4)
    }
    
    private var profileImageSection: some View {
        ZStack {
            if let profileImage = profileImage {
                profileImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 110, height: 110)
                    .overlay(
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 45, height: 45)
                            .foregroundColor(Color.gray.opacity(0.5))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            
            if isEditing {
                Button(action: { showingActionSheet = true }) {
                    Image(systemName: "camera")
                        .font(.system(size: 18))
                        .foregroundColor(Colors.nasmBlue)
                        .padding(7)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
                        .offset(x: 35, y: 35)
                }
            }
        }
    }
    
    private var nameSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .foregroundColor(Colors.nasmBlue)
                .frame(width: 20)
                .font(.system(size: 16, weight: .medium))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Colors.nasmBlue.opacity(0.8))
                    .kerning(0.5)
                
                if isEditing {
                    TextField("Enter your name", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .fontWeight(.medium)
                } else {
                    Text(dataManager.userName)
                        .font(.body)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var logoutButton: some View {
        Button(action: logout) {
            Text("Logout")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red)
                        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading {
                    ProgressView()
                } else {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            Task {
                                await updateProfile()
                            }
                        } else {
                            startEditing()
                        }
                    }
                }
            }
        }
    }
    
    private func fetchUserProfile() async {
        print("UserProfileView: Fetching user profile")
        do {
            let profile = try await APIClient.shared.getProfile()
            print("UserProfileView: Profile fetched - Name:", profile.name, "Email:", profile.email)
            print("UserProfileView: Profile image URL:", profile.profileImage ?? "none")
            
            await MainActor.run {
                dataManager.saveUserName(profile.name)
                dataManager.saveUserEmail(profile.email)
                editedName = profile.name
                
                if let imageUrl = profile.profileImage {
                    self.profileImageUrl = imageUrl
                    dataManager.saveProfileImageUrl(imageUrl)
                    print("UserProfileView: Profile image URL found and saved:", imageUrl)
                } else {
                    print("UserProfileView: No profile image URL found")
                    self.profileImage = nil
                    self.profileImageUrl = nil
                }
                print("UserProfileView: Profile updated in UI and DataManager")
            }
        } catch {
            print("UserProfileView: Error fetching profile:", error)
            await MainActor.run {
                self.error = handleError(error)
                showAlert = true
            }
        }
    }
    
    private func updateProfile() async {
        print("UserProfileView: Starting profile update")
        isLoading = true
        
        do {
            // 1. FRONTEND: Update UI immediately for better UX
            await MainActor.run {
                print("UserProfileView: Updating UI first")
                if let newImage = selectedImage {
                    profileImage = Image(uiImage: newImage)
                }
            }
            
            // 2. BACKEND: Process updates
            if let newImage = selectedImage {
                print("UserProfileView: Processing and uploading new profile image")
                try await uploadProfileImage(newImage)
            }
            
            try await dataManager.updateUserProfile(name: editedName)
            
            // 3. FRONTEND: Finalize UI updates after backend success
            await MainActor.run {
                print("UserProfileView: Finalizing UI updates")
                dataManager.saveUserName(editedName)
                isEditing = false
                isLoading = false
                selectedImage = nil
                
                // Refresh UI everywhere
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshUserProfile"),
                    object: nil
                )
            }
        } catch {
            print("UserProfileView: Error updating profile:", error)
            await MainActor.run {
                isLoading = false
                self.error = handleError(error)
                showAlert = true
                
                // Revert UI changes if backend update failed
                if let imageUrl = profileImageUrl {
                    Task {
                        await loadProfileImage(from: imageUrl)
                    }
                }
            }
        }
    }
    
    private func startEditing() {
        editedName = dataManager.userName
        isEditing = true
        print("UserProfileView: Started editing - Current name:", dataManager.userName)
    }
    
    private func logout() {
        print("UserProfileView: Initiating logout - User:", dataManager.userName, "Email:", dataManager.userEmail)
        authManager.isAuthenticated = false
        authManager.logout()
        dismiss()
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
    
    private func uploadProfileImage(_ image: UIImage) async throws {
        print("uploadProfileImage: Function called with image size: \(image.size)")
        
        // Process the image before upload
        guard let processedImageData = processImageForUpload(image) else {
            print("uploadProfileImage: Failed to process image")
            throw APIError.serverError("Failed to process image")
        }
        
        print("uploadProfileImage: Starting upload...")
        let imageUrl = try await APIClient.shared.uploadImage(processedImageData)
        print("uploadProfileImage: Image uploaded successfully - URL: \(imageUrl)")
        
        print("uploadProfileImage: Updating user profile...")
        _ = try await APIClient.shared.updateUserProfileWithImage(
            name: dataManager.userName,
            profileImage: imageUrl
        )
        print("uploadProfileImage: Profile updated successfully")
        
        await MainActor.run {
            print("uploadProfileImage: Updating UI...")
            self.profileImageUrl = imageUrl
            dataManager.saveProfileImageUrl(imageUrl)
        }
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
    
    private func loadProfileImage(from url: String) async {
        print("loadProfileImage: Attempting to load from URL:", url)
        guard let imageUrl = URL(string: url) else {
            print("loadProfileImage: Invalid image URL:", url)
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageUrl)
            if let uiImage = UIImage(data: data) {
                print("loadProfileImage: Successfully loaded image")
                await MainActor.run {
                    profileImage = Image(uiImage: uiImage)
                }
            } else {
                print("loadProfileImage: Failed to create UIImage from data")
            }
        } catch {
            print("loadProfileImage: Failed to load image:", error)
        }
    }
    
    private func handleImageSelection(_ image: UIImage) {
        print("handleImageSelection: Called with image size: \(image.size)")
        // Update UI immediately without Task wrapper
        selectedImage = image
        profileImage = Image(uiImage: image)
        print("handleImageSelection: UI updated immediately with new image")
    }
}

// Helper view for info rows
private struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Colors.nasmBlue)
                .frame(width: 20)
                .font(.system(size: 16, weight: .medium))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Colors.nasmBlue.opacity(0.8))
                    .kerning(0.5)
                Text(value)
                    .font(.body)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

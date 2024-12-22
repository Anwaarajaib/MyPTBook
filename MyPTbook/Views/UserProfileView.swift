import SwiftUI

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var authManager = AuthManager.shared
    
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var showingLogoutAlert = false
    @State private var error: String?
    @State private var showingError = false
    @State private var isLoading = false
    
    init() {
        _editedName = State(initialValue: DataManager.shared.userName)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // User Info Card
                    userInfoCard
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .background(Colors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarItems
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "An unknown error occurred")
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
            .task {
                await fetchUserProfile()
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                if isEditing {
                    TextField("Name", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 200)
                } else {
                    Text(dataManager.userName)
                        .font(.title2.bold())
                }
                
                Text(dataManager.userEmail)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var userInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    title: "Name",
                    value: dataManager.userName,
                    icon: "person.fill"
                )
                
                InfoRow(
                    title: "Email",
                    value: dataManager.userEmail,
                    icon: "envelope.fill"
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            Button(action: { showingLogoutAlert = true }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Logout")
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private var toolbarItems: some ToolbarContent {
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
            
            await MainActor.run {
                dataManager.saveUserName(profile.name)
                dataManager.saveUserEmail(profile.email)
                editedName = profile.name
                print("UserProfileView: Profile updated in UI and DataManager")
            }
        } catch {
            print("UserProfileView: Error fetching profile:", error)
            await MainActor.run {
                self.error = handleError(error)
                showingError = true
            }
        }
    }
    
    private func updateProfile() async {
        print("UserProfileView: Updating profile - New name:", editedName)
        isLoading = true
        do {
            try await dataManager.updateUserProfile(name: editedName)
            await MainActor.run {
                dataManager.saveUserName(editedName)
                isEditing = false
                isLoading = false
                print("UserProfileView: Profile update successful - New name:", editedName)
            }
        } catch {
            print("UserProfileView: Error updating profile:", error)
            await MainActor.run {
                isLoading = false
                self.error = handleError(error)
                showingError = true
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
} 

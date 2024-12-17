import SwiftUI

// MARK: - Main Application View
struct MainAppView: View {
    @StateObject private var dataManager = DataManager.shared
    @EnvironmentObject private var authManager: AuthManager
    @State private var clients: [Client] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingAddClient = false
    @State private var showingProfile = false
    @State private var trainerName: String = DataManager.shared.getUserName()
    @State private var trainerImage: UIImage? = DataManager.shared.getUserImage()
    
    // Add observer for profile updates
    private let profileUpdatePublisher = NotificationCenter.default.publisher(
        for: NSNotification.Name("ProfileImageUpdated")
    )
    
    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 150), spacing: 52)
    ]
    
    private func refreshClients() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let updatedClients = try await APIClient.shared.fetchClients()
                await MainActor.run {
                    dataManager.clients = updatedClients
                    isLoading = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    handleError(error)
                    isLoading = false
                }
            }
        }
    }
    
    private func handleError(_ error: APIError) {
        switch error {
        case .unauthorized:
            // Handle unauthorized error (e.g., show login screen)
            break
        case .networkError(let urlError as URLError):
            self.error = "Network error: \(urlError.localizedDescription)"
        case .serverError(let message):
            self.error = message
        default:
            self.error = "An unexpected error occurred"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        // Trainer name with "Coach" prefix
                        Text("\(trainerName)")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Profile image button
                        Button(action: { showingProfile = true }) {
                            if let profileImage = trainerImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.gray.opacity(0.5))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Clients grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        // Add Client button
                        Button(action: { showingAddClient = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(Colors.nasmBlue)
                                Text("Add Client")
                                    .font(.headline)
                                    .foregroundColor(Colors.nasmBlue)
                            }
                            .padding(.vertical, 34)
                            .padding(.horizontal, 20)
                            .frame(width: 128, height: 128)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        
                        // Existing clients
                        ForEach(dataManager.clients) { client in
                            ClientCard(client: client, dataManager: dataManager)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .background(Colors.background)
            .onAppear {
                refreshClients()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshClientData"))) { _ in
                refreshClients()
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView(dataManager: dataManager)
            }
            .sheet(isPresented: $showingProfile) {
                UserProfileView(
                    name: $trainerName,
                    profileImage: .constant(DataManager.shared.getUserImage())
                )
                .environmentObject(authManager)
            }
        }
        .background(Colors.background)
        .accentColor(Colors.nasmBlue)
        .tint(Colors.nasmBlue)
        .onReceive(profileUpdatePublisher) { _ in
            trainerImage = DataManager.shared.getUserImage()
        }
    }
} 

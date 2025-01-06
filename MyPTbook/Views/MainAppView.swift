import SwiftUI

// MARK: - Main Application View
struct MainAppView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var showingAddClient = false
    @State private var showingProfile = false
    @State private var userName: String = "Default Name"
    @State private var userProfileImage: UIImage? = nil
    @State private var error: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text(dataManager.userName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: { showingProfile = true }) {
                            if let profileUrl = dataManager.userProfileImageUrl, !profileUrl.isEmpty {
                                ProfileImageView(imageUrl: profileUrl, size: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.gray)
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
                    
                    // Clients Grid - Updated to three columns
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
                        
                        // Client Cards
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
            .task {
                await fetchClients()
            }
            .refreshable {
                await fetchClients()
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView(dataManager: dataManager)
            }
            .sheet(isPresented: $showingProfile) {
                UserProfileView()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "An unknown error occurred")
            }
        }
        .background(Colors.background)
        .accentColor(Colors.nasmBlue)
        .tint(Colors.nasmBlue)
    }
    
    private func fetchClients() async {
        do {
            print("Starting client fetch")
            try await dataManager.fetchClients()
            print("Client fetch successful, count:", dataManager.clients.count)
        } catch {
            print("Client fetch error:", error)
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

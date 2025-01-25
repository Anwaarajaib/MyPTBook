import SwiftUI

// MARK: - Main Application View
struct MainAppView: View {
    @StateObject private var dataManager = DataManager.shared
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
                            .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 28 : 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: { showingProfile = true }) {
                            if let profileUrl = dataManager.userProfileImageUrl, !profileUrl.isEmpty {
                                ProfileImageView(imageUrl: profileUrl, size: DesignSystem.isIPad ? 100 : 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .adaptiveFrame(width: DesignSystem.isIPad ? 100 : 80, 
                                                 height: DesignSystem.isIPad ? 100 : 80)
                                    .foregroundColor(.gray)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .adaptivePadding(.horizontal, DesignSystem.isIPad ? 40 : 24)
                    .adaptivePadding(.top, DesignSystem.isIPad ? 16 : 8)
                    .adaptivePadding(.bottom, DesignSystem.isIPad ? 8 : 4)
                    
                    // Clients Grid
                    LazyVGrid(
                        columns: DesignSystem.gridColumns,
                        spacing: DesignSystem.gridSpacing
                    ) {
                        // Add Client button
                        NavigationLink {
                            AddClientView(dataManager: dataManager)
                        } label: {
                            VStack(spacing: DesignSystem.adaptiveSize(8)) {
                                Spacer()
                                    .frame(height: DesignSystem.adaptiveSize(16))
                                
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: DesignSystem.adaptiveSize(30)))
                                    .foregroundColor(Colors.nasmBlue)
                                Text("Add Client")
                                    .font(DesignSystem.adaptiveFont(size: 17, weight: .semibold))
                                    .foregroundColor(Colors.nasmBlue)
                                
                                Spacer()
                                    .frame(height: DesignSystem.adaptiveSize(8))
                            }
                            .adaptivePadding(.vertical, 20)
                            .adaptivePadding(.horizontal, 20)
                            .adaptiveFrame(width: DesignSystem.maxCardWidth, 
                                         height: DesignSystem.maxCardWidth)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        
                        // Client Cards
                        ForEach(dataManager.clients) { client in
                            ClientCard(client: client, dataManager: dataManager)
                        }
                    }
                    .adaptivePadding(.horizontal, DesignSystem.isIPad ? 32 : 16)
                    .adaptivePadding(.vertical, DesignSystem.isIPad ? 8 : 4)
                }
                .adaptivePadding(.top, 0)
                .adaptivePadding(.bottom, DesignSystem.isIPad ? 16 : 8)
            }
            .background(Colors.background)
            .task {
                await fetchClients()
            }
            .refreshable {
                await fetchClients()
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

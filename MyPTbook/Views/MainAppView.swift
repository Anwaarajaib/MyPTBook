import SwiftUI

// MARK: - Main Application View
struct MainAppView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var clients: [Client] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingAddClient = false
    @State private var showingTrainerProfile = false
    @State private var trainerName: String = DataManager.shared.getTrainerName()
    @State private var trainerImage: UIImage? = DataManager.shared.getTrainerImage()
    
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
                        Button(action: { showingTrainerProfile = true }) {
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
                    LazyVGrid(columns: columns, spacing: 16) {
                        // Display clients first
                        ForEach(dataManager.clients) { client in
                            ClientCard(client: client, dataManager: dataManager)
                        }
                        
                        // Add Client button at the end
                        Button(action: { showingAddClient = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(Colors.nasmBlue)
                                Text("Add Client")
                                    .font(.headline)
                                    .foregroundColor(Colors.nasmBlue)
                            }
                            .padding(.vertical, 40)
                            .padding(.horizontal, 24)
                            .frame(width: 150, height: 150)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 24)
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
            .sheet(isPresented: $showingTrainerProfile) {
                TrainerProfileView(
                    name: $trainerName,
                    profileImage: $trainerImage
                )
            }
        }
        .background(Colors.background)
    }
} 

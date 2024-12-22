import SwiftUI
import PDFKit

// MARK: - Trainer Profile Header
struct TrainerProfileHeader: View {
    @Binding var showingProfile: Bool
    
    var body: some View {
        Button(action: { showingProfile = true }) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading) {
                    Text("Welcome")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Trainer Name")
                        .font(.title2.bold())
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Colors.background)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Client Card
struct ClientCard: View {
    let client: Client
    @ObservedObject var dataManager: DataManager
    
    var body: some View {
        NavigationLink(destination: ClientDetailView(dataManager: dataManager, client: client)) {
            VStack(spacing: 12) {
                // Profile Image
                if !client.clientImage.isEmpty {
                    ClientImageView(imageUrl: client.clientImage, size: 80)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.gray.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Text(client.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .frame(width: 128, height: 128)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Session List Card
struct SessionListCard: View {
    let title: String
    let sessions: [Session]
    let showAddButton: Bool
    let onAddTapped: () -> Void
    let clientId: String
    let client: Client
    @State private var showingDeleteAlert = false
    @ObservedObject var dataManager = DataManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(title: title, showAddButton: showAddButton, onAddTapped: onAddTapped)
            SessionListView(sessions: sessions)
        }
    }
}

struct HeaderView: View {
    let title: String
    let showAddButton: Bool
    let onAddTapped: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if showAddButton {
                Button(action: onAddTapped) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(Colors.nasmBlue)
                        .font(.system(size: 20))
                        .padding(.horizontal, 8)
                }
            }
        }
    }
}

struct SessionListView: View {
    let sessions: [Session]
    
    var body: some View {
        ForEach(sessions) { session in
            SessionRowView(session: session)
        }
    }
}

struct SessionRowView: View {
    let session: Session
    @State private var showingSessionDetail = false
    
    var body: some View {
        Button(action: { showingSessionDetail = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.workoutName)
                        .font(.headline)
                        .foregroundColor(session.isCompleted ? .gray : .primary)
                    
                    if let date = session.completedDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(session.exercises.count) exercises")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if session.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(session.isCompleted ? Color(.systemGray6) : Color.white)
                    .shadow(color: .black.opacity(session.isCompleted ? 0.02 : 0.05), 
                           radius: session.isCompleted ? 2 : 4, 
                           x: 0, 
                           y: session.isCompleted ? 1 : 2)
            )
            .opacity(session.isCompleted ? 0.8 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingSessionDetail) {
            SessionDetailView(session: session)
        }
    }
}



struct NutritionSectionModel {
    let title: String
    let items: [String]
}

// Premium Metric Pill
struct PremiumMetricPill: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Colors.nasmBlue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Colors.nasmBlue.opacity(0.1), lineWidth: 1)
        )
    }
}

// Keep this version in Components.swift
struct SessionsListView: View {
    let client: Client
    @Binding var showingAddSession: Bool
    @ObservedObject var dataManager = DataManager.shared
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Add Button
            HStack {
                Text("Training Sessions")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSession = true }) {
                    Label("Add Session", systemImage: "plus.circle.fill")
                        .foregroundColor(Colors.nasmBlue)
                }
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                if let sessions = client.sessions {
                    if sessions.isEmpty {
                        Text("No sessions yet")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        // Active Sessions
                        let activeSessions = sessions.filter { !$0.isCompleted }
                        if !activeSessions.isEmpty {
                            ForEach(activeSessions) { session in
                                SessionRowView(session: session)
                            }
                        }
                        
                        // Completed Sessions
                        let completedSessions = sessions.filter { $0.isCompleted }
                        if !completedSessions.isEmpty {
                            Text("Completed")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.top, 24)
                            
                            ForEach(completedSessions) { session in
                                SessionRowView(session: session)
                            }
                        }
                    }
                }
            }
        }
        .task {
            await fetchSessions()
        }
        .onChange(of: showingAddSession) { oldValue, newValue in
            if !newValue {
                Task {
                    await fetchSessions()
                }
            }
        }
    }
    
    private func fetchSessions() async {
        isLoading = true
        do {
            try await dataManager.fetchClientSessions(for: client)
        } catch {
            print("Error fetching sessions:", error)
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Info Section
struct InfoSection: View {
    let title: String
    @Binding var text: String
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            
            if isEditing {
                TextEditor(text: $text)
                    .frame(height: 60)
                    .font(.body.bold())
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                    .tint(Colors.nasmBlue)
            } else {
                Text(text.isEmpty ? "Not specified" : text)
                    .font(.body.bold())
                    .foregroundColor(text.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric View
struct MetricView: View {
    let title: String
    @Binding var value: String
    let unit: String
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.black)
            
            if isEditing {
                HStack(spacing: 4) {
                    TextField("0", text: $value)
                        .keyboardType(.decimalPad)
                        .font(.body.bold())
                        .multilineTextAlignment(.leading)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 40)
                        .foregroundColor(.black)
                        .tint(Colors.nasmBlue)
                    Text(unit)
                        .font(.body.bold())
                        .foregroundColor(.black)
                }
            } else {
                HStack(spacing: 4) {
                    Text(value)
                        .font(.body.bold())
                        .foregroundColor(.black)
                    Text(unit)
                        .font(.body.bold())
                        .foregroundColor(.black)
                }
            }
        }
    }
}

// MARK: - Nutrition Plan Editor
struct NutritionPlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showingError = false
    
    let client: Client
    
    var body: some View {
        NavigationStack {
            VStack {
                // Placeholder content for future AI nutrition feature
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50))
                        .foregroundColor(Colors.nasmBlue)
                    
                    Text("AI Nutrition Planning")
                        .font(.title2.bold())
                    
                    Text("This feature will use AI to generate personalized nutrition plans based on client goals and metrics.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // Placeholder metrics that might be used for AI
                    VStack(spacing: 12) {
                        MetricRow(title: "Height", value: "\(Int(client.height)) cm")
                        MetricRow(title: "Weight", value: "\(Int(client.weight)) kg")
                        MetricRow(title: "Goals", value: client.goals)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical, 32)
            }
            .background(Colors.background)
            .navigationTitle("Nutrition Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper view for the nutrition metrics
private struct MetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding()
            .background(Color.red)
            .cornerRadius(8)
            .padding(.horizontal)
    }
}

struct ComplexView: View {
    var body: some View {
        VStack {
            HStack {
                Text("Title")
                    .font(.largeTitle)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "gear")
                }
            }
            .padding()

            List {
                ForEach(0..<10) { item in
                    HStack {
                        Image(systemName: "star")
                        Text("Item \(item)")
                        Spacer()
                        Button(action: {}) {
                            Text("Action")
                        }
                    }
                }
            }
        }
    }
}

// When deleting a session, post notification with sessionId
func deleteSession(_ session: Session) {
    NotificationCenter.default.post(
        name: NSNotification.Name("DeleteSessionCard"),
        object: nil,
        userInfo: [
            "sessionId": session._id,
            "clientId": session.client
        ]
    )
}

struct ClientImageView: View {
    let imageUrl: String
    let size: CGFloat
    
    var body: some View {
        AsyncImage(url: URL(string: imageUrl)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .failure(_):
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.gray.opacity(0.3))
            @unknown default:
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
    }
}

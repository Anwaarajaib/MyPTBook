import SwiftUI
import PDFKit

// MARK: - User Profile Header
struct UserProfileHeader: View {
    @Binding var showingProfile: Bool
    @ObservedObject private var dataManager = DataManager.shared
    @State private var isLoadingProfile = false
    
    var body: some View {
        Button(action: { showingProfile = true }) {
            HStack {
                ProfileImageView(imageUrl: dataManager.userProfileImageUrl, size: 40)
                
                Text(dataManager.userName)
                    .font(.title2.bold())
                
                Spacer()
            }
            .padding()
            .background(Colors.background)
        }
        .buttonStyle(.plain)
        .task {
            await refreshProfile()
        }
        .onAppear {
            print("UserProfileHeader: Appeared with image URL:", dataManager.userProfileImageUrl ?? "none")
            // Add notification observer
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshUserProfile"),
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await refreshProfile()
                }
            }
        }
    }
    
    private func refreshProfile() async {
        do {
            isLoadingProfile = true
            let profile = try await APIClient.shared.getProfile()
            print("UserProfileHeader: Got profile response with image:", profile.profileImage ?? "none")
            
            await MainActor.run {
                if let imageUrl = profile.profileImage {
                    print("UserProfileHeader: Saving profile image URL:", imageUrl)
                    dataManager.saveProfileImageUrl(imageUrl)
                }
                isLoadingProfile = false
            }
        } catch {
            print("UserProfileHeader: Failed to refresh profile:", error)
            await MainActor.run {
                isLoadingProfile = false
            }
        }
    }
}

// MARK: - Client Card
struct ClientCard: View {
    let client: Client
    @ObservedObject var dataManager: DataManager
    
    var body: some View {
        NavigationLink(destination: ClientDetailView(dataManager: dataManager, client: client)) {
            VStack(spacing: 16) {
                // Profile Image Section
                if !client.clientImage.isEmpty {
                    AsyncImage(url: URL(string: client.clientImage)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        case .failure, .empty:
                            fallbackImageView
                        @unknown default:
                            fallbackImageView
                        }
                    }
                } else {
                    fallbackImageView
                }
                
                Text(client.name)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 34)
            .padding(.horizontal, 20)
            .frame(width: 128, height: 128)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    private var fallbackImageView: some View {
        Circle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .foregroundColor(Color.gray.opacity(0.5))
            )
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Session List Card
struct SessionListCard: View {
    let title: String
    let sessions: [Session]
    let showAddButton: Bool
    let onAddTapped: () -> Void
    let client: Client
    @ObservedObject var dataManager = DataManager.shared
    
    var sortedSessions: [Session] {
        // Sort sessions and add numbers
        sessions.enumerated().map { (index, session) in
            var numberedSession = session
            numberedSession.sessionNumber = index + 1  // Add session number
            return numberedSession
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if showAddButton {
                    if !sessions.isEmpty {
                        Button(action: shareSessionsPDF) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(Colors.nasmBlue)
                                .font(.system(size: 20))
                                .padding(.horizontal, 8)
                        }
                    }
                    Button(action: onAddTapped) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    }
                }
            }
            
            if sessions.isEmpty {
                Text("No \(title.lowercased())")
                    .foregroundColor(.gray)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRowView(session: session)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color.white)
                        
                        if session.id != sessions.last?.id {
                            Divider()
                                .foregroundColor(Color.gray.opacity(0.3))
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.vertical, 8)
        .tint(Colors.nasmBlue)
    }
    
    private func shareSessionsPDF() {
        if let pdfData = PDFGenerator.generateSessionsPDF(clientName: client.name, sessions: sessions) {
            let fileName = "MyPTbook_\(client.name.replacingOccurrences(of: " ", with: "_"))_Sessions.pdf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try pdfData.write(to: tempURL)
                let activityVC = UIActivityViewController(
                    activityItems: [tempURL],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = rootVC.view
                        popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2,
                                                  y: UIScreen.main.bounds.height / 2,
                                                  width: 0,
                                                  height: 0)
                        popover.permittedArrowDirections = []
                    }
                    rootVC.present(activityVC, animated: true)
                }
            } catch {
                print("Error saving PDF: \(error)")
            }
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

// MARK: - Session Row View
struct SessionRowView: View {
    let session: Session
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Session \(session.sessionNumber)")
                    .font(.headline)
                    .foregroundColor(session.isCompleted ? .gray : .black)
                
                Text(session.workoutName)
                    .font(.subheadline)
                    .foregroundColor(session.isCompleted ? .gray : .gray)
            }
            
            Spacer()
            
            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green.opacity(0.8))
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
        .opacity(session.isCompleted ? 0.8 : 1)
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
    
    var activeSessions: [Session] {
        client.sessions?.filter { !$0.isCompleted } ?? []
    }
    
    var completedSessions: [Session] {
        client.sessions?.filter { $0.isCompleted } ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SessionListCard(
                title: "Active Sessions",
                sessions: activeSessions,
                showAddButton: true,
                onAddTapped: { showingAddSession = true },
                client: client
            )
            
            if !completedSessions.isEmpty {
                SessionListCard(
                    title: "Completed Sessions",
                    sessions: completedSessions,
                    showAddButton: false,
                    onAddTapped: { },
                    client: client
                )
            }
        }
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
        Group {
            if imageUrl.isEmpty || !isValidUrl(imageUrl) {
                // Show default image for empty or invalid URLs
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.gray.opacity(0.3))
            } else {
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
                    case .failure:
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
    }
    
    private func isValidUrl(_ urlString: String) -> Bool {
        if let url = URL(string: urlString) {
            return url.scheme == "http" || url.scheme == "https"
        }
        return false
    }
}

// Add this new view
struct ProfileImageView: View {
    let imageUrl: String?
    let size: CGFloat
    @State private var loadError: Error?
    
    var body: some View {
        Group {
            if let url = imageUrl, !url.isEmpty {
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .empty:
                        fallbackImage
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    case .failure:
                        fallbackImage
                    @unknown default:
                        fallbackImage
                    }
                }
            } else {
                fallbackImage
            }
        }
    }
    
    private var fallbackImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.45, height: size * 0.45)
                    .foregroundColor(Color.gray.opacity(0.5))
            )
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Delete Button
struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(role: .destructive, action: action) {
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

// MARK: - Add Exercise Sheet
struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [Exercise]
    var onSave: ((Exercise) -> Void)? = nil
    
    @State private var exerciseName = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var groupType: Exercise.GroupType?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $exerciseName)
                    
                    TextField("Sets", text: $sets)
                        .keyboardType(.numberPad)
                    
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                }
                
                Section("Exercise Type") {
                    Picker("Type", selection: $groupType) {
                        Text("Regular").tag(Optional<Exercise.GroupType>.none)
                        Text("Superset").tag(Optional<Exercise.GroupType>.some(.superset))
                        Text("Circuit").tag(Optional<Exercise.GroupType>.some(.circuit))
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let exercise = Exercise(
                            _id: "",
                            exerciseName: exerciseName,
                            sets: Int(sets) ?? 0,
                            reps: Int(reps) ?? 0,
                            weight: 0,
                            time: nil,
                            groupType: groupType,
                            session: ""
                        )
                        
                        if let onSave = onSave {
                            // For SessionDetailView
                            onSave(exercise)
                        } else {
                            // For AddSessionView
                            exercises.append(exercise)
                        }
                        dismiss()
                    }
                    .disabled(exerciseName.isEmpty)
                }
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

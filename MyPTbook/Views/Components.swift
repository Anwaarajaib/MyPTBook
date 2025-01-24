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
                ProfileImageView(imageUrl: dataManager.userProfileImageUrl, 
                               size: DesignSystem.isIPad ? 80 : 40)
                
                Text(dataManager.userName)
                    .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 24 : 20, weight: .bold))
                
                Spacer()
            }
            .adaptivePadding(.all, DesignSystem.isIPad ? 24 : 16)
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
        guard !isLoadingProfile else { return }  // Prevent multiple simultaneous refreshes
        
        do {
            isLoadingProfile = true
            let profile = try await APIClient.shared.getProfile()
            
            // Batch UI updates together
            await MainActor.run {
                if let imageUrl = profile.profileImage {
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
    
    private let imageCache = NSCache<NSString, UIImage>()
    
    var body: some View {
        NavigationLink(destination: ClientDetailView(dataManager: dataManager, client: client)) {
            VStack(spacing: DesignSystem.adaptiveSize(8)) {
                Spacer()
                    .frame(height: DesignSystem.adaptiveSize(16))
                
                // Profile Image Section
                if !client.clientImage.isEmpty {
                    loadImage(from: client.clientImage)
                } else {
                    fallbackImageView
                }
                
                Text(client.name)
                    .font(DesignSystem.adaptiveFont(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
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
    }
    
    private var fallbackImageView: some View {
        Circle()
            .fill(Color.gray.opacity(0.1))
            .adaptiveFrame(width: DesignSystem.maxImageSize,
                          height: DesignSystem.maxImageSize)
            .overlay(
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .adaptiveFrame(width: DesignSystem.maxImageSize * 0.45, height: DesignSystem.maxImageSize * 0.45)
                    .foregroundColor(Color.gray.opacity(0.5))
            )
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func loadImage(from url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .adaptiveFrame(width: DesignSystem.maxImageSize,
                                 height: DesignSystem.maxImageSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .onAppear {
                        // Cache the image synchronously since asUIImage() is not async
                        if let uiImage = image.asUIImage() {
                            imageCache.setObject(uiImage, forKey: url as NSString)
                        }
                    }
            case .failure, .empty:
                if let cachedImage = imageCache.object(forKey: url as NSString) {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .adaptiveFrame(width: DesignSystem.maxImageSize,
                                     height: DesignSystem.maxImageSize)
                        .clipShape(Circle())
                } else {
                    fallbackImageView
                }
            @unknown default:
                fallbackImageView
            }
        }
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
    @State private var isLoading = false
    
    var sortedSessions: [Session] {
        // Sort sessions and add sequential numbers
        sessions.enumerated().map { (index, session) in
            var numberedSession = session
            // For completed sessions, start from 1
            // For active sessions, continue from where completed sessions left off
            let baseNumber = title == "Active Sessions" ? 
                (client.sessions?.filter { $0.isCompleted }.count ?? 0) : 0
            numberedSession.sessionNumber = baseNumber + index + 1
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
                    if !client.sessions.isNilOrEmpty {
                        Button(action: shareSessionsPDF) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(Colors.nasmBlue)
                                    .font(.system(size: 20))
                            }
                        }
                        .disabled(isLoading)
                        .frame(width: 44)
                        .padding(.horizontal, 8)
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
                LazyVStack(spacing: 0) {
                    ForEach(sortedSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRowView(session: session)
                                .id(session.id)
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
        Task {
            do {
                await MainActor.run { isLoading = true }
                
                // Get all sessions for the client, both active and completed
                let allSessions = client.sessions ?? []
                
                // Sort sessions by their original session number
                let sortedSessions = allSessions.sorted { 
                    ($0.sessionNumber, $0.isCompleted ? 0 : 1) < ($1.sessionNumber, $1.isCompleted ? 0 : 1)
                }
                
                // Generate PDF in background
                let pdfData = try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let data = PDFGenerator.generateSessionsPDF(clientName: client.name, 
                                                                 sessions: sortedSessions) {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(throwing: NSError(domain: "PDFGenerator", code: -1, 
                                userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"]))
                        }
                    }
                }
                
                // Create temporary file URL
                let fileName = "MyPTbook_\(client.name.replacingOccurrences(of: " ", with: "_"))_Sessions.pdf"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                try pdfData.write(to: tempURL)
                
                // Present share sheet on main thread
                await MainActor.run {
                    isLoading = false
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
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("Error generating PDF:", error.localizedDescription)
                }
            }
        }
    }
}

extension Optional where Wrapped == [Session] {
    var isNilOrEmpty: Bool {
        switch self {
        case .none:
            return true
        case .some(let array):
            return array.isEmpty
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
                .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 15 : 14, weight: .bold))
                .foregroundColor(.gray.opacity(0.9))
            
            if isEditing {
                HStack(spacing: 6) {
                    TextField("0", text: $value)
                        .keyboardType(.decimalPad)
                        .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 15 : 16, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: DesignSystem.adaptiveSize(45))
                        .foregroundColor(.black)
                        .tint(Colors.nasmBlue)
                    Text(unit)
                        .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 14 : 14, weight: .bold))
                        .foregroundColor(.gray.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                HStack(spacing: 6) {
                    Text(value)
                        .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 15 : 16, weight: .bold))
                        .foregroundColor(.black)
                    Text(unit)
                        .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 14 : 14, weight: .bold))
                        .foregroundColor(.gray.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 16 : 14, weight: .bold))
                .foregroundColor(.gray.opacity(0.9))
            
            if isEditing {
                TextEditor(text: $text)
                    .frame(height: 60)
                    .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 15 : 15, weight: .bold))
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                    .tint(Colors.nasmBlue)
            } else {
                Text(text.isEmpty ? "Not specified" : text)
                    .font(DesignSystem.adaptiveFont(size: DesignSystem.isIPad ? 15 : 15, weight: .bold))
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
    
    // Add image cache
    private static let imageCache = NSCache<NSString, UIImage>()
    
    var body: some View {
        Group {
            if let url = imageUrl, !url.isEmpty {
                AsyncImage(url: URL(string: url), transaction: .init(animation: .easeInOut)) { phase in
                    switch phase {
                    case .empty:
                        fallbackImage
                            .transition(.opacity)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: size, height: size)
                            )
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                            .transition(.opacity)
                            .onAppear {
                                // Cache the image synchronously
                                if let uiImage = image.asUIImage() {
                                    Self.imageCache.setObject(uiImage, forKey: url as NSString)
                                }
                            }
                    case .failure:
                        if let cachedImage = Self.imageCache.object(forKey: url as NSString) {
                            Image(uiImage: cachedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                        } else {
                            fallbackImage
                        }
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

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

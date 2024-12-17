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
            VStack(spacing: 16) {
                if let profileImage = client.profileImage {
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
}

// MARK: - Session List Card
struct SessionListCard: View {
    let title: String
    let sessions: [Session]
    let showAddButton: Bool
    let onAddTapped: () -> Void
    let clientId: UUID
    let client: Client
    @State private var showingDeleteAlert = false
    @ObservedObject var dataManager = DataManager.shared
    
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
                        
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
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
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session, clientId: clientId)
                        } label: {
                            SessionRowView(session: session, clientId: clientId)
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
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DeleteSessionCard"),
                    object: nil,
                    userInfo: [
                        "sessionNumbers": sessions.map { $0.sessionNumber },
                        "clientId": clientId
                    ]
                )
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete these sessions? This action cannot be undone.")
        }
        .tint(Colors.nasmBlue)
    }
    
    private func shareSessionsPDF() {
        if let client = dataManager.clients.first(where: { $0.id == clientId }),
           let pdfData = PDFGenerator.generateSessionsPDF(clientName: client.name, sessions: sessions) {
            
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

// MARK: - Session Row View
struct SessionRowView: View {
    let session: Session
    let clientId: UUID
    
    var body: some View {
        NavigationLink(destination: SessionDetailView(session: session, clientId: clientId)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session \(session.sessionNumber)")
                        .font(.headline)
                        .foregroundColor(session.isCompleted ? .gray : .black)
                    Text("\(session.exercises.count) exercises")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(session.isCompleted ? 0.5 : 0.6))
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
}

// Add this new view for the nutrition note popup
struct NutritionNoteView: View {
    @Binding var nutritionPlan: String
    @State private var tempNutritionPlan: String = ""
    @ObservedObject var dataManager: DataManager
    let client: Client
    @State private var isEditing = false
    @Binding var isPresented: Bool
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextEditorFocused: Bool
    
    init(nutritionPlan: Binding<String>, dataManager: DataManager, client: Client, isPresented: Binding<Bool>) {
        self._nutritionPlan = nutritionPlan
        self.dataManager = dataManager
        self.client = client
        self._isPresented = isPresented
        self._tempNutritionPlan = State(initialValue: nutritionPlan.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with leaf icon
            HStack {
                // Left side with icon and title
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [Colors.nasmBlue, Colors.nasmBlue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Nutrition Plan")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Only show Save button when editing
                if isEditing {
                    Button {
                        nutritionPlan = tempNutritionPlan
                        saveNutritionPlan()
                    } label: {
                        Text("Save")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Colors.nasmBlue)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    if isEditing {
                        editingView
                    } else {
                        nutritionCard
                    }
                }
                
                if !isEditing && !tempNutritionPlan.isEmpty {
                    Button(action: sharePDF) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Colors.nasmBlue)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .shadow(
                                        color: Color.black.opacity(0.1),
                                        radius: 8,
                                        x: 0,
                                        y: 4
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Colors.nasmBlue.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width - 48, 392))
        .frame(maxHeight: keyboardHeight > 0 ? 
            UIScreen.main.bounds.height * 0.5 :  // Smaller height when keyboard is shown
            UIScreen.main.bounds.height * 0.72    // Original height when keyboard is hidden
        )
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Colors.background)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -50)
        .onAppear {
            tempNutritionPlan = client.nutritionPlan
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeInOut(duration: 0.25)) {  // Added animation
                        keyboardHeight = keyboardFrame.height
                    }
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {  // Added animation
                    keyboardHeight = 0
                }
            }
        }
        .animation(.easeInOut, value: keyboardHeight)  // Added animation for keyboard height changes
        .ignoresSafeArea(.keyboard)
    }
    
    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            if tempNutritionPlan.isEmpty {
                EmptyNutritionView {
                    withAnimation {
                        isEditing = true
                        isTextEditorFocused = true
                    }
                }
            } else {
                // Content with improved formatting
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(parseNutritionSections(), id: \.title) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            // Section Header with icon
                            HStack(spacing: 12) {
                                Image(systemName: getSectionIcon(section.title))
                                    .font(.system(size: 20))
                                    .foregroundColor(Colors.nasmBlue)
                                
                                Text(section.title)
                                    .font(.headline)
                                    .foregroundColor(Colors.nasmBlue)
                            }
                            
                            Rectangle()
                                .fill(Colors.nasmBlue.opacity(0.2))
                                .frame(height: 1)
                            
                            // Section Items
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(formatSectionItems(section.items), id: \.self) { item in
                                    HStack(alignment: .top, spacing: 12) {
                                        // Simple bullet point
                                        Rectangle()
                                            .fill(Colors.nasmBlue.opacity(0.3))
                                            .frame(width: 4, height: 4)
                                            .padding(.top, 8)
                                        
                                        // Item content with original text
                                        Text(item)
                                            .font(.body)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    private var editingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextEditor(text: $tempNutritionPlan)
                .font(.body)
                .padding(16)
                .frame(height: keyboardHeight > 0 ? 300 : 550)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .focused($isTextEditorFocused)
            
            Text("Tip: Organize your plan with sections like 'Breakfast:', 'Lunch:', etc.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .ignoresSafeArea(.keyboard)
    }
    
    private func saveNutritionPlan() {
        Task {
            do {
                var updatedClient = client
                updatedClient.nutritionPlan = nutritionPlan
                try await dataManager.updateClient(updatedClient)
                
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshClientData"),
                        object: nil
                    )
                    isPresented = false
                }
            } catch {
                print("Error saving nutrition plan: \(error)")
                // You might want to add error handling UI here
            }
        }
    }
    
    private func parseNutritionSections() -> [NutritionSectionModel] {
        let lines = tempNutritionPlan.components(separatedBy: .newlines)
        var sections: [NutritionSectionModel] = []
        var currentTitle = "General"
        var currentItems: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.hasSuffix(":") {
                if !currentItems.isEmpty {
                    sections.append(NutritionSectionModel(title: currentTitle, items: currentItems))
                    currentItems = []
                }
                currentTitle = String(trimmed.dropLast())
            } else {
                currentItems.append(trimmed)
            }
        }
        
        if !currentItems.isEmpty {
            sections.append(NutritionSectionModel(title: currentTitle, items: currentItems))
        }
        
        return sections
    }
    
    private func getSectionIcon(_ title: String) -> String {
        switch title.lowercased() {
        case "breakfast": return "sun.rise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snacks": return "leaf.fill"
        case "supplements": return "pills.fill"
        case "pre-workout": return "figure.run"
        case "post-workout": return "figure.cooldown"
        default: return "fork.knife"
        }
    }
    
    private func formatSectionItems(_ items: [String]) -> [String] {
        return items.map { item in
            // Only remove bullet points, dashes, or asterisks from the start of the line
            item.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
        }
    }
    
    // Add this function to handle PDF sharing
    private func sharePDF() {
        if let pdfData = PDFGenerator.generateNutritionPDF(
            clientName: client.name,
            sections: parseNutritionSections()
        ) {
            // Create a temporary URL for the PDF with proper name
            let fileName = "MyPTbook_\(client.name.replacingOccurrences(of: " ", with: "_"))_NutritionPlan.pdf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try pdfData.write(to: tempURL)
                let activityVC = UIActivityViewController(
                    activityItems: [tempURL],  // Share the URL instead of data
                    applicationActivities: nil
                )
                
                // Get the root view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    // For iPad
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
    
    // Move EmptyNutritionView here as a nested private struct
    private struct EmptyNutritionView: View {
        let startEditing: () -> Void
        
        var body: some View {
            ZStack {
                // Background icons
                Group {
                    // Top row
                    Image(systemName: "carrot.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: -120, y: -80)
                        .rotationEffect(.degrees(-15))
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: 0, y: -100)
                        .rotationEffect(.degrees(5))
                    
                    Image(systemName: "apple.logo")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: 120, y: -80)
                        .rotationEffect(.degrees(15))
                    
                    // Middle section (around the button)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: -140, y: 0)
                        .rotationEffect(.degrees(-10))
                    
                    Image(systemName: "fish.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: 140, y: 0)
                        .rotationEffect(.degrees(10))
                    
                    // Lower middle
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: -100, y: 80)
                        .rotationEffect(.degrees(-20))
                    
                    Image(systemName: "basket.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: 100, y: 80)
                        .rotationEffect(.degrees(20))
                    
                    // Bottom row
                    Image(systemName: "apple.logo")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: -120, y: 160)
                        .rotationEffect(.degrees(-15))
                    
                    Image(systemName: "carrot.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: 0, y: 180)
                        .rotationEffect(.degrees(0))
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Colors.nasmBlue.opacity(0.15))
                        .offset(x: 120, y: 160)
                        .rotationEffect(.degrees(15))
                }
                
                // Main content
                VStack(spacing: 16) {
                    Spacer()  // Top spacer
                    Spacer()  // Additional spacer
                    Spacer()  // Additional spacer
                    Spacer()  // Even more spacing to push content lower
                    Spacer()  // One more for good measure
                    
                    Button(action: startEditing) {
                        Text("Add Nutrition Plan")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Colors.nasmBlue)
                            .cornerRadius(8)
                    }
                    
                    Spacer()  // Bottom spacer
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 40)
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
    
    var activeSessions: [Session] {
        client.sessions.filter { !$0.isCompleted }.sorted { $0.sessionNumber < $1.sessionNumber }
    }
    
    var completedSessions: [Session] {
        client.sessions.filter { $0.isCompleted }.sorted { $0.sessionNumber < $1.sessionNumber }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SessionListCard(
                title: "Active Sessions",
                sessions: activeSessions,
                showAddButton: true,
                onAddTapped: { showingAddSession = true },
                clientId: client.id,
                client: client
            )
            
            if !completedSessions.isEmpty {
                SessionListCard(
                    title: "Completed Sessions",
                    sessions: completedSessions,
                    showAddButton: false,
                    onAddTapped: { },
                    clientId: client.id,
                    client: client
                )
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
    @State private var tempNutritionPlan: String
    @State private var showingSections = false
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showingError = false
    
    let client: Client
    
    init(client: Client) {
        self.client = client
        _tempNutritionPlan = State(initialValue: client.nutritionPlan)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $tempNutritionPlan)
                    .font(.body)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding()
            }
            .background(Colors.background)
            .navigationTitle("Nutrition Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveNutritionPlan()
                        }
                    }
                    .disabled(isProcessing)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "An unknown error occurred")
            }
        }
    }
    
    private func saveNutritionPlan() async {
        guard !isProcessing else { return }
        
        await MainActor.run {
            isProcessing = true
            error = nil
        }
        
        do {
            var updatedClient = client
            updatedClient.nutritionPlan = tempNutritionPlan
            
            try await dataManager.updateClient(updatedClient)
            
            await MainActor.run {
                isProcessing = false
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshClientData"),
                    object: nil
                )
                dismiss()
            }
        } catch {
            await MainActor.run {
                isProcessing = false
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

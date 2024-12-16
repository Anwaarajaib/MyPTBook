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
                
                // Only Edit/Save Button
                Button {
                    if isEditing {
                        nutritionPlan = tempNutritionPlan
                        saveNutritionPlan()
                    }
                    withAnimation { isEditing.toggle() }
                } label: {
                    Text(isEditing ? "Save" : "Edit")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Colors.nasmBlue)
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
        .frame(maxHeight: UIScreen.main.bounds.height * 0.72)
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
        }
    }
    
    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            if tempNutritionPlan.isEmpty {
                EmptyNutritionView()
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
                .frame(minHeight: 300)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
            
            Text("Tip: Organize your plan with sections like 'Breakfast:', 'Lunch:', etc.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    private func saveNutritionPlan() {
        var updatedClient = client
        updatedClient.nutritionPlan = nutritionPlan
        if let index = dataManager.clients.firstIndex(where: { $0.id == client.id }) {
            dataManager.clients[index] = updatedClient
            dataManager.saveClients()
        }
        NotificationCenter.default.post(name: NSNotification.Name("RefreshClientData"), object: nil)
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

// Empty State View
struct EmptyNutritionView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    .linearGradient(
                        colors: [Colors.nasmBlue.opacity(0.7), Colors.nasmBlue.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Text("No nutrition plan added yet")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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

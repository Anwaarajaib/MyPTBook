import SwiftUI

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
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
            .frame(width: 150, height: 150)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if showAddButton {
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

import SwiftUI
import Foundation
import UIKit

struct ClientDetailView: View {
    @ObservedObject var dataManager: DataManager
    let client: Client
    @State private var showingAddSession = false
    @State private var isEditing = false
    
    // Edit mode states
    @State private var editedName: String = ""
    @State private var editedAge: String = ""
    @State private var editedHeight: String = ""
    @State private var editedWeight: String = ""
    @State private var editedMedicalHistory: String = ""
    @State private var editedGoals: String = ""
    @State private var editedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Increase top spacing to bring the card lower
                Color.clear.frame(height: 70)
                
                // White Card Section for Client Details
                VStack(spacing: 0) {
                    // Add a Spacer to move the profile image lower
                    Spacer().frame(height: 20) // Adjust this value to move the image lower
                    
                    // Profile Image Section
                    Button(action: { 
                        if isEditing {
                            showingActionSheet = true
                        }
                    }) {
                        ZStack {
                            if let displayImage = isEditing ? editedImage : client.profileImage {
                                Image(uiImage: displayImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: isEditing ? 100 : 80, height: isEditing ? 100 : 80)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: isEditing ? 100 : 80, height: isEditing ? 100 : 80)
                                    .foregroundColor(.gray)
                            }
                            
                            if isEditing {
                                Image(systemName: "camera")
                                    .font(.system(size: 18))
                                    .foregroundColor(Colors.nasmBlue)
                                    .padding(7)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
                                    .offset(x: 35, y: 35)
                            }
                        }
                    }
                    .disabled(!isEditing)
                    
                    // Client Details Group
                    Group {
                        if isEditing {
                            // Name
                            TextField("Name", text: $editedName)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            
                            // Metrics Row
                            HStack(spacing: 40) {
                                // Age
                                VStack(spacing: 4) {
                                    Text("Age")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    HStack(spacing: 4) {
                                        TextField("0", text: $editedAge)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.center)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 60)
                                        Text("years")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                // Height
                                VStack(spacing: 4) {
                                    Text("Height")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    HStack(spacing: 4) {
                                        TextField("0.0", text: $editedHeight)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.center)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 60)
                                        Text("cm")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                // Weight
                                VStack(spacing: 4) {
                                    Text("Weight")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    HStack(spacing: 4) {
                                        TextField("0.0", text: $editedWeight)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.center)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 60)
                                        Text("kg")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Medical History Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Medical History")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                TextEditor(text: $editedMedicalHistory)
                                    .frame(height: 100)
                                    .padding(4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .padding(.top, 8)
                            
                            // Goals Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goals")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                TextEditor(text: $editedGoals)
                                    .frame(height: 100)
                                    .padding(4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        } else {
                            // Keep the existing non-editing view code
                            // Name Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text(client.name)
                                    .font(.body)
                            }
                            .padding(.top, 24)
                            
                            // Age, Height, Weight Section
                            HStack(spacing: 16) {
                                // Age
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Age")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    if isEditing {
                                        TextField("Age", text: $editedAge)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .keyboardType(.numberPad)
                                    } else {
                                        Text("\(client.age)")
                                            .font(.body)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Height
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Height (cm)")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    if isEditing {
                                        TextField("Height", text: $editedHeight)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .keyboardType(.decimalPad)
                                    } else {
                                        Text(String(format: "%.1f", client.height))
                                            .font(.body)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Weight
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Weight (kg)")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    if isEditing {
                                        TextField("Weight", text: $editedWeight)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .keyboardType(.decimalPad)
                                    } else {
                                        Text(String(format: "%.1f", client.weight))
                                            .font(.body)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.top, 16)
                            
                            // Medical History Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Medical History")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                if isEditing {
                                    TextEditor(text: $editedMedicalHistory)
                                        .frame(height: 100)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                } else {
                                    Text(client.medicalHistory)
                                        .font(.body)
                                }
                            }
                            .padding(.top, 16)
                            
                            // Goals Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goals")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                if isEditing {
                                    TextEditor(text: $editedGoals)
                                        .frame(height: 100)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                } else {
                                    Text(client.goals)
                                        .font(.body)
                                }
                            }
                            .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Active Sessions Section
                if !isEditing {
                    SessionsListView(client: client, showingAddSession: $showingAddSession)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Colors.background)
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if isEditing {
                            saveChanges()
                        } else {
                            startEditing()
                        }
                        isEditing.toggle()
                    }
                }
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingAddSession) {
            AddSessionView(client: client)
        }
        .confirmationDialog("Change Profile Picture", isPresented: $showingActionSheet) {
            Button("Take Photo") {
                showingCamera = true
            }
            Button("Choose from Library") {
                showingImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $editedImage, sourceType: .photoLibrary)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(image: $editedImage, sourceType: .camera)
        }
    }
    
    private func startEditing() {
        editedName = client.name
        editedAge = String(client.age)
        editedHeight = String(format: "%.1f", client.height)
        editedWeight = String(format: "%.1f", client.weight)
        editedMedicalHistory = client.medicalHistory
        editedGoals = client.goals
        editedImage = client.profileImage
    }
    
    private func saveChanges() {
        var updatedClient = client
        updatedClient.name = editedName
        updatedClient.age = Int(editedAge) ?? client.age
        updatedClient.height = Double(editedHeight) ?? client.height
        updatedClient.weight = Double(editedWeight) ?? client.weight
        updatedClient.medicalHistory = editedMedicalHistory
        updatedClient.goals = editedGoals
        updatedClient.profileImage = editedImage
        
        // Update the client in DataManager
        if let index = dataManager.clients.firstIndex(where: { $0.id == client.id }) {
            dataManager.clients[index] = updatedClient
            dataManager.saveClients()
        }
    }
}

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
                title: "ACTIVE SESSIONS",
                sessions: activeSessions,
                showAddButton: true,
                onAddTapped: { showingAddSession = true }
            )
            
            if !completedSessions.isEmpty {
                SessionListCard(
                    title: "COMPLETED SESSIONS",
                    sessions: completedSessions,
                    showAddButton: false,
                    onAddTapped: {}
                )
            }
        }
    }
} 

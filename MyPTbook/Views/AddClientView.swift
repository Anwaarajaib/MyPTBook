import SwiftUI
import PhotosUI

struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataManager: DataManager
    
    @State private var name = ""
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var medicalHistory = ""
    @State private var goals = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Add some top spacing
                    Color.clear.frame(height: 70)
                    
                    // White Card Section
                    VStack(spacing: 8) {
                        // Profile Image
                        ZStack {
                            if let profileImage = selectedImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                            }
                            
                            Image(systemName: "camera")
                                .font(.system(size: 18))
                                .foregroundColor(Colors.nasmBlue)
                                .padding(7)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
                                .offset(x: 35, y: 35)
                                .onTapGesture {
                                    showingActionSheet = true
                                }
                        }
                        
                        // Name
                        TextField("Name", text: $name)
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
                                    TextField("0", text: $age)
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
                                    TextField("0.0", text: $height)
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
                                    TextField("0.0", text: $weight)
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
                            TextEditor(text: $medicalHistory)
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
                            TextEditor(text: $goals)
                                .frame(height: 100)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 16)
            }
            .background(Colors.background)
            .ignoresSafeArea()
            .navigationTitle("Add Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        saveClient()
                    }
                    .disabled(name.isEmpty)
                }
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
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
        }
    }
    
    private func saveClient() {
        let newClient = Client(
            name: name,
            age: Int(age) ?? 0,
            height: Double(height) ?? 0.0,
            weight: Double(weight) ?? 0.0,
            medicalHistory: medicalHistory,
            goals: goals,
            sessions: [],
            profileImage: selectedImage
        )
        
        dataManager.addClient(newClient)
        dismiss()
    }
}

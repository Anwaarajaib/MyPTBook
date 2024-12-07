import SwiftUI
import PhotosUI

struct TrainerProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var profileImage: UIImage?
    
    @State private var tempName: String
    @State private var tempImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    @State private var isEditing = false
    @State private var isAuthenticated: Bool = true
    
    init(name: Binding<String>, profileImage: Binding<UIImage?>) {
        self._name = name
        self._profileImage = profileImage
        _tempName = State(initialValue: name.wrappedValue)
        _tempImage = State(initialValue: profileImage.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Main content container
                    VStack(spacing: 24) {
                        // Profile Image Section
                        Button(action: { 
                            // Do nothing when clicking the image
                        }) {
                            if let profileImage = tempImage {
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
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray.opacity(0.5))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                        .overlay(
                            Group {
                                if isEditing {
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
                            }
                        )
                        
                        // Name Section
                        VStack(alignment: .center, spacing: 8) {
                            if isEditing {
                                TextField("Enter your name", text: $tempName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                   } else {
                                Text(tempName.isEmpty ? name : tempName) 
                                    .font(.title2)
                                    .foregroundColor(.black) // Ensure the color is consistent
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    Button(action: {
                        // Perform logout
                        APIClient.shared.logout()
                        isAuthenticated = false
                        // Clear any temporary data
                        tempName = ""
                        tempImage = nil
                        dismiss()
                    }) {
                        Text("Logout")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(20)
            }
            .background(Colors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            name = tempName
                            profileImage = tempImage
                            DataManager.shared.saveTrainerName(tempName)
                            DataManager.shared.saveTrainerImage(tempImage)
                            dismiss()
                        }
                        withAnimation {
                            isEditing.toggle()
                        }
                    }
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
                ImagePicker(image: $tempImage, sourceType: .photoLibrary)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(image: $tempImage, sourceType: .camera)
            }
        }
    }
}

// Image Picker struct to handle camera and photo library
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
    }
} 

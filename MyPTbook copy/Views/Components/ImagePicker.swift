import SwiftUI
import UIKit
import AVFoundation

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        // Check if the source type is available
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
            
            // If using camera, check permission
            if sourceType == .camera {
                checkCameraPermission { granted in
                    if !granted {
                        DispatchQueue.main.async {
                            alertMessage = "Camera access is required. Please enable it in Settings."
                            showAlert = true
                            dismiss()
                        }
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                alertMessage = "This device doesn't support the selected image source."
                showAlert = true
                dismiss()
            }
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("ImagePicker Coordinator: Image selected")
            if let image = info[.originalImage] as? UIImage {
                print("ImagePicker Coordinator: Processing image of size: \(image.size)")
                // Update on main thread immediately
                self.parent.image = image
                print("ImagePicker Coordinator: Image assigned to binding")
                
                // Dismiss first, then update UI
                parent.dismiss()
            } else {
                print("ImagePicker Coordinator: Failed to get image from picker")
                parent.dismiss()
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("ImagePicker Coordinator: Picker cancelled")
            parent.dismiss()
        }
    }
}
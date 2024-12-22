import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Create Account")
                .font(.title2.bold())
                .foregroundColor(Colors.nasmBlue)
            
            VStack(spacing: 16) {
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.name)
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                
                Button(action: register) {
                    Text("Register")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Colors.nasmBlue)
                        .cornerRadius(10)
                }
                .disabled(!isValidForm)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Registration Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isValidForm: Bool {
        !name.isEmpty &&
        !email.isEmpty && 
        !password.isEmpty && 
        password == confirmPassword &&
        password.count >= 6
    }
    
    private func register() {
        Task {
            do {
                try await authManager.register( name: name,email: email, password: password)
                // Registration successful, dismiss the view
                dismiss()
            } catch {
                await MainActor.run {
                    switch error {
                    case APIError.validationError(let errors):
                        alertMessage = errors.joined(separator: "\n")
                    case APIError.serverError(let message):
                        alertMessage = message
                    default:
                        alertMessage = error.localizedDescription
                    }
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthManager.shared)
    }
} 
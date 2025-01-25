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
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case name, email, password, confirmPassword
    }
    
    var body: some View {
        ZStack {
            // Background gradient with tap gesture
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "003B7E"), Color(hex: "001A3A")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .onTapGesture {
                focusedField = nil // Dismiss keyboard
            }
            
            VStack(spacing: 10) {
                Image("Trainer-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)
                    .padding(.top, -30)
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(.white.opacity(0.7))
                        TextField("Name", text: $name)
                            .textContentType(.name)
                            .foregroundColor(.white)
                            .font(.system(size: 12, weight: .bold))
                            .placeholder(when: name.isEmpty) {
                                Text("Name")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .focused($focusedField, equals: .name)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                    
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.white.opacity(0.7))
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .foregroundColor(.white)
                            .font(.system(size: 12, weight: .bold))
                            .placeholder(when: email.isEmpty) {
                                Text("Email")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .focused($focusedField, equals: .email)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                    
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.white.opacity(0.7))
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                            .foregroundColor(.white)
                            .font(.system(size: 12, weight: .bold))
                            .placeholder(when: password.isEmpty) {
                                Text("Password")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .focused($focusedField, equals: .password)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                    
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.white.opacity(0.7))
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .foregroundColor(.white)
                            .font(.system(size: 12, weight: .bold))
                            .placeholder(when: confirmPassword.isEmpty) {
                                Text("Confirm Password")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .focused($focusedField, equals: .confirmPassword)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                    
                    Button(action: register) {
                        Text("REGISTER ACCOUNT")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .background(
                        Color.white.opacity(isValidForm ? 0.2 : 0.1)
                    )
                    .cornerRadius(10)
                    .opacity(isValidForm ? 1 : 0.5)
                    .disabled(!isValidForm)
                }
                .padding(.horizontal)
            }
            .padding(.top, -20)
            .padding(.horizontal)
        }
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
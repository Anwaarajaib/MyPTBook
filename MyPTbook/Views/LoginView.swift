import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo or App Name
                Text("MyPTbook")
                    .font(.largeTitle.bold())
                    .foregroundColor(Colors.nasmBlue)
                
                // Login Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)
                    
                    Button(action: login) {
                        Text("Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Colors.nasmBlue)
                            .cornerRadius(10)
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 32)
                
                // Register Button
                Button {
                    showingRegister = true
                } label: {
                    Text("Don't have an account? Register")
                        .foregroundColor(Colors.nasmBlue)
                }
            }
            .padding(.vertical, 40)
            .navigationDestination(isPresented: $showingRegister) {
                RegisterView()
                    .environmentObject(authManager)
            }
            .alert("Login Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        // action
                    }
                    .foregroundColor(Colors.nasmBlue)
                }
            }
        }
    }
    
    private func login() {
        Task {
            do {
                try await authManager.login(email: email, password: password)
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
} 

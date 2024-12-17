import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Logo or App Name
                Text("MyPTbook")
                    .font(.largeTitle.bold())
                    .foregroundColor(Colors.nasmBlue)
                
                // Login Form
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)
                    
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Login")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Colors.nasmBlue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal)
                
                // Register Link
                NavigationLink("Don't have an account? Register") {
                    RegisterView()
                }
                .foregroundColor(Colors.nasmBlue)
            }
            .padding()
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func login() {
        isLoading = true
        
        Task {
            do {
                print("Attempting login with email:", email)
                let token = try await APIClient.shared.login(email: email, password: password)
                print("Login successful, token received:", token)
                
                await MainActor.run {
                    authManager.isAuthenticated = true
                    DataManager.shared.saveAuthToken(token)
                }
            } catch {
                print("Login error:", error)
                await MainActor.run {
                    isLoading = false
                    alertMessage = handleError(error)
                    showingAlert = true
                }
            }
        }
    }
    
    private func handleError(_ error: Error) -> String {
        print("Handling error:", error)
        switch error {
        case APIError.unauthorized:
            return "Invalid email or password"
        case APIError.networkError(let error as URLError):
            return "Network error: \(error.localizedDescription)"
        case APIError.serverError(let message):
            return "Server error: \(message)"
        case APIError.validationError(let errors):
            return errors.joined(separator: "\n")
        default:
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
} 

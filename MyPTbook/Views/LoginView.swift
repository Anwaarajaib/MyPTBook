import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("MyPTbook")
                    .font(.largeTitle)
                    .foregroundColor(Colors.nasmBlue)
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if let error = error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .transition(.opacity)
                }
                
                Button(action: login) {
                    HStack {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Login")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Colors.nasmBlue)
                .disabled(isLoading || !isLoginValid)
                
                NavigationLink(destination: RegisterView(isLoggedIn: $isLoggedIn)) {
                    Text("Create Account")
                        .foregroundColor(Colors.nasmBlue)
                }
            }
            .padding()
            .animation(.default, value: error)
        }
    }
    
    private var isLoginValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 // Minimum password length
    }
    
    private func login() {
        guard isLoginValid else {
            error = "Please enter a valid email and password"
            return
        }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let token = try await APIClient.shared.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
                
                await MainActor.run {
                    DataManager.shared.saveAuthToken(token)
                    
                    isLoggedIn = true
                    isLoading = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    handleLoginError(error)
                }
            } catch {
                await MainActor.run {
                    self.error = "An unexpected error occurred: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func handleLoginError(_ error: APIError) {
        switch error {
        case .unauthorized:
            self.error = "Invalid email or password"
        case .validationError(let errors):
            self.error = errors.joined(separator: "\n")
        case .networkError(let underlyingError as URLError):
            switch underlyingError.code {
            case .notConnectedToInternet:
                self.error = "No internet connection. Please check your connection and try again."
            case .timedOut:
                self.error = "Request timed out. Please try again."
            case .cannotConnectToHost:
                self.error = "Cannot connect to server. Please try again later."
            default:
                self.error = "Network error: \(underlyingError.localizedDescription)"
            }
        case .serverError(let message):
            self.error = message
        default:
            self.error = "An unexpected error occurred"
        }
        isLoading = false
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
} 

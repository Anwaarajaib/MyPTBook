import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var error: String?
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Register")
                    .font(.largeTitle)
                    .foregroundColor(Colors.nasmBlue)
                
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: register) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Register")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Colors.nasmBlue)
                .disabled(isLoading || email.isEmpty || password.isEmpty || name.isEmpty)
                
                Button("Already have an account? Login") {
                    dismiss()
                }
                .foregroundColor(Colors.nasmBlue)
            }
            .padding()
        }
    }
    
    private func register() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let token = try await APIClient.shared.register(email: email, password: password, name: name)
                await MainActor.run {
                    DataManager.shared.saveAuthToken(token)
                    isLoggedIn = true
                }
            } catch let error as APIError {
                await MainActor.run {
                    switch error {
                    case .validationError(let errors):
                        self.error = errors.joined(separator: "\n")
                    case .networkError(let underlyingError as URLError):
                        switch underlyingError.code {
                        case .notConnectedToInternet:
                            self.error = "No internet connection. Please check your connection and try again."
                        case .timedOut:
                            self.error = "Request timed out. Please try again."
                        case .cannotConnectToHost:
                            self.error = """
                            Cannot connect to server. Please ensure:
                            1. The backend server is running
                            2. Port 5001 is available
                            3. You're connected to the internet
                            """
                        default:
                            self.error = "Network error: \(underlyingError.localizedDescription)"
                        }
                    case .serverError(let message):
                        self.error = message
                    default:
                        self.error = "Registration failed. Please try again."
                    }
                    isLoading = false
                }
            }
        }
    }
} 
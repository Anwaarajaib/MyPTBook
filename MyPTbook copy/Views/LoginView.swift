import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var dataManager = DataManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
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
                    
                    Text("Your Personal Training Book")
                        .font(.title3.bold())
                        .foregroundColor(.white.opacity(0.8))
                    
                    VStack(spacing: 16) {
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
                                .textContentType(.password)
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
                        
                        Button(action: login) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("LOGIN")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(
                            Color.white.opacity(isLoading || email.isEmpty || password.isEmpty ? 0.1 : 0.2)
                        )
                        .cornerRadius(10)
                        .opacity(isLoading || email.isEmpty || password.isEmpty ? 0.5 : 1)
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                    }
                    .padding(.horizontal)
                    
                    NavigationLink("Don't have an account? Register") {
                        RegisterView()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .padding(.bottom, 1)
                    .background(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(.white)
                            .offset(y: 7)
                    )
                    .padding(.top, 10)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .navigationDestination(isPresented: $authManager.isAuthenticated) {
                MainAppView()
                    .navigationBarBackButtonHidden()
            }
        }
    }
    
    private func login() {
        guard !isLoading else { return }
        isLoading = true
        print("LoginView: Attempting login with email:", email)
        
        Task {
            do {
                print("LoginView: Starting login process...")
                let response = try await APIClient.shared.login(email: email, password: password)
                print("LoginView: Login successful")
                print("LoginView: Profile image URL:", response.user.profileImage ?? "none")
                
                await MainActor.run {
                    dataManager.handleLoginSuccess(response: response)
                    isLoading = false
                    authManager.isAuthenticated = true
                }
            } catch {
                print("LoginView: Login error:", error)
                await MainActor.run {
                    isLoading = false
                    alertMessage = handleError(error)
                    showingAlert = true
                }
            }
        }
    }
    
    private func handleError(_ error: Error) -> String {
        print("LoginView: Handling error:", error)
        switch error {
        case APIError.unauthorized:
            return "Invalid email or password"
        case APIError.networkError(let urlError as URLError):
            switch urlError.code {
            case .timedOut:
                return "Request timed out. Please try again."
            case .notConnectedToInternet:
                return "No internet connection. Please check your connection and try again."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        case APIError.serverError(let message):
            return "Server error: \(message)"
        case APIError.validationError(let errors):
            return errors.joined(separator: "\n")
        case APIError.decodingError:
            return "Error processing server response. Please try again."
        default:
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
} 

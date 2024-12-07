//
//  ContentView.swift
//  MyPTbook
//
//  Created by Mohammed Anwaar Ajaib on 26/11/2024.
//

import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var showingLogin = false
    @State private var showingRegister = false
    @State private var isCheckingAuth = true
    
    var body: some View {
        Group {
            if isCheckingAuth {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if isAuthenticated {
                MainAppView()
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    
                    // Custom app logo/icon
                    Image("trainer-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .padding(.bottom, 20)
                    
                    Text("MyPTbook")
                        .font(.largeTitle.bold())
                    
                    Text("Your Personal Training Assistant")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Login Button Card
                    Button(action: {
                        showingLogin = true
                    }) {
                        Text("Login")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Colors.nasmBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .sheet(isPresented: $showingLogin) {
                        LoginView(isLoggedIn: $isAuthenticated)
                    }
                    
                    // Register Button Card
                    Button(action: {
                        showingRegister = true
                    }) {
                        Text("Register")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Colors.nasmBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .sheet(isPresented: $showingRegister) {
                        RegisterView(isLoggedIn: $isAuthenticated)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .task {
            await checkAuthenticationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LogoutNotification"))) { _ in
            isAuthenticated = false
            showingLogin = false
        }
    }
    
    private func checkAuthenticationStatus() async {
        isCheckingAuth = true
        
        if DataManager.shared.getAuthToken() != nil {
            do {
                let isValid = try await APIClient.shared.verifyToken()
                await MainActor.run {
                    isAuthenticated = isValid
                    if !isValid {
                        DataManager.shared.removeAuthToken()
                    }
                }
            } catch {
                // On error, if we have a token, keep the user logged in
                if DataManager.shared.getAuthToken() != nil {
                    await MainActor.run {
                        isAuthenticated = true
                    }
                } else {
                    await MainActor.run {
                        isAuthenticated = false
                    }
                }
            }
        } else {
            await MainActor.run {
                isAuthenticated = false
            }
        }
        
        await MainActor.run {
            isCheckingAuth = false
        }
    }
}

#Preview {
    ContentView()
}

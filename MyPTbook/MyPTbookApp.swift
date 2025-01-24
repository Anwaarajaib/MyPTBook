//
//  MyPTbookApp.swift
//  MyPTbook
//
//  Created by Mohammed Anwaar Ajaib on 26/11/2024.
//

import SwiftUI

@main
struct MyPTbookApp: App {
    @StateObject private var authManager = AuthManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView(steps: onboardingSteps) { 
                    hasCompletedOnboarding = true
                }
            } else if authManager.isAuthenticated {
                MainAppView()
            } else {
                LoginView()
            }
        }
    }
    
    private var onboardingSteps: [OnboardingStep] {
        [
            OnboardingStep(
                imageName: "clients",
                title: "Manage Your Clients",
                description: "Keep records of all your clients' information, and training programs in one place."
            ),
            OnboardingStep(
                imageName: "sessions",
                title: "Create/Manage Sessions",
                description: "Create and manage workout sessions, record weights, and share with your clients."
            ),
            OnboardingStep(
                imageName: "nutrition",
                title: "Nutrition Plans",
                description: "Design and share nutrition plans for your clients to help them achieve their goals."
            )
        ]
    }
}

//
//  MyPTbookApp.swift
//  MyPTbook
//
//  Created by Mohammed Anwaar Ajaib on 26/11/2024.
//

import SwiftUI

@main
struct MyPTbookApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainAppView()
                    .environmentObject(dataManager)
                    .environmentObject(authManager)
                    .accentColor(Colors.nasmBlue)
                    .tint(Colors.nasmBlue)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}

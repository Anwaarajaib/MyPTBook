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
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainAppView()
            } else {
                LoginView()
            }
        }
    }
}

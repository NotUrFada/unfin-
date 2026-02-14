//
//  AfterlightApp.swift
//  Unfin
//

import SwiftUI

@main
struct UnfinApp: App {
    @StateObject private var store = IdeaStore()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !store.isLoggedIn {
                    AuthView()
                } else if store.needsOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(store)
        }
    }
}

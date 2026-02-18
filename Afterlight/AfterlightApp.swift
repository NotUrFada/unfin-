//
//  AfterlightApp.swift
//  Unfin
//

import SwiftUI
import UIKit

/// Shown while session is being restored so we don’t show onboarding until we know the profile.
private struct LoadingSessionView: View {
    var body: some View {
        ZStack {
            Color(white: 0.12).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.2)
        }
    }
}

@main
struct UnfinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = IdeaStore()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !store.isLoggedIn {
                    AuthView()
                } else if !store.hasRestoredSession {
                    // Wait for profile load so we don’t flash onboarding for returning users.
                    LoadingSessionView()
                } else if store.needsOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(store)
            .task { await store.restoreSessionIfNeeded() }
            .onChange(of: store.isLoggedIn) { _, loggedIn in
                if !loggedIn { UIApplication.shared.applicationIconBadgeNumber = 0 }
            }
            .onChange(of: store.unreadNotificationCount) { _, count in
                guard store.isLoggedIn else { return }
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }
}

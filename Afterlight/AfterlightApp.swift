//
//  AfterlightApp.swift
//  Unfin
//

import SwiftUI
import UIKit

/// Brief splash shown at launch to set the tone before auth or main app.
private struct SplashView: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.92

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.08),
                    Color(red: 0.12, green: 0.12, blue: 0.14),
                    Color(red: 0.08, green: 0.08, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("UNFIN")
                    .font(.system(size: 36, weight: .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
                scale = 1
            }
        }
    }
}

/// Shown while session is being restored so we don't show onboarding until we know the profile.
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
    @AppStorage(appBackgroundStyleKey) private var backgroundStyleRaw: String = AppBackgroundStyle.gradient.rawValue
    @State private var showSplash = true

    private var preferredScheme: ColorScheme? {
        let style = AppBackgroundStyle(rawValue: backgroundStyleRaw) ?? .gradient
        switch style {
        case .white: return .light
        case .black, .gradient: return .dark
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if !store.isLoggedIn {
                        AuthView()
                    } else if !store.hasRestoredSession {
                        LoadingSessionView()
                    } else if store.needsOnboarding {
                        OnboardingView()
                    } else {
                        MainTabView()
                    }
                }
                .environmentObject(store)
                .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.35), value: showSplash)
            .preferredColorScheme(preferredScheme)
            .task { await store.restoreSessionIfNeeded() }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation { showSplash = false }
                }
            }
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

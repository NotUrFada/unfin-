//
//  MainTabView.swift
//  Unfin
//

import SwiftUI
import UIKit

enum Tab: String, CaseIterable {
    case home
    case explore
    case profile
}

struct MainTabView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: Tab = .home
    @State private var showCreateIdea = false

    private var isLight: Bool { colorScheme == .light }
    private var tabFg: Color { isLight ? Color(white: 0.12) : .white }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    FeedView(showCreateIdea: $showCreateIdea)
                case .explore:
                    ExploreView(showCreateIdea: $showCreateIdea)
                case .profile:
                    ProfileView(showCreateIdea: $showCreateIdea)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            bottomNavBar
        }
        .sheet(isPresented: $showCreateIdea) {
            CreateIdeaView()
                .environmentObject(store)
        }
        .onAppear {
            if store.isLoggedIn {
                UIApplication.shared.applicationIconBadgeNumber = store.unreadNotificationCount
                store.refreshUserProfileIfNeeded()
            }
        }
    }
    
    private var bottomNavBar: some View {
        HStack(spacing: 8) {
            ForEach([Tab.home, Tab.explore, Tab.profile], id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: iconForTab(tab))
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(selectedTab == tab ? tabFg : tabFg.opacity(0.6))
                            .background(selectedTab == tab ? tabFg.opacity(0.15) : Color.clear)
                            .clipShape(Circle())
                        if tab == .home, store.unreadNotificationCount > 0 {
                            Text("\(min(store.unreadNotificationCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(tabFg.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    private func iconForTab(_ tab: Tab) -> String {
        switch tab {
        case .home: return "house.fill"
        case .explore: return "square.grid.2x2.fill"
        case .profile: return "person.fill"
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(IdeaStore())
}

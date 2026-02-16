//
//  MainTabView.swift
//  Unfin
//

import SwiftUI

enum Tab: String, CaseIterable {
    case home
    case explore
    case profile
}

struct MainTabView: View {
    @EnvironmentObject var store: IdeaStore
    @State private var selectedTab: Tab = .home
    @State private var showCreateIdea = false
    
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
    }
    
    private var bottomNavBar: some View {
        HStack(spacing: 8) {
            ForEach([Tab.home, Tab.explore, Tab.profile], id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Image(systemName: iconForTab(tab))
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.6))
                        .background(selectedTab == tab ? Color.white.opacity(0.15) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    private func iconForTab(_ tab: Tab) -> String {
        switch tab {
        case .home: return "house.fill"
        case .explore: return "play.circle.fill"
        case .profile: return "person.fill"
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(IdeaStore())
}

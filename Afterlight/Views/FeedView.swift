//
//  FeedView.swift
//  Unfin
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject var store: IdeaStore
    @Binding var showCreateIdea: Bool
    var filterCategoryId: UUID? = nil
    
    @State private var selectedFilterId: UUID? = nil
    @State private var navigationPath = NavigationPath()
    @State private var showNotifications = false
    @State private var pendingIdeaIdToOpen: UUID?
    
    private var filteredIdeas: [Idea] {
        var list = store.ideas
        if let id = selectedFilterId ?? filterCategoryId {
            list = list.filter { $0.categoryId == id }
        }
        return list
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            feedContent
                .background(BackgroundGradientView())
                .navigationDestination(for: UUID.self) { id in
                    IdeaDetailView(ideaId: id)
                }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView(onSelectIdea: { id in
                pendingIdeaIdToOpen = id
                showNotifications = false
            })
            .environmentObject(store)
        }
        .onChange(of: showNotifications) { _, visible in
            if !visible, let id = pendingIdeaIdToOpen {
                navigationPath.append(id)
                pendingIdeaIdToOpen = nil
            }
        }
    }
    
    private var feedContent: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                filterTabs
                ScrollView {
                    feedList
                }
                .scrollIndicators(.visible, axes: .vertical)
                .frame(maxHeight: .infinity)
            }
            
            fabButton
        }
    }
    
    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                Text("UNFIN")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(Color.white)
            }
            Spacer()
            Button {
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white)
                    if store.unreadNotificationCount > 0 {
                        Text("\(min(store.unreadNotificationCount, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            Text(store.currentUserName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterTab(title: "For You", isSelected: selectedFilterId == nil) {
                    selectedFilterId = nil
                }
                ForEach(store.categories) { category in
                    FilterTab(title: category.displayName, isSelected: selectedFilterId == category.id) {
                        selectedFilterId = category.id
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .padding(.bottom, 10)
    }
    
    private var feedList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredIdeas) { idea in
                IdeaCardView(idea: idea) {
                    navigationPath.append(idea.id)
                }
            }
            Color.clear.frame(height: 100)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 120)
    }
    
    private var fabButton: some View {
        Button {
            showCreateIdea = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color(white: 0.1))
                .frame(width: 56, height: 56)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 32)
    }
}

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color(white: 0.12) : Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.white : Color.white.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}

struct BackgroundGradientView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.91, green: 0.91, blue: 0.91),
                Color(red: 0.75, green: 0.75, blue: 0.75),
                Color(red: 0.1, green: 0.1, blue: 0.1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    FeedView(showCreateIdea: .constant(false))
        .environmentObject(IdeaStore())
}

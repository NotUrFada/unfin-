//
//  FeedView.swift
//  Unfin
//

import SwiftUI

enum AppBackgroundStyle: String, CaseIterable {
    case black
    case white
    case gradient
    
    var displayName: String {
        switch self {
        case .black: return "Black"
        case .white: return "White"
        case .gradient: return "Gradient"
        }
    }
}

let appBackgroundStyleKey = "appBackgroundStyle"

struct FeedView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showCreateIdea: Bool
    var filterCategoryId: UUID? = nil

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }
    private var secondaryFg: Color { isLight ? Color(white: 0.35) : .white.opacity(0.9) }
    private var surfaceOpacity: Double { isLight ? 0.12 : 0.15 }

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
                    IdeaDetailView(ideaId: id, onOpenUserProfile: { name, authorId in
                        navigationPath.append(UserProfileDestination(displayName: name, authorId: authorId))
                    })
                }
                .navigationDestination(for: UserProfileDestination.self) { dest in
                    UserProfileView(displayName: dest.displayName, authorId: dest.authorId) { ideaId in
                        navigationPath.append(ideaId)
                    }
                    .environmentObject(store)
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
                    .foregroundStyle(primaryFg)
                if store.isLoggedIn && store.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text("\(store.currentStreak)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryFg)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(primaryFg.opacity(surfaceOpacity))
                    .clipShape(Capsule())
                }
            }
            Spacer()
            Button {
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(primaryFg)
                    if store.unreadNotificationCount > 0 {
                        Text("\(min(store.unreadNotificationCount, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 10, y: -10)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text(store.currentUserName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(primaryFg)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(primaryFg.opacity(0.2))
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
                IdeaCardView(idea: idea, onOpenUserProfile: { name, authorId in
                    navigationPath.append(UserProfileDestination(displayName: name, authorId: authorId))
                }) {
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
                .foregroundStyle(isLight ? Color.white : Color(white: 0.1))
                .frame(width: 56, height: 56)
                .background(isLight ? Color(white: 0.12) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 32)
    }
}

struct FilterTab: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? (isLight ? Color.white : Color(white: 0.12)) : primaryFg)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? primaryFg : primaryFg.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(primaryFg.opacity(0.1), lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}

struct BackgroundGradientView: View {
    @EnvironmentObject var store: IdeaStore
    @AppStorage(appBackgroundStyleKey) private var styleRaw: String = AppBackgroundStyle.gradient.rawValue

    private var style: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: styleRaw) ?? .gradient
    }

    private var auraColors: (Color, Color, Color)? {
        if let v = store.currentAccount?.auraVariant {
            return AuraConfig.from(variant: v).colors
        }
        if let p = store.currentAccount?.auraPaletteIndex {
            return AuraConfig.fromLegacy(paletteIndex: p).colors
        }
        return nil
    }

    var body: some View {
        Group {
            switch style {
            case .black:
                Color.black
            case .white:
                Color.white
            case .gradient:
                gradientContent
            }
        }
        .ignoresSafeArea()
    }

    private var gradientContent: some View {
        let useAura = auraColors != nil ? Float(1.0) : Float(0.0)
        let (c1, c2, c3) = auraColors ?? (
            Color(red: 0.06, green: 0.06, blue: 0.08),
            Color(red: 0.18, green: 0.18, blue: 0.2),
            Color(red: 0.38, green: 0.38, blue: 0.42)
        )
        return TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100)
            Color.black
                .layerEffect(
                    ShaderLibrary.noisyGradient(
                        .boundingRect,
                        .float(time),
                        .float(useAura),
                        .color(c1),
                        .color(c2),
                        .color(c3)
                    ),
                    maxSampleOffset: .zero
                )
        }
    }
}

#Preview {
    FeedView(showCreateIdea: .constant(false))
        .environmentObject(IdeaStore())
}

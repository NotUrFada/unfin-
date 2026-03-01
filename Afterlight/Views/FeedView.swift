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

enum FeedSort: String, CaseIterable {
    case newest = "Newest"
    case mostCompletions = "Most completions"
    case mostReactions = "Most reactions"
}

struct FeedView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showCreateIdea: Bool
    var filterCategoryId: UUID? = nil

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { AppTheme.Colors.primaryText(isLight: isLight) }
    private var secondaryFg: Color { AppTheme.Colors.secondaryText(isLight: isLight) }
    private var surfaceOpacity: Double { AppTheme.Colors.surfaceOpacity(isLight: isLight) }

    @State private var selectedFilterId: UUID? = nil
    @State private var feedSort: FeedSort = .newest
    @State private var navigationPath = NavigationPath()
    @State private var showNotifications = false
    @State private var pendingIdeaIdToOpen: UUID?
    
    /// Home feed shows only open ideas (finished ideas are hidden); hidden-by-user ideas are excluded.
    private var filteredIdeas: [Idea] {
        var list = store.ideas
            .filter { !store.hiddenIdeaIds.contains($0.id) }
            .filter { !$0.isFinished }
        if let id = selectedFilterId ?? filterCategoryId {
            list = list.filter { $0.categoryId == id }
        }
        switch feedSort {
        case .newest:
            list.sort { $0.createdAt > $1.createdAt }
        case .mostCompletions:
            list.sort { $0.contributions.count > $1.contributions.count }
        case .mostReactions:
            list.sort { $0.contributions.reduce(0) { $0 + $1.totalReactionCount } > $1.contributions.reduce(0) { $0 + $1.totalReactionCount } }
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
                sortPicker
                ScrollView {
                    feedList
                }
                .scrollIndicators(.visible, axes: .vertical)
                .refreshable {
                    await store.refreshContent()
                }
                .frame(maxHeight: .infinity)
            }

            fabButton
        }
    }
    
    private var header: some View {
        HStack {
            HStack(spacing: AppTheme.Spacing.sm) {
                UnfinWordmark(size: 15, color: primaryFg)
                if store.isLoggedIn && store.currentStreak > 0 {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.orange)
                        Text("\(store.currentStreak)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryFg)
                    }
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
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
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(primaryFg)
                    if store.unreadNotificationCount > 0 {
                        Text("\(min(store.unreadNotificationCount, 99))")
                            .font(AppTheme.Typography.labelSmall)
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
                .font(AppTheme.Typography.label)
                .foregroundStyle(primaryFg)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(primaryFg.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
        .padding(.top, AppTheme.Spacing.headerTop)
        .padding(.bottom, AppTheme.Spacing.headerBottom)
    }
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.md) {
                FilterTab(title: "For You", isSelected: selectedFilterId == nil) {
                    selectedFilterId = nil
                }
                ForEach(store.categories) { category in
                    FilterTab(title: category.displayName, isSelected: selectedFilterId == category.id) {
                        selectedFilterId = category.id
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
            .padding(.bottom, AppTheme.Spacing.sm)
        }
        .padding(.bottom, AppTheme.Spacing.sm + 2)
    }

    private var sortPicker: some View {
        Menu {
            ForEach(FeedSort.allCases, id: \.rawValue) { sort in
                Button {
                    feedSort = sort
                } label: {
                    HStack {
                        Text(sort.rawValue)
                        if feedSort == sort {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.xs) {
                Text("Sort: \(feedSort.rawValue)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(secondaryFg)
                Image(systemName: "chevron.down")
                    .font(AppTheme.Typography.labelSmall)
                    .foregroundStyle(secondaryFg)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 6)
            .background(primaryFg.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
        .padding(.bottom, AppTheme.Spacing.sm)
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
        .padding(.horizontal, AppTheme.Spacing.lg)
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
        .padding(.trailing, AppTheme.Spacing.screenHorizontal)
        .padding(.bottom, AppTheme.Spacing.xxl)
    }
}

struct FilterTab: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { AppTheme.Colors.primaryText(isLight: isLight) }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.bodySmall)
                .foregroundStyle(isSelected ? (isLight ? Color.white : Color(white: 0.1)) : primaryFg)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
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
        let (c1, c2, c3) = auraColors ?? AppTheme.Colors.defaultGradientDark
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

//
//  ExploreView.swift
//  Unfin
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showCreateIdea: Bool
    @State private var explorePath = NavigationPath()
    @State private var searchText = ""

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { AppTheme.Colors.primaryText(isLight: isLight) }
    private var secondaryFg: Color { AppTheme.Colors.secondaryText(isLight: isLight) }

    /// Explore shows all ideas (open and finished); only hidden ideas are excluded.
    private var visibleIdeas: [Idea] {
        store.ideas.filter { !store.hiddenIdeaIds.contains($0.id) }
    }

    private var searchResults: [Idea] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return [] }
        return visibleIdeas.filter {
            $0.content.lowercased().contains(q)
                || store.categoryDisplayName(byId: $0.categoryId).lowercased().contains(q)
        }
    }

    private var randomIdea: Idea? {
        visibleIdeas.randomElement()
    }

    /// Ideas that are still open (not marked finished) — good targets to complete.
    private var openIdeas: [Idea] {
        visibleIdeas.filter { !$0.isFinished }
    }

    private var randomOpenIdea: Idea? {
        openIdeas.randomElement()
    }

    var body: some View {
        NavigationStack(path: $explorePath) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        searchBar
                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            searchResultsSection
                        } else {
                            quickActionsSection
                            openForCompletionSection
                            discoverySection
                            categoryGrid
                        }
                    }
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await store.refreshContent()
                }
                .background(BackgroundGradientView())

                addButton
            }
            .navigationDestination(for: Category.self) { category in
                CategoryFeedView(category: category, showCreateIdea: $showCreateIdea, onOpenUserProfile: { name, authorId in
                    explorePath.append(UserProfileDestination(displayName: name, authorId: authorId))
                }) { ideaId in
                    explorePath.append(ideaId)
                }
            }
            .navigationDestination(for: UUID.self) { ideaId in
                IdeaDetailView(ideaId: ideaId, onOpenUserProfile: { name, authorId in
                    explorePath.append(UserProfileDestination(displayName: name, authorId: authorId))
                })
            }
            .navigationDestination(for: UserProfileDestination.self) { dest in
                UserProfileView(displayName: dest.displayName, authorId: dest.authorId) { ideaId in
                    explorePath.append(ideaId)
                }
                .environmentObject(store)
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Explore")
                    .font(AppTheme.Typography.titleLarge)
                    .tracking(-0.5)
                    .foregroundStyle(primaryFg)
                Spacer()
                UnfinWordmark(size: 12, color: secondaryFg)
            }
            .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
            .padding(.top, AppTheme.Spacing.headerTop)

            Text("Discover ideas that need your help.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(secondaryFg)
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                .padding(.top, AppTheme.Spacing.xs)
                .padding(.bottom, AppTheme.Spacing.sm)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(secondaryFg)
            TextField("Search ideas or categories", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(primaryFg)
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(primaryFg.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primaryFg)
                .padding(.horizontal, 24)
            if searchResults.isEmpty {
                Text("No ideas match \"\(searchText)\".")
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryFg)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(primaryFg.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(searchResults) { idea in
                        IdeaCardView(idea: idea, onOpenUserProfile: { name, authorId in
                            explorePath.append(UserProfileDestination(displayName: name, authorId: authorId))
                        }) {
                            explorePath.append(idea.id)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What do you want to do?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondaryFg)
                .padding(.horizontal, 24)
            HStack(spacing: AppTheme.Spacing.md) {
                if let open = randomOpenIdea {
                    Button {
                        explorePath.append(open.id)
                    } label: {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(primaryFg)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Complete one")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(primaryFg)
                                Text("Add your take")
                                    .font(.system(size: 12))
                                    .foregroundStyle(secondaryFg)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(secondaryFg)
                        }
                        .padding(AppTheme.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(primaryFg.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(primaryFg.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showCreateIdea = true
                } label: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(primaryFg)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share your own")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(primaryFg)
                            Text("Post an idea")
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryFg)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(secondaryFg)
                    }
                    .padding(AppTheme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(primaryFg.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(primaryFg.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 8)
    }

    private var openForCompletionSection: some View {
        Group {
            if !openIdeas.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Open for completion")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(primaryFg)
                        Text("\(openIdeas.count) ideas")
                            .font(.system(size: 13))
                            .foregroundStyle(secondaryFg)
                    }
                    .padding(.horizontal, 24)
                    Text("Add your voice or completion to any of these.")
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryFg)
                        .padding(.horizontal, 24)
                    LazyVStack(spacing: 12) {
                        ForEach(openIdeas.prefix(6)) { idea in
                            IdeaCardView(idea: idea, onOpenUserProfile: { name, authorId in
                                explorePath.append(UserProfileDestination(displayName: name, authorId: authorId))
                            }) {
                                explorePath.append(idea.id)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }
        }
    }

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let random = randomIdea {
                Button {
                    explorePath.append(random.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Surprise me")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(primaryFg)
                            Text("Discover a random idea")
                                .font(.system(size: 13))
                                .foregroundStyle(primaryFg.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(secondaryFg)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(primaryFg.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(primaryFg.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
    
    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by category")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(primaryFg)
                .padding(.horizontal, 24)
            VStack(spacing: 12) {
            ForEach(store.categories) { category in
                Button {
                    explorePath.append(category)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(primaryFg)
                            Text("\(count(for: category)) ideas")
                                .font(.system(size: 13))
                                .foregroundStyle(secondaryFg)
                        }
                        Spacer()
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(primaryFg.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(primaryFg.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func count(for category: Category) -> Int {
        visibleIdeas.filter { $0.categoryId == category.id }.count
    }
    
    private var addButton: some View {
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
        .padding(.bottom, 100)
    }
}

struct CategoryFeedView: View {
    let category: Category
    @Binding var showCreateIdea: Bool
    var onOpenUserProfile: ((String, UUID?) -> Void)? = nil
    var onSelectIdea: (UUID) -> Void
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }

    /// Category feed shows all ideas in this category (open and finished).
    private var visibleIdeas: [Idea] {
        store.ideas.filter { !store.hiddenIdeaIds.contains($0.id) }
    }

    private var ideas: [Idea] {
        visibleIdeas.filter { $0.categoryId == category.id }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(ideas) { idea in
                        IdeaCardView(idea: idea, onOpenUserProfile: onOpenUserProfile) {
                            onSelectIdea(idea.id)
                        }
                    }
                    if ideas.isEmpty {
                        Text("No \(category.displayName.lowercased()) ideas yet. Tap + to add one.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.primary.opacity(0.9))
                            .padding(24)
                            .frame(maxWidth: .infinity)
                    }
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .refreshable {
                await store.refreshContent()
            }
            .background(BackgroundGradientView())
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.12), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            
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
            .padding(.bottom, 100)
        }
    }
}

#Preview {
    ExploreView(showCreateIdea: .constant(false))
        .environmentObject(IdeaStore())
}

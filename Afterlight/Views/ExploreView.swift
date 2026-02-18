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

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }

    var body: some View {
        NavigationStack(path: $explorePath) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        categoryGrid
                    }
                    .padding(.bottom, 100)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Explore")
                .font(.system(size: 32, weight: .medium))
                .tracking(-0.03)
                .foregroundStyle(primaryFg)
                .padding(.horizontal, 24)
                .padding(.top, 56)

            Text("Browse ideas by category.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(primaryFg.opacity(0.95))
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 24)
        }
    }
    
    private var categoryGrid: some View {
        VStack(spacing: 12) {
            ForEach(store.categories) { category in
                Button {
                    explorePath.append(category)
                } label: {
                    HStack {
                        Image(systemName: iconForCategory(category))
                            .font(.system(size: 22))
                            .foregroundStyle(primaryFg.opacity(0.9))
                            .frame(width: 44, height: 44)
                            .background(primaryFg.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(primaryFg)
                            Text("\(count(for: category)) ideas")
                                .font(.system(size: 13))
                                .foregroundStyle(primaryFg.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(primaryFg.opacity(0.6))
                    }
                    .padding(20)
                    .background(primaryFg.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(primaryFg.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func count(for category: Category) -> Int {
        store.ideas.filter { $0.categoryId == category.id }.count
    }
    
    private func iconForCategory(_ category: Category) -> String {
        if category.id == Category.melodyId { return "waveform" }
        if category.id == Category.lyricsId { return "music.quarternote.3" }
        if category.id == Category.fictionId { return "book.fill" }
        if category.id == Category.conceptId { return "lightbulb.fill" }
        if category.id == Category.poetryId { return "text.quote" }
        return "tag.fill"
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

    private var ideas: [Idea] {
        store.ideas.filter { $0.categoryId == category.id }
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

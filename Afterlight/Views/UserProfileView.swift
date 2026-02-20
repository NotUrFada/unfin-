//
//  UserProfileView.swift
//  Unfin
//

import SwiftUI

/// Read-only profile for another user: avatar, display name, ideas they started.
struct UserProfileView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme

    let displayName: String
    let authorId: UUID?
    var onSelectIdea: (UUID) -> Void

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }
    private var secondaryFg: Color { isLight ? Color(white: 0.4) : Color.white.opacity(0.9) }

    private var ideasByUser: [Idea] {
        store.ideas.filter { idea in
            if let aid = authorId { return idea.authorId == aid }
            return idea.authorId == nil && idea.authorDisplayName == displayName
        }
    }

    private var contributionsByUserCount: Int {
        store.ideas.flatMap(\.contributions).filter { c in
            if let aid = authorId, let cid = c.authorId { return cid == aid }
            return c.authorDisplayName == displayName
        }.count
    }

    /// (Contribution, parent Idea) for this user's contributions.
    private var contributionsByUserWithIdeas: [(contribution: Contribution, idea: Idea)] {
        store.ideas.flatMap { idea in
            idea.contributions.compactMap { c -> (Contribution, Idea)? in
                let isTheirs = (authorId != nil && c.authorId == authorId) || c.authorDisplayName == displayName
                return isTheirs ? (c, idea) : nil
            }
        }
    }

    enum ProfileSegment { case ideas, contributions }
    @State private var selectedProfileSegment: ProfileSegment = .ideas

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if selectedProfileSegment == .ideas {
                        ideasSection
                    } else {
                        contributionsSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 160)
            }
            .clipped()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        let isCurrentUser = authorId == store.currentUserId
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                AuraAvatarView(
                    size: 52,
                    auraVariant: isCurrentUser ? store.currentAccount?.auraVariant : auraVariantForDisplayName(displayName),
                    legacyPaletteIndex: isCurrentUser ? store.currentAccount?.auraPaletteIndex : nil,
                    fallbackUserId: isCurrentUser ? store.currentUserId : nil,
                    fallbackDisplayName: displayName
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(primaryFg)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Button {
                        selectedProfileSegment = .ideas
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(ideasByUser.count)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(primaryFg)
                            Text("ideas shared")
                                .font(.system(size: 13))
                                .foregroundStyle(secondaryFg)
                        }
                    }
                    .buttonStyle(.plain)
                    Button {
                        selectedProfileSegment = .contributions
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(contributionsByUserCount)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(primaryFg)
                            Text("contributions")
                                .font(.system(size: 13))
                                .foregroundStyle(secondaryFg)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if store.averageRatingForUser(displayName: displayName, authorId: authorId) != nil || store.averageIdeaRatingForUser(displayName: displayName, authorId: authorId) != nil {
                    HStack(spacing: 20) {
                        if let avg = store.averageRatingForUser(displayName: displayName, authorId: authorId) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", avg))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(primaryFg)
                                Text("completions")
                                    .font(.system(size: 12))
                                    .foregroundStyle(secondaryFg)
                            }
                        }
                        if let avg = store.averageIdeaRatingForUser(displayName: displayName, authorId: authorId) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", avg))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(primaryFg)
                                Text("ideas")
                                    .font(.system(size: 12))
                                    .foregroundStyle(secondaryFg)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Text(selectedProfileSegment == .ideas ? "Ideas by \(displayName)" : "Contributions by \(displayName)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondaryFg)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
    }

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if ideasByUser.isEmpty {
                Text("No ideas yet.")
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryFg)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(primaryFg.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
            } else {
                ForEach(ideasByUser) { idea in
                    IdeaCardView(idea: idea, onOpenUserProfile: nil) {
                        onSelectIdea(idea.id)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var contributionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if contributionsByUserWithIdeas.isEmpty {
                Text("No contributions yet.")
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryFg)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(primaryFg.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
            } else {
                ForEach(Array(contributionsByUserWithIdeas.enumerated()), id: \.element.contribution.id) { _, pair in
                    Button {
                        onSelectIdea(pair.idea.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            let preview = pair.contribution.content.isEmpty ? "Voice or attachment" : String(pair.contribution.content.prefix(120))
                            let previewText = preview.count == 120 ? preview + "…" : preview
                            Text(previewText)
                                .font(.system(size: 15))
                                .foregroundStyle(primaryFg)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text("Added to: \(String(pair.idea.content.prefix(60)))\(pair.idea.content.count > 60 ? "…" : "")")
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryFg)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(primaryFg.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

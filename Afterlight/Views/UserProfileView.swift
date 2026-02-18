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

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    ideasSection
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(white: 0.12), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                AuraAvatarView(
                    size: 52,
                    auraVariant: auraVariantForDisplayName(displayName),
                    legacyPaletteIndex: nil
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

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("\(ideasByUser.count)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryFg)
                    Text("ideas shared")
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryFg)
                }
                HStack(spacing: 6) {
                    Text("\(contributionsByUserCount)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryFg)
                    Text("contributions")
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryFg)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Text("Ideas by \(displayName)")
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
            Color.clear.frame(height: 120)
        }
    }
}

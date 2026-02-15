//
//  IdeaCardView.swift
//  Unfin
//

import SwiftUI

struct IdeaCardView: View {
    @EnvironmentObject var store: IdeaStore
    let idea: Idea
    var onAction: () -> Void
    
    var body: some View {
        Button(action: onAction) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(white: 0.5))
                            .frame(width: 6, height: 6)
                        Text(store.categoryDisplayName(byId: idea.categoryId))
                            .font(.system(size: 10, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(Color(white: 0.5))
                    }
                    Spacer()
                    Text(idea.timeAgo)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                
                cardContent
                
                if !idea.attachments.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.95))
                        Text("\(idea.attachments.count) attachment\(idea.attachments.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.95))
                    }
                }
                
                HStack {
                    participantAvatars
                    Spacer()
                    HStack(spacing: 6) {
                        Text(store.categoryActionVerb(byId: idea.categoryId))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var cardContent: some View {
        if idea.categoryId == Category.melodyId {
            VStack(alignment: .leading, spacing: 12) {
                WaveformView()
                Text(idea.content)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.95))
            }
        } else {
            Text(idea.content)
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(Color.white)
                .lineLimit(4)
        }
    }
    
    private var participantAvatars: some View {
        let participants = Array(idea.participantDisplayNames.prefix(3))
        let total = idea.participantDisplayNames.count
        return HStack(spacing: -8) {
            ForEach(Array(participants.enumerated()), id: \.offset) { index, displayName in
                if displayName == store.currentUserName, let acc = store.currentAccount {
                    AuraAvatarView(
                        size: 24,
                        auraVariant: acc.auraVariant,
                        legacyPaletteIndex: acc.auraPaletteIndex
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                } else {
                    let initial = String(displayName.prefix(1)).uppercased()
                    Text(initial)
                        .font(.system(size: index == 2 && total > 3 ? 10 : 8))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(width: 24, height: 24)
                        .background(
                            index == 2 && total > 3
                                ? Color.white.opacity(0.15)
                                : Color(white: 0.18)
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
            }
            if total > 3 {
                Text("+\(total - 3)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.leading, 4)
            }
        }
    }
    
}

struct WaveformView: View {
    @State private var animating = false
    let heights: [CGFloat] = [0.4, 0.7, 0.3, 1.0, 0.5, 0.8, 0.4, 0.6, 0.2]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, h in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 3, height: 24 * h)
                    .scaleEffect(y: animating ? 1 : 0.5, anchor: .center)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.05),
                        value: animating
                    )
            }
        }
        .frame(height: 24)
        .onAppear { animating = true }
    }
}

#Preview {
    IdeaCardView(
        idea: Idea(
            categoryId: Category.fictionId,
            content: "The train station was empty...",
            authorDisplayName: "K"
        ),
        onAction: {}
    )
    .environmentObject(IdeaStore())
    .padding()
    .background(Color.gray)
}

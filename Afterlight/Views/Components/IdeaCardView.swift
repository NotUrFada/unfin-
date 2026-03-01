//
//  IdeaCardView.swift
//  Unfin
//

import SwiftUI

struct IdeaCardView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var contentRevealed = false
    let idea: Idea
    var onOpenUserProfile: ((String, UUID?) -> Void)? = nil
    var onAction: () -> Void

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }
    private var secondaryFg: Color { isLight ? Color(white: 0.4) : Color.white.opacity(0.9) }
    private var mutedFg: Color { isLight ? Color(white: 0.5) : Color.white.opacity(0.5) }

    var body: some View {
        Button(action: onAction) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(mutedFg)
                            .frame(width: 6, height: 6)
                        Text(store.categoryDisplayName(byId: idea.categoryId))
                            .font(.system(size: 10, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(mutedFg)
                        if idea.isSensitive {
                            Text("Sensitive")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        if idea.isFinished {
                            Text(idea.isClosedByTimeLimit ? "Closed" : "Finished")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(idea.isClosedByTimeLimit ? .orange : .green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((idea.isClosedByTimeLimit ? Color.orange : Color.green).opacity(0.2))
                                .clipShape(Capsule())
                        }
                        if !idea.isFinished, let remaining = idea.timeLimitRemaining, remaining > 0 {
                            Text(IdeaCardView.formatTimeRemaining(remaining))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        if !idea.isFinished && idea.completionPercentage > 0 {
                            Text("\(idea.completionPercentage)%")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(secondaryFg)
                        }
                    }
                    Spacer()
                    if idea.ratingCount > 0, let avg = idea.averageRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", avg))
                                .font(.system(size: 11))
                                .foregroundStyle(secondaryFg)
                        }
                        .padding(.trailing, 8)
                    }
                    Text(idea.timeAgo)
                            .font(.system(size: 11))
                            .foregroundStyle(secondaryFg)
                }
                
                sensitiveAwareCardContent
                
                if idea.voicePath != nil || !idea.attachments.isEmpty {
                    HStack(spacing: 10) {
                        if idea.voicePath != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 11))
                                Text("Voice")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(secondaryFg)
                        }
                        if !idea.attachments.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 11))
                                    .foregroundStyle(secondaryFg)
                                Text("\(idea.attachments.count) attachment\(idea.attachments.count == 1 ? "" : "s")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(secondaryFg)
                            }
                        }
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
                    .foregroundStyle(isLight ? .white : primaryFg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(primaryFg.opacity(isLight ? 0.2 : 0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(primaryFg.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var cardContent: some View {
        if idea.categoryId == Category.melodyId {
            VStack(alignment: .leading, spacing: 12) {
                WaveformView(isLight: isLight)
                Text(idea.content)
                    .font(.system(size: 14))
                    .foregroundStyle(secondaryFg)
            }
        } else {
            Text(idea.content)
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(primaryFg)
                .lineLimit(4)
        }
    }
    
    @ViewBuilder
    private var sensitiveAwareCardContent: some View {
        if idea.isSensitive, !store.isCurrentUserIdeaAuthor(ideaId: idea.id), !contentRevealed {
            ZStack {
                cardContent
                    .blur(radius: 12)
                Button {
                    contentRevealed = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 28))
                        Text("Tap to reveal")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(secondaryFg)
                    .frame(maxWidth: .infinity, minHeight: 80)
                }
                .buttonStyle(.plain)
            }
        } else {
            cardContent
        }
    }
    
    private var participantAvatars: some View {
        let destinations = Array(idea.participantDestinations.prefix(3))
        let total = idea.participantDestinations.count
        return HStack(spacing: -8) {
            ForEach(Array(destinations.enumerated()), id: \.offset) { index, dest in
                let isCurrentUser = dest.authorId == store.currentUserId
                let effectiveName = isCurrentUser ? store.currentUserName : dest.displayName
                let variant: Int? = isCurrentUser
                    ? store.currentAccount?.auraVariant
                    : auraVariantForDisplayName(dest.displayName)
                let avatar = AuraAvatarView(
                    size: 24,
                    auraVariant: variant,
                    legacyPaletteIndex: isCurrentUser ? store.currentAccount?.auraPaletteIndex : nil,
                    fallbackUserId: isCurrentUser ? store.currentUserId : nil,
                    fallbackDisplayName: effectiveName
                )
                .overlay(Circle().stroke(primaryFg.opacity(0.15), lineWidth: 1))
                if let onOpen = onOpenUserProfile {
                    Button {
                        onOpen(effectiveName, dest.authorId)
                    } label: { avatar }
                    .buttonStyle(.plain)
                } else {
                    avatar
                }
            }
            if total > 3 {
                Text("+\(total - 3)")
                    .font(.system(size: 10))
                    .foregroundStyle(secondaryFg)
                    .padding(.leading, 4)
            }
        }
    }

    private static func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h >= 24 {
            let d = h / 24
            let hRest = h % 24
            if hRest == 0 { return "\(d)d left" }
            return "\(d)d \(hRest)h left"
        }
        if h > 0 { return "\(h)h \(m)m left" }
        if m > 0 { return "\(m)m left" }
        return "Closing soon"
    }
}

struct WaveformView: View {
    @State private var animating = false
    var isLight: Bool = false
    let heights: [CGFloat] = [0.4, 0.7, 0.3, 1.0, 0.5, 0.8, 0.4, 0.6, 0.2]

    private var barColor: Color { isLight ? Color(white: 0.35) : .white }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, h in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
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

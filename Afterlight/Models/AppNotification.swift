//
//  AppNotification.swift
//  Unfin
//

import Foundation

enum AppNotificationType: String, Codable {
    case contribution  // reply to your idea
    case comment       // comment on your completion
    case reaction      // reaction on your completion
    case newIdea       // someone posted a new idea
}

struct AppNotification: Codable, Identifiable {
    let id: UUID
    let type: AppNotificationType
    let ideaId: UUID
    let contributionId: UUID?
    let actorDisplayName: String
    /// Who should see this (display name). Empty means broadcast / all.
    let targetDisplayName: String
    let createdAt: Date
    var isRead: Bool
    
    init(
        id: UUID = UUID(),
        type: AppNotificationType,
        ideaId: UUID,
        contributionId: UUID? = nil,
        actorDisplayName: String,
        targetDisplayName: String,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.ideaId = ideaId
        self.contributionId = contributionId
        self.actorDisplayName = actorDisplayName
        self.targetDisplayName = targetDisplayName
        self.createdAt = createdAt
        self.isRead = isRead
    }
    
    var summaryText: String {
        switch type {
        case .contribution:
            return "\(actorDisplayName) replied to your idea"
        case .comment:
            return "\(actorDisplayName) commented on your completion"
        case .reaction:
            return "\(actorDisplayName) reacted to your completion"
        case .newIdea:
            return "\(actorDisplayName) posted a new idea"
        }
    }
    
    var iconName: String {
        switch type {
        case .contribution: return "arrowshape.turn.up.left.fill"
        case .comment: return "bubble.left.fill"
        case .reaction: return "heart.fill"
        case .newIdea: return "doc.badge.plus"
        }
    }
}

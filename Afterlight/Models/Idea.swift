//
//  Idea.swift
//  Unfin
//

import Foundation

enum IdeaCategory: String, Codable, CaseIterable {
    case melody
    case lyrics
    case fiction
    case concept
    case poetry
    
    var displayName: String {
        switch self {
        case .melody: return "Melody"
        case .lyrics: return "Lyrics"
        case .fiction: return "Micro-Fiction"
        case .concept: return "Concept"
        case .poetry: return "Poetry"
        }
    }
    
    var actionVerb: String {
        switch self {
        case .melody: return "Complete"
        case .lyrics: return "Verse"
        case .fiction: return "Write"
        case .concept: return "Build"
        case .poetry: return "Verse"
        }
    }
}

enum AttachmentKind: String, Codable, CaseIterable {
    case image
    case audio
    case document
    case other
    
    var iconName: String {
        switch self {
        case .image: return "photo.fill"
        case .audio: return "waveform"
        case .document: return "doc.fill"
        case .other: return "paperclip"
        }
    }
}

struct Attachment: Codable, Identifiable {
    let id: UUID
    let fileName: String
    let displayName: String
    let kind: AttachmentKind
    
    init(id: UUID = UUID(), fileName: String, displayName: String, kind: AttachmentKind) {
        self.id = id
        self.fileName = fileName
        self.displayName = displayName
        self.kind = kind
    }
}

struct Comment: Codable, Identifiable {
    let id: UUID
    let authorDisplayName: String
    var content: String
    let createdAt: Date
    var reactions: [Reaction]
    var voicePath: String?
    var authorId: UUID?
    var editedAt: Date?
    
    init(id: UUID = UUID(), authorDisplayName: String, content: String, createdAt: Date = Date(), reactions: [Reaction] = [], voicePath: String? = nil, authorId: UUID? = nil, editedAt: Date? = nil) {
        self.id = id
        self.authorDisplayName = authorDisplayName
        self.content = content
        self.createdAt = createdAt
        self.reactions = reactions
        self.voicePath = voicePath
        self.authorId = authorId
        self.editedAt = editedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, authorDisplayName, content, createdAt, reactions, voicePath, authorId, editedAt
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        authorDisplayName = try c.decode(String.self, forKey: .authorDisplayName)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        reactions = try c.decodeIfPresent([Reaction].self, forKey: .reactions) ?? []
        voicePath = try c.decodeIfPresent(String.self, forKey: .voicePath)
        authorId = try c.decodeIfPresent(UUID.self, forKey: .authorId)
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(authorDisplayName, forKey: .authorDisplayName)
        try c.encode(content, forKey: .content)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(reactions, forKey: .reactions)
        try c.encodeIfPresent(voicePath, forKey: .voicePath)
        try c.encodeIfPresent(authorId, forKey: .authorId)
        try c.encodeIfPresent(editedAt, forKey: .editedAt)
    }
    
    func count(for type: String) -> Int { reactions.filter { $0.type == type }.count }
    var totalReactionCount: Int { reactions.count }
}

/// A single reaction from a user (emoji type or sticker id).
struct Reaction: Codable, Identifiable {
    let id: UUID
    let accountId: UUID
    /// One of: "heart", "fire", "laugh", "thumbsUp", "wow", "sad", or "sticker:xyz" for stickers.
    let type: String
    
    init(id: UUID = UUID(), accountId: UUID, type: String) {
        self.id = id
        self.accountId = accountId
        self.type = type
    }
}

enum ReactionType: String, CaseIterable {
    case heart
    case fire
    case laugh
    case thumbsUp
    case wow
    case sad
    
    var symbolName: String {
        switch self {
        case .heart: return "heart.fill"
        case .fire: return "flame.fill"
        case .laugh: return "face.smiling.fill"
        case .thumbsUp: return "hand.thumbsup.fill"
        case .wow: return "star.fill"
        case .sad: return "cloud.rain.fill"
        }
    }
}

/// Sticker options for the reaction sticker picker.
enum ReactionStickers {
    static let all: [(id: String, emoji: String)] = [
        ("party", "🎉"),
        ("star", "⭐️"),
        ("lightbulb", "💡"),
        ("sparkles", "✨"),
        ("clap", "👏"),
        ("rocket", "🚀"),
        ("flame", "🔥"),
        ("heart", "❤️"),
    ]
}

struct Contribution: Codable, Identifiable {
    let id: UUID
    let authorDisplayName: String
    var content: String
    let createdAt: Date
    var isPublic: Bool
    var likedByAccountIds: [UUID] // legacy; kept for decode migration
    var reactions: [Reaction]
    var comments: [Comment]
    var voicePath: String?
    var authorId: UUID?
    var editedAt: Date?
    var attachments: [Attachment]
    
    init(
        id: UUID = UUID(),
        authorDisplayName: String,
        content: String,
        createdAt: Date = Date(),
        isPublic: Bool = true,
        likedByAccountIds: [UUID] = [],
        reactions: [Reaction] = [],
        comments: [Comment] = [],
        voicePath: String? = nil,
        authorId: UUID? = nil,
        editedAt: Date? = nil,
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.authorDisplayName = authorDisplayName
        self.content = content
        self.createdAt = createdAt
        self.isPublic = isPublic
        self.likedByAccountIds = likedByAccountIds
        self.reactions = reactions
        self.comments = comments
        self.voicePath = voicePath
        self.authorId = authorId
        self.editedAt = editedAt
        self.attachments = attachments
    }
    
    func count(for type: String) -> Int {
        reactions.filter { $0.type == type }.count
    }
    
    var likeCount: Int { count(for: ReactionType.heart.rawValue) }
    var totalReactionCount: Int { reactions.count }
    
    enum CodingKeys: String, CodingKey {
        case id, authorDisplayName, content, createdAt, isPublic, likedByAccountIds, reactions, comments, voicePath, authorId, editedAt, attachments
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        authorDisplayName = try c.decode(String.self, forKey: .authorDisplayName)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
        let legacyLikes = try c.decodeIfPresent([UUID].self, forKey: .likedByAccountIds) ?? []
        var decodedReactions = try c.decodeIfPresent([Reaction].self, forKey: .reactions) ?? []
        if !legacyLikes.isEmpty && decodedReactions.isEmpty {
            decodedReactions = legacyLikes.map { Reaction(accountId: $0, type: ReactionType.heart.rawValue) }
        }
        likedByAccountIds = []
        reactions = decodedReactions
        comments = try c.decodeIfPresent([Comment].self, forKey: .comments) ?? []
        voicePath = try c.decodeIfPresent(String.self, forKey: .voicePath)
        authorId = try c.decodeIfPresent(UUID.self, forKey: .authorId)
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt)
        attachments = try c.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(authorDisplayName, forKey: .authorDisplayName)
        try c.encode(content, forKey: .content)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(isPublic, forKey: .isPublic)
        try c.encode(likedByAccountIds, forKey: .likedByAccountIds)
        try c.encode(reactions, forKey: .reactions)
        try c.encode(comments, forKey: .comments)
        try c.encodeIfPresent(voicePath, forKey: .voicePath)
        try c.encodeIfPresent(authorId, forKey: .authorId)
        try c.encodeIfPresent(editedAt, forKey: .editedAt)
        try c.encode(attachments, forKey: .attachments)
    }
}

struct Idea: Codable, Identifiable {
    let id: UUID
    var categoryId: UUID
    var content: String
    /// Optional storage path for voice-recorded idea (e.g. "ideas/<id>/voice.m4a").
    var voicePath: String?
    /// Stable author identity; use this (not display name) to determine "my ideas" so they persist after name change.
    var authorId: UUID?
    var authorDisplayName: String
    var createdAt: Date
    var contributions: [Contribution]
    var attachments: [Attachment]
    
    init(
        id: UUID = UUID(),
        categoryId: UUID,
        content: String,
        voicePath: String? = nil,
        authorId: UUID? = nil,
        authorDisplayName: String,
        createdAt: Date = Date(),
        contributions: [Contribution] = [],
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.categoryId = categoryId
        self.content = content
        self.voicePath = voicePath
        self.authorId = authorId
        self.authorDisplayName = authorDisplayName
        self.createdAt = createdAt
        self.contributions = contributions
        self.attachments = attachments
    }
    
    enum CodingKeys: String, CodingKey {
        case id, categoryId, category, content, voicePath, authorId, authorDisplayName, createdAt, contributions, attachments
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        if let catId = try c.decodeIfPresent(UUID.self, forKey: .categoryId) {
            categoryId = catId
        } else if let legacy = try c.decodeIfPresent(IdeaCategory.self, forKey: .category) {
            categoryId = Category.systemId(for: legacy)
        } else {
            categoryId = Category.melodyId
        }
        content = try c.decode(String.self, forKey: .content)
        voicePath = try c.decodeIfPresent(String.self, forKey: .voicePath)
        authorId = try c.decodeIfPresent(UUID.self, forKey: .authorId)
        authorDisplayName = try c.decode(String.self, forKey: .authorDisplayName)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        contributions = try c.decode([Contribution].self, forKey: .contributions)
        attachments = try c.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(categoryId, forKey: .categoryId)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(voicePath, forKey: .voicePath)
        try c.encodeIfPresent(authorId, forKey: .authorId)
        try c.encode(authorDisplayName, forKey: .authorDisplayName)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(contributions, forKey: .contributions)
        try c.encode(attachments, forKey: .attachments)
    }
    
    /// Participant display names, author first, then contributors (unique, order preserved). Use for avatar list.
    var participantDisplayNames: [String] {
        var seen = Set<String>()
        var out: [String] = []
        if !seen.contains(authorDisplayName) {
            seen.insert(authorDisplayName)
            out.append(authorDisplayName)
        }
        for c in contributions {
            if !seen.contains(c.authorDisplayName) {
                seen.insert(c.authorDisplayName)
                out.append(c.authorDisplayName)
            }
        }
        return out
    }
    
    var participantInitials: [String] {
        participantDisplayNames.map { String($0.prefix(1)).uppercased() }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

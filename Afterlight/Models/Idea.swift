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
    let content: String
    let createdAt: Date
    
    init(id: UUID = UUID(), authorDisplayName: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.authorDisplayName = authorDisplayName
        self.content = content
        self.createdAt = createdAt
    }
}

struct Contribution: Codable, Identifiable {
    let id: UUID
    let authorDisplayName: String
    let content: String
    let createdAt: Date
    var isPublic: Bool
    var likedByAccountIds: [UUID]
    var comments: [Comment]
    
    init(
        id: UUID = UUID(),
        authorDisplayName: String,
        content: String,
        createdAt: Date = Date(),
        isPublic: Bool = true,
        likedByAccountIds: [UUID] = [],
        comments: [Comment] = []
    ) {
        self.id = id
        self.authorDisplayName = authorDisplayName
        self.content = content
        self.createdAt = createdAt
        self.isPublic = isPublic
        self.likedByAccountIds = likedByAccountIds
        self.comments = comments
    }
    
    var likeCount: Int { likedByAccountIds.count }
    
    enum CodingKeys: String, CodingKey {
        case id, authorDisplayName, content, createdAt, isPublic, likedByAccountIds, comments
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        authorDisplayName = try c.decode(String.self, forKey: .authorDisplayName)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
        likedByAccountIds = try c.decodeIfPresent([UUID].self, forKey: .likedByAccountIds) ?? []
        comments = try c.decodeIfPresent([Comment].self, forKey: .comments) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(authorDisplayName, forKey: .authorDisplayName)
        try c.encode(content, forKey: .content)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(isPublic, forKey: .isPublic)
        try c.encode(likedByAccountIds, forKey: .likedByAccountIds)
        try c.encode(comments, forKey: .comments)
    }
}

struct Idea: Codable, Identifiable {
    let id: UUID
    var categoryId: UUID
    var content: String
    var authorDisplayName: String
    var createdAt: Date
    var contributions: [Contribution]
    var attachments: [Attachment]
    
    init(
        id: UUID = UUID(),
        categoryId: UUID,
        content: String,
        authorDisplayName: String,
        createdAt: Date = Date(),
        contributions: [Contribution] = [],
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.categoryId = categoryId
        self.content = content
        self.authorDisplayName = authorDisplayName
        self.createdAt = createdAt
        self.contributions = contributions
        self.attachments = attachments
    }
    
    enum CodingKeys: String, CodingKey {
        case id, categoryId, category, content, authorDisplayName, createdAt, contributions, attachments
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
        try c.encode(authorDisplayName, forKey: .authorDisplayName)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(contributions, forKey: .contributions)
        try c.encode(attachments, forKey: .attachments)
    }
    
    var participantInitials: [String] {
        var set = Set([String(authorDisplayName.prefix(1)).uppercased()])
        for c in contributions {
            set.insert(String(c.authorDisplayName.prefix(1)).uppercased())
        }
        return Array(set).sorted()
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

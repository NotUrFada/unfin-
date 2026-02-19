//
//  Category.swift
//  Unfin
//

import Foundation

struct Category: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var displayName: String
    var actionVerb: String
    let isSystem: Bool
    /// User who created this category (app_user_id); nil for system categories. Only the creator can delete.
    let creatorId: UUID?
    
    init(id: UUID, displayName: String, actionVerb: String, isSystem: Bool = false, creatorId: UUID? = nil) {
        self.id = id
        self.displayName = displayName
        self.actionVerb = actionVerb
        self.isSystem = isSystem
        self.creatorId = creatorId
    }
    
    // Fixed UUIDs for system categories (for migration and consistency)
    static let melodyId = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!
    static let lyricsId = UUID(uuidString: "A1000000-0000-0000-0000-000000000002")!
    static let fictionId = UUID(uuidString: "A1000000-0000-0000-0000-000000000003")!
    static let conceptId = UUID(uuidString: "A1000000-0000-0000-0000-000000000004")!
    static let poetryId = UUID(uuidString: "A1000000-0000-0000-0000-000000000005")!
    
    static func systemId(for ideaCategory: IdeaCategory) -> UUID {
        switch ideaCategory {
        case .melody: return melodyId
        case .lyrics: return lyricsId
        case .fiction: return fictionId
        case .concept: return conceptId
        case .poetry: return poetryId
        }
    }
    
    static var defaultSystemCategories: [Category] {
        [
            Category(id: melodyId, displayName: "Melody", actionVerb: "Complete", isSystem: true, creatorId: nil),
            Category(id: lyricsId, displayName: "Lyrics", actionVerb: "Verse", isSystem: true, creatorId: nil),
            Category(id: fictionId, displayName: "Micro-Fiction", actionVerb: "Write", isSystem: true, creatorId: nil),
            Category(id: conceptId, displayName: "Concept", actionVerb: "Build", isSystem: true, creatorId: nil),
            Category(id: poetryId, displayName: "Poetry", actionVerb: "Verse", isSystem: true, creatorId: nil)
        ]
    }
}

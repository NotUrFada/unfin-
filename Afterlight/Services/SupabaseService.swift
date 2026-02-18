//
//  SupabaseService.swift
//  Unfin
//

import Foundation
import Supabase

// MARK: - Configuration

private enum SupabaseConfig {
    static var url: URL {
        guard let path = Bundle.main.path(forResource: "Supabase-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let urlString = plist["SUPABASE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("Add Supabase-Info.plist with SUPABASE_URL and SUPABASE_ANON_KEY. See SUPABASE_SETUP.md.")
        }
        return url
    }
    static var anonKey: String {
        guard let path = Bundle.main.path(forResource: "Supabase-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let key = plist["SUPABASE_ANON_KEY"] as? String else {
            fatalError("Add Supabase-Info.plist with SUPABASE_ANON_KEY. See SUPABASE_SETUP.md.")
        }
        return key
    }
}

enum SupabaseService {
    static let client: SupabaseClient = {
        SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }()
}

// MARK: - User Profile (same shape as before for IdeaStore)

struct FirestoreUserProfile {
    var appUserId: String
    var displayName: String
    var email: String?
    var auraVariant: Int?
    var auraPaletteIndex: Int?
    var glyphGrid: String?
    var createdAt: Date?
    var streakCount: Int
    var streakLastDate: Date?
}

// MARK: - DB row types (snake_case for Postgres)

private struct ProfileRow: Codable {
    let id: UUID
    let appUserId: UUID
    let displayName: String
    let email: String?
    let auraVariant: Int?
    let auraPaletteIndex: Int?
    let glyphGrid: String?
    let createdAt: Date?
    let streakCount: Int
    let streakLastDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, displayName = "display_name", email
        case appUserId = "app_user_id"
        case auraVariant = "aura_variant"
        case auraPaletteIndex = "aura_palette_index"
        case glyphGrid = "glyph_grid"
        case createdAt = "created_at"
        case streakCount = "streak_count"
        case streakLastDate = "streak_last_date"
    }
    
    init(id: UUID, appUserId: UUID, displayName: String, email: String?, auraVariant: Int?, auraPaletteIndex: Int?, glyphGrid: String?, createdAt: Date?, streakCount: Int = 0, streakLastDate: Date? = nil) {
        self.id = id
        self.appUserId = appUserId
        self.displayName = displayName
        self.email = email
        self.auraVariant = auraVariant
        self.auraPaletteIndex = auraPaletteIndex
        self.glyphGrid = glyphGrid
        self.createdAt = createdAt
        self.streakCount = streakCount
        self.streakLastDate = streakLastDate
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        appUserId = try c.decode(UUID.self, forKey: .appUserId)
        displayName = try c.decode(String.self, forKey: .displayName)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        auraVariant = try c.decodeIfPresent(Int.self, forKey: .auraVariant)
        auraPaletteIndex = try c.decodeIfPresent(Int.self, forKey: .auraPaletteIndex)
        glyphGrid = try c.decodeIfPresent(String.self, forKey: .glyphGrid)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        streakCount = try c.decodeIfPresent(Int.self, forKey: .streakCount) ?? 0
        if let d = try c.decodeIfPresent(Date.self, forKey: .streakLastDate) {
            streakLastDate = d
        } else if let s = try c.decodeIfPresent(String.self, forKey: .streakLastDate) {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = TimeZone(identifier: "UTC")
            streakLastDate = fmt.date(from: s)
        } else {
            streakLastDate = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(appUserId, forKey: .appUserId)
        try c.encode(displayName, forKey: .displayName)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(auraVariant, forKey: .auraVariant)
        try c.encodeIfPresent(auraPaletteIndex, forKey: .auraPaletteIndex)
        try c.encodeIfPresent(glyphGrid, forKey: .glyphGrid)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encode(streakCount, forKey: .streakCount)
        try c.encodeIfPresent(streakLastDate, forKey: .streakLastDate)
    }
}

private struct IdeaRow: Codable {
    let id: UUID
    let categoryId: UUID
    let content: String
    let voicePath: String?
    let drawingPath: String?
    let authorId: UUID
    let authorDisplayName: String
    let createdAt: Date
    let contributions: [ContributionRow]
    let attachments: [AttachmentRow]
    let finishedAt: Date?
    let isSensitive: Bool
    let averageRating: Double?
    let ratingCount: Int
    let completionPercentage: Int
    
    enum CodingKeys: String, CodingKey {
        case id, content, voicePath = "voice_path"
        case categoryId = "category_id"
        case authorId = "author_id"
        case authorDisplayName = "author_display_name"
        case createdAt = "created_at"
        case contributions, attachments
        case finishedAt = "finished_at"
        case isSensitive = "is_sensitive"
        case drawingPath = "drawing_path"
        case averageRating = "average_rating"
        case ratingCount = "rating_count"
        case completionPercentage = "completion_percentage"
    }
    
    init(id: UUID, categoryId: UUID, content: String, voicePath: String? = nil, drawingPath: String? = nil, authorId: UUID, authorDisplayName: String, createdAt: Date, contributions: [ContributionRow], attachments: [AttachmentRow], finishedAt: Date? = nil, isSensitive: Bool = false, averageRating: Double? = nil, ratingCount: Int = 0, completionPercentage: Int = 0) {
        self.id = id
        self.categoryId = categoryId
        self.content = content
        self.voicePath = voicePath
        self.drawingPath = drawingPath
        self.authorId = authorId
        self.authorDisplayName = authorDisplayName
        self.createdAt = createdAt
        self.contributions = contributions
        self.attachments = attachments
        self.finishedAt = finishedAt
        self.isSensitive = isSensitive
        self.averageRating = averageRating
        self.ratingCount = ratingCount
        self.completionPercentage = min(100, max(0, completionPercentage))
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        categoryId = try c.decode(UUID.self, forKey: .categoryId)
        content = try c.decode(String.self, forKey: .content)
        voicePath = try c.decodeIfPresent(String.self, forKey: .voicePath)
        authorId = try c.decode(UUID.self, forKey: .authorId)
        authorDisplayName = try c.decode(String.self, forKey: .authorDisplayName)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        contributions = try c.decode([ContributionRow].self, forKey: .contributions)
        attachments = try c.decode([AttachmentRow].self, forKey: .attachments)
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        isSensitive = try c.decodeIfPresent(Bool.self, forKey: .isSensitive) ?? false
        drawingPath = try c.decodeIfPresent(String.self, forKey: .drawingPath)
        averageRating = try c.decodeIfPresent(Double.self, forKey: .averageRating)
        ratingCount = try c.decodeIfPresent(Int.self, forKey: .ratingCount) ?? 0
        completionPercentage = min(100, max(0, try c.decodeIfPresent(Int.self, forKey: .completionPercentage) ?? 0))
    }
}

private struct ContributionRow: Codable {
    let id: UUID
    let authorDisplayName: String
    let content: String
    let createdAt: Date
    let isPublic: Bool
    let reactions: [ReactionRow]
    let comments: [CommentRow]
    let voicePath: String?
    let authorId: UUID?
    let editedAt: Date?
    let attachments: [AttachmentRow]
    let drawingPath: String?
    let authorRating: Int?
    let authorRatingAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, content, createdAt = "created_at"
        case authorDisplayName = "author_display_name"
        case isPublic = "is_public"
        case reactions, comments
        case voicePath = "voice_path"
        case authorId = "author_id"
        case editedAt = "edited_at"
        case attachments
        case drawingPath = "drawing_path"
        case authorRating = "author_rating"
        case authorRatingAt = "author_rating_at"
    }
    
    init(id: UUID, authorDisplayName: String, content: String, createdAt: Date, isPublic: Bool, reactions: [ReactionRow], comments: [CommentRow], voicePath: String? = nil, authorId: UUID? = nil, editedAt: Date? = nil, attachments: [AttachmentRow] = [], drawingPath: String? = nil, authorRating: Int? = nil, authorRatingAt: Date? = nil) {
        self.id = id
        self.authorDisplayName = authorDisplayName
        self.content = content
        self.createdAt = createdAt
        self.isPublic = isPublic
        self.reactions = reactions
        self.comments = comments
        self.voicePath = voicePath
        self.authorId = authorId
        self.editedAt = editedAt
        self.attachments = attachments
        self.drawingPath = drawingPath
        self.authorRating = authorRating
        self.authorRatingAt = authorRatingAt
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        authorDisplayName = try c.decode(String.self, forKey: .authorDisplayName)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
        reactions = try c.decodeIfPresent([ReactionRow].self, forKey: .reactions) ?? []
        comments = try c.decodeIfPresent([CommentRow].self, forKey: .comments) ?? []
        voicePath = try c.decodeIfPresent(String.self, forKey: .voicePath)
        authorId = try c.decodeIfPresent(UUID.self, forKey: .authorId)
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt)
        attachments = try c.decodeIfPresent([AttachmentRow].self, forKey: .attachments) ?? []
        drawingPath = try c.decodeIfPresent(String.self, forKey: .drawingPath)
        authorRating = try c.decodeIfPresent(Int.self, forKey: .authorRating)
        authorRatingAt = try c.decodeIfPresent(Date.self, forKey: .authorRatingAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(authorDisplayName, forKey: .authorDisplayName)
        try c.encode(content, forKey: .content)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(isPublic, forKey: .isPublic)
        try c.encode(reactions, forKey: .reactions)
        try c.encode(comments, forKey: .comments)
        try c.encodeIfPresent(voicePath, forKey: .voicePath)
        try c.encodeIfPresent(authorId, forKey: .authorId)
        try c.encodeIfPresent(editedAt, forKey: .editedAt)
        try c.encode(attachments, forKey: .attachments)
        try c.encodeIfPresent(drawingPath, forKey: .drawingPath)
        try c.encodeIfPresent(authorRating, forKey: .authorRating)
        try c.encodeIfPresent(authorRatingAt, forKey: .authorRatingAt)
    }
}

private struct ReactionRow: Codable {
    let id: UUID
    let accountId: UUID
    let type: String
    enum CodingKeys: String, CodingKey {
        case id, type
        case accountId = "account_id"
    }
}

private struct CommentRow: Codable {
    let id: UUID
    let authorDisplayName: String
    var content: String
    let createdAt: Date
    let reactions: [ReactionRow]
    let voicePath: String?
    let authorId: UUID?
    let editedAt: Date?
    init(id: UUID, authorDisplayName: String, content: String, createdAt: Date, reactions: [ReactionRow] = [], voicePath: String? = nil, authorId: UUID? = nil, editedAt: Date? = nil) {
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
        case id, content, reactions
        case authorDisplayName = "author_display_name"
        case createdAt = "created_at"
        case voicePath = "voice_path"
        case authorId = "author_id"
        case editedAt = "edited_at"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        authorDisplayName = try c.decode(String.self, forKey: .authorDisplayName)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        reactions = try c.decodeIfPresent([ReactionRow].self, forKey: .reactions) ?? []
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
}

private struct AttachmentRow: Codable {
    let id: UUID
    let fileName: String
    let displayName: String
    let kind: String
    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case displayName = "display_name"
        case kind
    }
}

private struct CategoryRow: Codable {
    let id: UUID
    let displayName: String
    let actionVerb: String
    let isSystem: Bool
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case actionVerb = "action_verb"
        case isSystem = "is_system"
    }
}

private struct NotificationRow: Codable {
    let id: UUID
    let type: String
    let ideaId: UUID
    let contributionId: UUID?
    let actorDisplayName: String
    let targetDisplayName: String
    let createdAt: Date
    let isRead: Bool
    enum CodingKeys: String, CodingKey {
        case id, type
        case ideaId = "idea_id"
        case contributionId = "contribution_id"
        case actorDisplayName = "actor_display_name"
        case targetDisplayName = "target_display_name"
        case createdAt = "created_at"
        case isRead = "is_read"
    }
}

// MARK: - Listener (polling-based; call remove() to stop)

final class SupabaseListenerRegistration {
    private var task: Task<Void, Never>?
    private var isRemoved = false
    private let onRemove: () -> Void
    init(remove: @escaping () -> Void) { self.onRemove = remove }
    func startPolling(interval: TimeInterval = 3, handler: @escaping () -> Void) {
        task = Task {
            while !Task.isCancelled && !isRemoved {
                handler()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    func remove() {
        isRemoved = true
        task?.cancel()
        task = nil
        onRemove()
    }
}

// MARK: - Auth

extension SupabaseService {
    static var currentSession: Session? {
        get async {
            try? await client.auth.session
        }
    }
    
    static func signUp(email: String, password: String, displayName: String) async throws -> (appUserId: UUID, displayName: String) {
        let response = try await client.auth.signUp(email: email, password: password)
        let user = response.user
        let appUserId = UUID()
        let profile = ProfileRow(
            id: user.id,
            appUserId: appUserId,
            displayName: displayName,
            email: email,
            auraVariant: nil,
            auraPaletteIndex: nil,
            glyphGrid: nil,
            createdAt: Date(),
            streakCount: 0,
            streakLastDate: nil
        )
        try await client.from("profiles").insert(profile).execute()
        return (appUserId, displayName)
    }
    
    static func login(email: String, password: String) async throws -> (appUserId: UUID, displayName: String, profile: FirestoreUserProfile?) {
        _ = try await client.auth.signIn(email: email, password: password)
        let session = try await client.auth.session
        // Select profile columns including aura so we can return full profile and show correct avatar after login
        let selectColumns = "id,app_user_id,display_name,email,aura_variant,aura_palette_index,glyph_grid,created_at,streak_count,streak_last_date"
        var rows: [ProfileRow] = (try? await client.from("profiles").select(selectColumns).eq("id", value: session.user.id).execute().value) ?? []
        if let row = rows.first {
            let profile = FirestoreUserProfile(
                appUserId: row.appUserId.uuidString,
                displayName: row.displayName,
                email: row.email,
                auraVariant: row.auraVariant,
                auraPaletteIndex: row.auraPaletteIndex,
                glyphGrid: row.glyphGrid,
                createdAt: row.createdAt,
                streakCount: row.streakCount,
                streakLastDate: row.streakLastDate
            )
            return (row.appUserId, row.displayName, profile)
        }
        // Auth user exists but no profile row. Insert minimal profile (only columns that always exist) so we don't fail on older DBs missing streak_count/streak_last_date.
        let appUserId = UUID()
        let displayName = session.user.email?.split(separator: "@").first.map(String.init) ?? "User"
        struct MinimalProfileInsert: Encodable {
            let id: UUID
            let app_user_id: UUID
            let display_name: String
            let email: String?
            let aura_variant: Int?
            let aura_palette_index: Int?
            let glyph_grid: String?
            let created_at: Date
        }
        let minimal = MinimalProfileInsert(
            id: session.user.id,
            app_user_id: appUserId,
            display_name: displayName,
            email: session.user.email,
            aura_variant: nil,
            aura_palette_index: nil,
            glyph_grid: nil,
            created_at: Date()
        )
        do {
            try await client.from("profiles").upsert(minimal, onConflict: "id", ignoreDuplicates: true).execute()
        } catch {
            try? await client.from("profiles").insert(minimal).execute()
        }
        let after: [ProfileRow] = (try? await client.from("profiles").select(selectColumns).eq("id", value: session.user.id).execute().value) ?? []
        if let row = after.first {
            let profile = FirestoreUserProfile(
                appUserId: row.appUserId.uuidString,
                displayName: row.displayName,
                email: row.email,
                auraVariant: row.auraVariant,
                auraPaletteIndex: row.auraPaletteIndex,
                glyphGrid: row.glyphGrid,
                createdAt: row.createdAt,
                streakCount: row.streakCount,
                streakLastDate: row.streakLastDate
            )
            return (row.appUserId, row.displayName, profile)
        }
        throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load your profile. Please try again or sign up if you don't have an account."])
    }
    
    static func logout() async throws {
        try await client.auth.signOut()
    }
    
    static func fetchUserProfile() async throws -> (appUserId: UUID, displayName: String, profile: FirestoreUserProfile)? {
        guard let session = try? await client.auth.session else { return nil }
        let sid = session.user.id
        let rows: [ProfileRow] = try await client.from("profiles").select().eq("id", value: sid).execute().value
        guard let row = rows.first else { return nil }
        let p = FirestoreUserProfile(
            appUserId: row.appUserId.uuidString,
            displayName: row.displayName,
            email: row.email,
            auraVariant: row.auraVariant,
            auraPaletteIndex: row.auraPaletteIndex,
            glyphGrid: row.glyphGrid,
            createdAt: row.createdAt,
            streakCount: row.streakCount,
            streakLastDate: row.streakLastDate
        )
        return (row.appUserId, row.displayName, p)
    }
    
    /// Call after the user posts an idea, adds a contribution, or adds a comment. Fetches profile, computes new streak (consecutive calendar days), updates profile, returns new streak.
    static func recordActivity() async throws -> Int {
        guard let session = try? await client.auth.session else { return 0 }
        let rows: [ProfileRow] = try await client.from("profiles").select().eq("id", value: session.user.id).execute().value
        guard let row = rows.first else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDate = row.streakLastDate.map { calendar.startOfDay(for: $0) }
        let newStreak: Int
        if let last = lastDate {
            let daysDiff = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            if daysDiff == 0 { newStreak = row.streakCount }
            else if daysDiff == 1 { newStreak = row.streakCount + 1 }
            else { newStreak = 1 }
        } else {
            newStreak = 1
        }
        struct StreakUpdate: Encodable {
            let streak_count: Int
            let streak_last_date: String
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: today)
        let payload = StreakUpdate(streak_count: newStreak, streak_last_date: dateString)
        try await client.from("profiles").update(payload).eq("id", value: session.user.id).execute()
        return newStreak
    }
    
    static func updateUserProfile(displayName: String? = nil, auraVariant: Int? = nil, auraPaletteIndex: Int? = nil, glyphGrid: String? = nil) async throws {
        guard displayName != nil || auraVariant != nil || auraPaletteIndex != nil || glyphGrid != nil else { return }
        let session = try await client.auth.session
        struct ProfileUpdate: Encodable {
            let display_name: String?
            let aura_variant: Int?
            let aura_palette_index: Int?
            let glyph_grid: String?
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encodeIfPresent(display_name, forKey: .display_name)
                try c.encodeIfPresent(aura_variant, forKey: .aura_variant)
                try c.encodeIfPresent(aura_palette_index, forKey: .aura_palette_index)
                try c.encodeIfPresent(glyph_grid, forKey: .glyph_grid)
            }
            enum CodingKeys: String, CodingKey {
                case display_name, aura_variant, aura_palette_index, glyph_grid
            }
        }
        let payload = ProfileUpdate(display_name: displayName, aura_variant: auraVariant, aura_palette_index: auraPaletteIndex, glyph_grid: glyphGrid)
        try await client.from("profiles").update(payload).eq("id", value: session.user.id).execute()
    }
}

// MARK: - Ideas, Categories, Notifications

private func ideaFromRow(_ row: IdeaRow) -> Idea {
    Idea(
        id: row.id,
        categoryId: row.categoryId,
        content: row.content,
        voicePath: row.voicePath,
        drawingPath: row.drawingPath,
        authorId: row.authorId,
        authorDisplayName: row.authorDisplayName,
        createdAt: row.createdAt,
        contributions: row.contributions.map { c in
            Contribution(
                id: c.id,
                authorDisplayName: c.authorDisplayName,
                content: c.content,
                createdAt: c.createdAt,
                isPublic: c.isPublic,
                reactions: c.reactions.map { r in Reaction(id: r.id, accountId: r.accountId, type: r.type) },
                comments: c.comments.map { com in
                    Comment(
                        id: com.id,
                        authorDisplayName: com.authorDisplayName,
                        content: com.content,
                        createdAt: com.createdAt,
                        reactions: com.reactions.map { r in Reaction(id: r.id, accountId: r.accountId, type: r.type) },
                        voicePath: com.voicePath,
                        authorId: com.authorId,
                        editedAt: com.editedAt
                    )
                },
                voicePath: c.voicePath,
                authorId: c.authorId,
                editedAt: c.editedAt,
                attachments: c.attachments.compactMap { a in AttachmentKind(rawValue: a.kind).map { kind in Attachment(id: a.id, fileName: a.fileName, displayName: a.displayName, kind: kind) } },
                drawingPath: c.drawingPath,
                authorRating: c.authorRating,
                authorRatingAt: c.authorRatingAt
            )
        },
        attachments: row.attachments.compactMap { a in AttachmentKind(rawValue: a.kind).map { kind in Attachment(id: a.id, fileName: a.fileName, displayName: a.displayName, kind: kind) } },
        finishedAt: row.finishedAt,
        isSensitive: row.isSensitive,
        averageRating: row.averageRating,
        ratingCount: row.ratingCount,
        completionPercentage: row.completionPercentage
    )
}

extension SupabaseService {
    static func listenIdeas(completion: @escaping ([Idea]) -> Void) -> SupabaseListenerRegistration {
        let reg = SupabaseListenerRegistration { }
        reg.startPolling {
            Task {
                let rows: [IdeaRow] = (try? await client.from("ideas").select().order("created_at", ascending: false).execute().value) ?? []
                await MainActor.run {
                    completion(rows.map(ideaFromRow))
                }
            }
        }
        return reg
    }
    
    static func addIdea(_ idea: Idea, authorId: UUID) async throws {
        struct InsertIdeaPayload: Encodable {
            let id: UUID
            let categoryId: UUID
            let content: String
            let voicePath: String?
            let drawingPath: String?
            let authorId: UUID
            let authorDisplayName: String
            let contributions: [ContributionRow]
            let attachments: [AttachmentRow]
            let isSensitive: Bool
            let completionPercentage: Int
            enum CodingKeys: String, CodingKey {
                case id, content, voicePath = "voice_path", drawingPath = "drawing_path", contributions, attachments, isSensitive = "is_sensitive", completionPercentage = "completion_percentage"
                case categoryId = "category_id"
                case authorId = "author_id"
                case authorDisplayName = "author_display_name"
            }
        }
        let payload = InsertIdeaPayload(
            id: idea.id,
            categoryId: idea.categoryId,
            content: idea.content,
            voicePath: idea.voicePath,
            drawingPath: idea.drawingPath,
            authorId: authorId,
            authorDisplayName: idea.authorDisplayName,
            contributions: idea.contributions.map { c in
                ContributionRow(
                    id: c.id,
                    authorDisplayName: c.authorDisplayName,
                    content: c.content,
                    createdAt: c.createdAt,
                    isPublic: c.isPublic,
                    reactions: c.reactions.map { r in ReactionRow(id: r.id, accountId: r.accountId, type: r.type) },
                    comments: c.comments.map { com in CommentRow(id: com.id, authorDisplayName: com.authorDisplayName, content: com.content, createdAt: com.createdAt, reactions: com.reactions.map { r in ReactionRow(id: r.id, accountId: r.accountId, type: r.type) }, voicePath: com.voicePath, authorId: com.authorId, editedAt: com.editedAt) },
                    voicePath: c.voicePath,
                    authorId: c.authorId,
                    editedAt: c.editedAt,
                    attachments: c.attachments.map { a in AttachmentRow(id: a.id, fileName: a.fileName, displayName: a.displayName, kind: a.kind.rawValue) },
                    drawingPath: c.drawingPath,
                    authorRating: c.authorRating,
                    authorRatingAt: c.authorRatingAt
                )
            },
            attachments: idea.attachments.map { a in AttachmentRow(id: a.id, fileName: a.fileName, displayName: a.displayName, kind: a.kind.rawValue) },
            isSensitive: idea.isSensitive,
            completionPercentage: idea.completionPercentage
        )
        try await client.from("ideas").insert(payload).execute()
    }
    
    static func updateIdea(ideaId: UUID, contributions: [Contribution], attachments: [Attachment]) async throws {
        let contributionsData = contributions.map { c in
            ContributionRow(
                id: c.id,
                authorDisplayName: c.authorDisplayName,
                content: c.content,
                createdAt: c.createdAt,
                isPublic: c.isPublic,
                reactions: c.reactions.map { r in ReactionRow(id: r.id, accountId: r.accountId, type: r.type) },
                comments: c.comments.map { com in CommentRow(id: com.id, authorDisplayName: com.authorDisplayName, content: com.content, createdAt: com.createdAt, reactions: com.reactions.map { r in ReactionRow(id: r.id, accountId: r.accountId, type: r.type) }, voicePath: com.voicePath, authorId: com.authorId, editedAt: com.editedAt) },
                voicePath: c.voicePath,
                authorId: c.authorId,
                editedAt: c.editedAt,
                attachments: c.attachments.map { a in AttachmentRow(id: a.id, fileName: a.fileName, displayName: a.displayName, kind: a.kind.rawValue) },
                drawingPath: c.drawingPath,
                authorRating: c.authorRating,
                authorRatingAt: c.authorRatingAt
            )
        }
        let attachmentsData = attachments.map { a in AttachmentRow(id: a.id, fileName: a.fileName, displayName: a.displayName, kind: a.kind.rawValue) }
        struct Payload: Encodable {
            let contributions: [ContributionRow]
            let attachments: [AttachmentRow]
        }
        let payload = Payload(contributions: contributionsData, attachments: attachmentsData)
        try await client.from("ideas").update(payload).eq("id", value: ideaId).execute()
    }
    
    static func getIdea(ideaId: UUID) async throws -> Idea? {
        let rows: [IdeaRow] = try await client.from("ideas").select().eq("id", value: ideaId).limit(1).execute().value
        return rows.first.map(ideaFromRow)
    }
    
    /// Rate an idea 1–5. One rating per user per idea (upsert). Requires current session.
    static func setIdeaRating(ideaId: UUID, rating: Int) async throws {
        let session = try await client.auth.session
        let raterId = session.user.id
        let clamped = min(5, max(1, rating))
        struct Row: Encodable {
            let idea_id: UUID
            let rater_id: UUID
            let rating: Int
        }
        try await client.from("idea_ratings")
            .upsert(Row(idea_id: ideaId, rater_id: raterId, rating: clamped), onConflict: "idea_id,rater_id")
            .execute()
    }
    
    /// Remove the current user's rating for an idea. Requires session.
    static func deleteIdeaRating(ideaId: UUID) async throws {
        let session = try await client.auth.session
        try await client.from("idea_ratings")
            .delete()
            .eq("idea_id", value: ideaId)
            .eq("rater_id", value: session.user.id)
            .execute()
    }
    
    /// Current user's ratings per idea (for showing "Your rating" and prefilling stars). Requires current session.
    static func getMyIdeaRatings() async throws -> [UUID: Int] {
        let session = try await client.auth.session
        struct IdeaRatingRow: Decodable {
            let idea_id: UUID
            let rating: Int
            enum CodingKeys: String, CodingKey { case idea_id, rating }
        }
        let rows: [IdeaRatingRow] = try await client.from("idea_ratings")
            .select("idea_id, rating")
            .eq("rater_id", value: session.user.id)
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.idea_id, $0.rating) })
    }
    
    static func deleteIdea(ideaId: UUID) async throws {
        try await client.from("ideas").delete().eq("id", value: ideaId).execute()
    }
    
    /// Submit a report for an idea (or idea + contribution). For later moderation. Requires session.
    static func reportIdea(ideaId: UUID, reason: String, details: String? = nil, contributionId: UUID? = nil) async throws {
        let session = try await client.auth.session
        struct Row: Encodable {
            let reporter_id: UUID
            let idea_id: UUID
            let contribution_id: UUID?
            let reason: String
            let details: String?
        }
        try await client.from("reports")
            .insert(Row(reporter_id: session.user.id, idea_id: ideaId, contribution_id: contributionId, reason: reason, details: details))
            .execute()
    }
    
    /// Hide an idea from the current user’s feed (“Don’t show this again”). Requires session.
    static func hideIdea(ideaId: UUID) async throws {
        let session = try await client.auth.session
        struct Row: Encodable {
            let user_id: UUID
            let idea_id: UUID
        }
        try await client.from("user_hidden_ideas").insert(Row(user_id: session.user.id, idea_id: ideaId)).execute()
    }
    
    /// Fetch the current user’s hidden idea ids. Requires session. Returns empty if not logged in or on error.
    static func getHiddenIdeaIds() async throws -> [UUID] {
        let session = try await client.auth.session
        struct Row: Decodable { let idea_id: UUID }
        let rows: [Row] = try await client.from("user_hidden_ideas")
            .select("idea_id")
            .eq("user_id", value: session.user.id)
            .execute()
            .value
        return rows.map(\.idea_id)
    }

    /// Delete all ideas authored by this user (e.g. when user deletes their account).
    static func deleteIdeasByAuthor(authorId: UUID) async throws {
        try await client.from("ideas").delete().eq("author_id", value: authorId).execute()
    }

    /// Mark an idea as finished (idea author only). Sets finished_at so no new completions are expected.
    static func updateIdeaFinished(ideaId: UUID, finishedAt: Date?) async throws {
        struct Payload: Encodable {
            let finished_at: Date?
            enum CodingKeys: String, CodingKey { case finished_at }
        }
        let payload = Payload(finished_at: finishedAt)
        try await client.from("ideas").update(payload).eq("id", value: ideaId).execute()
    }
    
    /// Idea author sets how complete the idea is (0–100%). Still accepting contributions until 100% or marked finished.
    static func updateIdeaCompletionPercentage(ideaId: UUID, percentage: Int) async throws {
        let clamped = min(100, max(0, percentage))
        struct Payload: Encodable {
            let completion_percentage: Int
        }
        try await client.from("ideas").update(Payload(completion_percentage: clamped)).eq("id", value: ideaId).execute()
    }
    
    static func listenCategories(completion: @escaping ([Category]) -> Void) -> SupabaseListenerRegistration {
        let reg = SupabaseListenerRegistration { }
        reg.startPolling {
            Task {
                let rows: [CategoryRow] = (try? await client.from("categories").select().execute().value) ?? []
                await MainActor.run {
                    let custom = rows.map { r in Category(id: r.id, displayName: r.displayName, actionVerb: r.actionVerb, isSystem: r.isSystem) }
                    completion(Category.defaultSystemCategories + custom.filter { !$0.isSystem })
                }
            }
        }
        return reg
    }
    
    static func addCategory(_ category: Category) async throws {
        let row = CategoryRow(id: category.id, displayName: category.displayName, actionVerb: category.actionVerb, isSystem: category.isSystem)
        try await client.from("categories").insert(row).execute()
    }
    
    static func removeCategory(id: UUID) async throws {
        try await client.from("categories").delete().eq("id", value: id).execute()
    }
    
    static func listenNotifications(targetDisplayName: String, completion: @escaping ([AppNotification]) -> Void) -> SupabaseListenerRegistration {
        let reg = SupabaseListenerRegistration { }
        reg.startPolling {
            Task {
                let rows: [NotificationRow] = (try? await client.from("notifications").select().in("target_display_name", values: [targetDisplayName, ""]).order("created_at", ascending: false).execute().value) ?? []
                await MainActor.run {
                    completion(rows.map { r in
                        AppNotification(
                            id: r.id,
                            type: AppNotificationType(rawValue: r.type) ?? .newIdea,
                            ideaId: r.ideaId,
                            contributionId: r.contributionId,
                            actorDisplayName: r.actorDisplayName,
                            targetDisplayName: r.targetDisplayName,
                            createdAt: r.createdAt,
                            isRead: r.isRead
                        )
                    })
                }
            }
        }
        return reg
    }
    
    static func addNotification(_ n: AppNotification) async throws {
        let row = NotificationRow(
            id: n.id,
            type: n.type.rawValue,
            ideaId: n.ideaId,
            contributionId: n.contributionId,
            actorDisplayName: n.actorDisplayName,
            targetDisplayName: n.targetDisplayName,
            createdAt: n.createdAt,
            isRead: n.isRead
        )
        try await client.from("notifications").insert(row).execute()
    }
    
    static func markNotificationRead(id: UUID) async throws {
        struct ReadUpdate: Encodable { let is_read: Bool = true }
        try await client.from("notifications").update(ReadUpdate()).eq("id", value: id).execute()
    }
    
    static func markAllNotificationsRead(ids: [UUID]) async throws {
        struct ReadUpdate: Encodable { let is_read: Bool = true }
        for id in ids {
            try await client.from("notifications").update(ReadUpdate()).eq("id", value: id).execute()
        }
    }
    
    /// Save device token for push notifications. Call when remote registration succeeds; uses current session to get app_user_id.
    static func savePushToken(appUserId: UUID, deviceToken: Data) async throws {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        struct Payload: Encodable {
            let app_user_id: UUID
            let device_token: String
        }
        let payload = Payload(app_user_id: appUserId, device_token: tokenString)
        try await client.from("push_tokens").upsert(payload, onConflict: "app_user_id,device_token").execute()
    }
}

// MARK: - Storage

extension SupabaseService {
    /// Upload to ideas/ideaId/fileName, or if contributionId is set to ideas/ideaId/completions/contribId/fileName.
    static func uploadAttachmentData(ideaId: UUID, data: Data, fileName: String, contributionId: UUID? = nil) async throws -> String {
        let path: String
        if let cid = contributionId {
            path = "ideas/\(ideaId.uuidString)/completions/\(cid.uuidString)/\(fileName)"
        } else {
            path = "ideas/\(ideaId.uuidString)/\(fileName)"
        }
        _ = try await client.storage.from("attachments").upload(path, data: data, options: FileOptions(upsert: true))
        return path
    }
    
    static func downloadURL(forStoragePath path: String) async throws -> URL {
        try await client.storage.from("attachments").createSignedURL(path: path, expiresIn: 3600)
    }
}

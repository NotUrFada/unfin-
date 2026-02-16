//
//  IdeaStore.swift
//  Unfin
//

import Foundation
import SwiftUI

final class IdeaStore: ObservableObject {
    @Published var ideas: [Idea] = []
    @Published var categories: [Category] = []
    @Published var currentUserId: UUID? {
        didSet {
            if let id = currentUserId?.uuidString {
                UserDefaults.standard.set(id, forKey: "currentUserId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentUserId")
            }
        }
    }
    @Published var currentUserName: String {
        didSet { UserDefaults.standard.set(currentUserName, forKey: "currentUserName") }
    }
    @Published var authError: String?
    @Published var postError: String?
    @Published private(set) var currentUserProfile: FirestoreUserProfile?
    
    private var ideasListener: SupabaseListenerRegistration?
    private var categoriesListener: SupabaseListenerRegistration?
    private var notificationsListener: SupabaseListenerRegistration?
    
    private let fileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ideas.json")
    }()
    
    private let attachmentsBaseURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Attachments", isDirectory: true)
    }()
    
    func attachmentsDirectory(for ideaId: UUID) -> URL {
        attachmentsBaseURL.appendingPathComponent(ideaId.uuidString, isDirectory: true)
    }
    
    func fileURL(ideaId: UUID, attachment: Attachment) -> URL {
        attachmentsDirectory(for: ideaId).appendingPathComponent(attachment.fileName)
    }
    
    /// Returns local file URL if the file exists; otherwise fetches download URL from Supabase Storage.
    func attachmentURL(ideaId: UUID, attachment: Attachment) async -> URL? {
        let local = fileURL(ideaId: ideaId, attachment: attachment)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        let path = "ideas/\(ideaId.uuidString)/\(attachment.fileName)"
        return try? await SupabaseService.downloadURL(forStoragePath: path)
    }
    
    @Published var notifications: [AppNotification] = []
    
    init() {
        let savedUserId = UserDefaults.standard.string(forKey: "currentUserId").flatMap { UUID(uuidString: $0) }
        self.currentUserId = savedUserId
        self.currentUserName = UserDefaults.standard.string(forKey: "currentUserName") ?? "Anonymous"
        
    }
    
    /// Call from the root view’s .task { await store.restoreSessionIfNeeded() } to restore session on launch.
    @MainActor
    func restoreSessionIfNeeded() async {
        if await SupabaseService.currentSession != nil {
            await handleSignedIn()
        } else {
            categories = Category.defaultSystemCategories
        }
    }
    
    @MainActor
    private func handleSignedIn() async {
        do {
            guard let result = try await SupabaseService.fetchUserProfile() else { return }
            currentUserId = result.appUserId
            currentUserName = result.displayName
            currentUserProfile = result.profile
            startListeners()
        } catch {
            authError = error.localizedDescription
        }
    }
    
    private func handleSignedOut() {
        ideasListener?.remove()
        categoriesListener?.remove()
        notificationsListener?.remove()
        ideasListener = nil
        categoriesListener = nil
        notificationsListener = nil
        ideas = []
        categories = Category.defaultSystemCategories
        notifications = []
        currentUserId = nil
        currentUserName = "Anonymous"
        currentUserProfile = nil
    }
    
    private func startListeners() {
        ideasListener?.remove()
        categoriesListener?.remove()
        notificationsListener?.remove()
        ideasListener = SupabaseService.listenIdeas { [weak self] list in
            DispatchQueue.main.async { self?.ideas = list }
        }
        categoriesListener = SupabaseService.listenCategories { [weak self] list in
            DispatchQueue.main.async { self?.categories = list }
        }
        notificationsListener = SupabaseService.listenNotifications(targetDisplayName: currentUserName) { [weak self] list in
            DispatchQueue.main.async { self?.notifications = list }
        }
    }
    
    var isLoggedIn: Bool { currentUserId != nil }
    
    var notificationsForCurrentUser: [AppNotification] {
        notifications.sorted { $0.createdAt > $1.createdAt }
    }
    
    var unreadNotificationCount: Int {
        notificationsForCurrentUser.filter { !$0.isRead }.count
    }
    
    func markNotificationRead(id: UUID) {
        Task {
            try? await SupabaseService.markNotificationRead(id: id)
        }
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            var n = notifications[idx]
            n.isRead = true
            notifications[idx] = n
        }
    }
    
    func markAllNotificationsRead() {
        let ids = notificationsForCurrentUser.filter { !$0.isRead }.map(\.id)
        Task {
            try? await SupabaseService.markAllNotificationsRead(ids: ids)
        }
        notifications = notifications.map { var n = $0; n.isRead = true; return n }
    }
    
    var needsOnboarding: Bool {
        currentUserProfile?.glyphGrid == nil
    }
    
    func account(byId id: UUID) -> Account? {
        guard id == currentUserId else { return nil }
        guard let p = currentUserProfile, let appUserId = currentUserId else { return nil }
        return Account(
            id: appUserId,
            email: p.email ?? "",
            passwordHash: "",
            displayName: p.displayName,
            glyphGrid: p.glyphGrid,
            auraPaletteIndex: p.auraPaletteIndex,
            auraVariant: p.auraVariant
        )
    }
    
    func signUp(email: String, password: String, displayName: String) async throws {
        authError = nil
        let emailLower = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !emailLower.isEmpty, !password.isEmpty, !name.isEmpty else {
            throw NSError(domain: "IdeaStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fill in all fields."])
        }
        let (appUserId, displayNameResult) = try await SupabaseService.signUp(email: emailLower, password: password, displayName: name)
        await MainActor.run {
            currentUserId = appUserId
            currentUserName = displayNameResult
            currentUserProfile = FirestoreUserProfile(appUserId: appUserId.uuidString, displayName: displayNameResult, email: emailLower, auraVariant: nil, auraPaletteIndex: nil, glyphGrid: nil, createdAt: nil)
            startListeners()
        }
    }
    
    func login(email: String, password: String) async throws {
        authError = nil
        let emailLower = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let (appUserId, displayName) = try await SupabaseService.login(email: emailLower, password: password)
        let profileResult = try? await SupabaseService.fetchUserProfile()
        await MainActor.run {
            currentUserId = appUserId
            currentUserName = displayName
            if let result = profileResult {
                currentUserProfile = result.profile
            }
            startListeners()
        }
    }
    
    func logout() {
        Task {
            try? await SupabaseService.logout()
            await MainActor.run { handleSignedOut() }
        }
    }
    
    var currentAccount: Account? {
        guard let id = currentUserId else { return nil }
        return account(byId: id)
    }
    
    func updateAccountDisplayName(_ name: String) {
        guard !name.isEmpty else { return }
        Task {
            try? await SupabaseService.updateUserProfile(displayName: name)
            await MainActor.run {
                currentUserName = name
                currentUserProfile?.displayName = name
            }
        }
    }
    
    func completeOnboarding(glyphGrid: String, auraPaletteIndex: Int?, auraVariant: Int?, displayName: String?) {
        // Update local state immediately so the UI transitions to the main app right away
        let name = (displayName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? currentUserName
        if !name.isEmpty { currentUserName = name }
        if var p = currentUserProfile {
            p.glyphGrid = glyphGrid
            p.auraPaletteIndex = auraPaletteIndex
            p.auraVariant = auraVariant
            p.displayName = name
            currentUserProfile = p
        } else if let id = currentUserId {
            // Profile can be nil e.g. if fetch failed after login; create one so we can leave onboarding
            currentUserProfile = FirestoreUserProfile(
                appUserId: id.uuidString,
                displayName: name,
                email: nil,
                auraVariant: auraVariant,
                auraPaletteIndex: auraPaletteIndex,
                glyphGrid: glyphGrid,
                createdAt: Date()
            )
        }
        Task {
            try? await SupabaseService.updateUserProfile(displayName: displayName, auraVariant: auraVariant, auraPaletteIndex: auraPaletteIndex, glyphGrid: glyphGrid)
        }
    }
    
    func updateAccountAura(auraVariant: Int) {
        Task {
            try? await SupabaseService.updateUserProfile(auraVariant: auraVariant, auraPaletteIndex: nil)
            await MainActor.run {
                if var p = currentUserProfile {
                    p.auraVariant = auraVariant
                    p.auraPaletteIndex = nil
                    currentUserProfile = p
                }
            }
        }
    }
    
    func category(byId id: UUID) -> Category? {
        categories.first { $0.id == id }
    }
    
    func categoryDisplayName(byId id: UUID) -> String {
        category(byId: id)?.displayName ?? "Uncategorized"
    }
    
    func categoryActionVerb(byId id: UUID) -> String {
        category(byId: id)?.actionVerb ?? "Complete"
    }
    
    @discardableResult
    func addCategory(displayName: String, actionVerb: String = "Complete") -> Category {
        let cat = Category(id: UUID(), displayName: displayName, actionVerb: actionVerb, isSystem: false)
        categories.append(cat)
        Task {
            try? await SupabaseService.addCategory(cat)
        }
        return cat
    }
    
    func removeCategory(id: UUID) {
        guard let cat = category(byId: id), !cat.isSystem else { return }
        categories.removeAll { $0.id == id }
        Task {
            try? await SupabaseService.removeCategory(id: id)
        }
    }
    
    func deleteAccount() {
        let nameToRemove = currentUserName
        if let id = currentUserId {
            currentUserId = nil
            currentUserName = "Anonymous"
            currentUserProfile = nil
            handleSignedOut()
        }
    }
    
    func addIdea(_ idea: Idea) async throws {
        postError = nil
        guard let authorId = currentUserId else {
            throw NSError(domain: "IdeaStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "You must be signed in to post."])
        }
        let dir = attachmentsDirectory(for: idea.id)
        for att in idea.attachments {
            let localURL = dir.appendingPathComponent(att.fileName)
            if FileManager.default.fileExists(atPath: localURL.path),
               let data = try? Data(contentsOf: localURL) {
                _ = try await SupabaseService.uploadAttachmentData(ideaId: idea.id, data: data, fileName: att.fileName)
            }
        }
        try await SupabaseService.addIdea(idea, authorId: authorId)
        try? await SupabaseService.addNotification(AppNotification(type: .newIdea, ideaId: idea.id, actorDisplayName: currentUserName, targetDisplayName: ""))
        await MainActor.run {
            ideas.insert(idea, at: 0)
        }
    }
    
    func addContribution(ideaId: UUID, content: String, isPublic: Bool = true) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        let idea = ideas[index]
        let contribution = Contribution(authorDisplayName: currentUserName, content: content, isPublic: isPublic)
        ideas[index].contributions.append(contribution)
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[index].contributions, attachments: ideas[index].attachments)
            if idea.authorDisplayName != currentUserName {
                try? await SupabaseService.addNotification(AppNotification(type: .contribution, ideaId: ideaId, contributionId: contribution.id, actorDisplayName: currentUserName, targetDisplayName: idea.authorDisplayName))
            }
        }
    }
    
    func toggleReaction(ideaId: UUID, contributionId: UUID, type: String) {
        guard let userId = currentUserId,
              let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }) else { return }
        var idea = ideas[ideaIndex]
        var contrib = idea.contributions[contribIndex]
        let existingIndex = contrib.reactions.firstIndex { $0.accountId == userId }
        if let idx = existingIndex {
            if contrib.reactions[idx].type == type {
                contrib.reactions.remove(at: idx)
            } else {
                contrib.reactions[idx] = Reaction(accountId: userId, type: type)
            }
        } else {
            contrib.reactions.append(Reaction(accountId: userId, type: type))
            let authorName = contrib.authorDisplayName
            idea.contributions[contribIndex] = contrib
            ideas[ideaIndex] = idea
            Task {
                try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[ideaIndex].contributions, attachments: ideas[ideaIndex].attachments)
                if authorName != currentUserName {
                    try? await SupabaseService.addNotification(AppNotification(type: .reaction, ideaId: ideaId, contributionId: contributionId, actorDisplayName: currentUserName, targetDisplayName: authorName))
                }
            }
            return
        }
        idea.contributions[contribIndex] = contrib
        ideas[ideaIndex] = idea
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[ideaIndex].contributions, attachments: ideas[ideaIndex].attachments)
        }
    }
    
    func addComment(ideaId: UUID, contributionId: UUID, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }) else { return }
        var idea = ideas[ideaIndex]
        var contrib = idea.contributions[contribIndex]
        let authorName = contrib.authorDisplayName
        contrib.comments.append(Comment(authorDisplayName: currentUserName, content: trimmed))
        idea.contributions[contribIndex] = contrib
        ideas[ideaIndex] = idea
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[ideaIndex].contributions, attachments: ideas[ideaIndex].attachments)
            if authorName != currentUserName {
                try? await SupabaseService.addNotification(AppNotification(type: .comment, ideaId: ideaId, contributionId: contributionId, actorDisplayName: currentUserName, targetDisplayName: authorName))
            }
        }
    }
    
    func currentUserReactionType(for contribution: Contribution) -> String? {
        guard let userId = currentUserId else { return nil }
        return contribution.reactions.first { $0.accountId == userId }?.type
    }
    
    func didCurrentUserLike(contribution: Contribution) -> Bool {
        currentUserReactionType(for: contribution) == ReactionType.heart.rawValue
    }
    
    func updateIdeaContent(ideaId: UUID, newContent: String) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        ideas[index].content = newContent
    }
    
    func idea(byId id: UUID) -> Idea? {
        ideas.first { $0.id == id }
    }
    
    func deleteIdea(ideaId: UUID) async throws {
        guard let index = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        let idea = ideas[index]
        guard idea.authorDisplayName == currentUserName else {
            throw NSError(domain: "IdeaStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "You can only delete your own ideas."])
        }
        try await SupabaseService.deleteIdea(ideaId: ideaId)
        await MainActor.run {
            ideas.removeAll { $0.id == ideaId }
        }
    }
}

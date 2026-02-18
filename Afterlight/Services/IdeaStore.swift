//
//  IdeaStore.swift
//  Unfin
//

import Foundation
import SwiftUI
import UserNotifications

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
    /// Set to true after restoreSessionIfNeeded() runs so we don’t show onboarding until we know the profile.
    @Published private(set) var hasRestoredSession = false
    
    private var ideasListener: SupabaseListenerRegistration?
    private var categoriesListener: SupabaseListenerRegistration?
    private var notificationsListener: SupabaseListenerRegistration?
    /// IDs we've already seen so we only show a popup for newly arrived notifications.
    private var previousNotificationIds: Set<UUID> = []
    
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
    
    /// Returns a local file URL so Quick Look can preview. Uses cache if present; otherwise downloads from Supabase and saves to disk.
    func attachmentURL(ideaId: UUID, attachment: Attachment) async -> URL? {
        let local = fileURL(ideaId: ideaId, attachment: attachment)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        let path = "ideas/\(ideaId.uuidString)/\(attachment.fileName)"
        guard let remoteURL = try? await SupabaseService.downloadURL(forStoragePath: path) else { return nil }
        // Quick Look only works with local file URLs; download and cache.
        guard let data = try? await URLSession.shared.data(from: remoteURL).0 else { return nil }
        try? FileManager.default.createDirectory(at: attachmentsDirectory(for: ideaId), withIntermediateDirectories: true)
        guard (try? data.write(to: local, options: .atomic)) != nil else { return nil }
        return local
    }
    
    /// Cache directory for a completion's attachments: Attachments/ideaId/completions/contribId/
    private func completionAttachmentsDirectory(ideaId: UUID, contributionId: UUID) -> URL {
        attachmentsBaseURL.appendingPathComponent(ideaId.uuidString, isDirectory: true).appendingPathComponent("completions", isDirectory: true).appendingPathComponent(contributionId.uuidString, isDirectory: true)
    }
    
    /// Returns a local file URL for a completion attachment (downloads and caches if needed).
    func attachmentURLForCompletion(ideaId: UUID, contributionId: UUID, attachment: Attachment) async -> URL? {
        let dir = completionAttachmentsDirectory(ideaId: ideaId, contributionId: contributionId)
        let local = dir.appendingPathComponent(attachment.fileName)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        let path = "ideas/\(ideaId.uuidString)/completions/\(contributionId.uuidString)/\(attachment.fileName)"
        guard let remoteURL = try? await SupabaseService.downloadURL(forStoragePath: path) else { return nil }
        guard let data = try? await URLSession.shared.data(from: remoteURL).0 else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard (try? data.write(to: local, options: .atomic)) != nil else { return nil }
        return local
    }
    
    /// Upload files for a completion; returns the Attachment list to pass to addContribution.
    func uploadCompletionAttachments(ideaId: UUID, contributionId: UUID, files: [(url: URL, displayName: String, kind: AttachmentKind)]) async throws -> [Attachment] {
        var result: [Attachment] = []
        for file in files {
            let data = try Data(contentsOf: file.url)
            let fileName = "\(UUID().uuidString)_\(file.displayName)"
            _ = try await SupabaseService.uploadAttachmentData(ideaId: ideaId, data: data, fileName: fileName, contributionId: contributionId)
            result.append(Attachment(fileName: fileName, displayName: file.displayName, kind: file.kind))
        }
        return result
    }
    
    @Published var notifications: [AppNotification] = []
    
    init() {
        #if DEBUG
        // When running from Xcode, start at the welcome screen (don’t restore session).
        self.currentUserId = nil
        self.currentUserName = "Anonymous"
        #else
        let savedUserId = UserDefaults.standard.string(forKey: "currentUserId").flatMap { UUID(uuidString: $0) }
        self.currentUserId = savedUserId
        self.currentUserName = UserDefaults.standard.string(forKey: "currentUserName") ?? "Anonymous"
        #endif
    }
    
    /// Call from the root view’s .task { await store.restoreSessionIfNeeded() } to restore session on launch.
    @MainActor
    func restoreSessionIfNeeded() async {
        #if DEBUG
        // When running from Xcode, skip restore so the app starts at the welcome screen.
        categories = Category.defaultSystemCategories
        hasRestoredSession = true
        return
        #endif
        if await SupabaseService.currentSession != nil {
            await handleSignedIn()
        } else {
            categories = Category.defaultSystemCategories
        }
        hasRestoredSession = true
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
            DispatchQueue.main.async {
                guard let self = self else { return }
                let newIds = Set(list.map(\.id))
                if self.previousNotificationIds.isEmpty {
                    self.previousNotificationIds = newIds
                    self.notifications = list
                    return
                }
                let newArrivals = list.filter { !self.previousNotificationIds.contains($0.id) && !$0.isRead }
                self.previousNotificationIds = newIds
                self.notifications = list
                for n in newArrivals {
                    self.showNotificationBanner(for: n)
                }
            }
        }
        AppDelegate.requestPushPermissionAndRegister()
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
    
    /// Schedules a local notification so a banner pops up for this notification (in-app or in background).
    private func showNotificationBanner(for n: AppNotification) {
        let content = UNMutableNotificationContent()
        content.title = "Unfin"
        content.body = n.summaryText
        content.sound = .default
        content.userInfo = ["ideaId": n.ideaId.uuidString, "notificationId": n.id.uuidString]
        let request = UNNotificationRequest(
            identifier: n.id.uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    var needsOnboarding: Bool {
        currentUserProfile?.glyphGrid == nil
    }
    
    /// Current consecutive-day streak (post idea, contribution, or comment). Read from profile; updated when recordActivity() runs.
    var currentStreak: Int {
        currentUserProfile?.streakCount ?? 0
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
            currentUserProfile = FirestoreUserProfile(appUserId: appUserId.uuidString, displayName: displayNameResult, email: emailLower, auraVariant: nil, auraPaletteIndex: nil, glyphGrid: nil, createdAt: nil, streakCount: 0, streakLastDate: nil)
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
                createdAt: Date(),
                streakCount: 0,
                streakLastDate: nil
            )
        }
        Task {
            try? await SupabaseService.updateUserProfile(displayName: displayName, auraVariant: auraVariant, auraPaletteIndex: auraPaletteIndex, glyphGrid: glyphGrid)
        }
    }
    
    func updateAccountAura(auraVariant: Int) {
        // Update local state immediately so background and avatar reflect right away
        if var p = currentUserProfile {
            p.auraVariant = auraVariant
            p.auraPaletteIndex = nil
            currentUserProfile = p
        }
        Task {
            try? await SupabaseService.updateUserProfile(auraVariant: auraVariant, auraPaletteIndex: nil)
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
        let newStreak = try? await SupabaseService.recordActivity()
        await MainActor.run {
            ideas.insert(idea, at: 0)
            if let s = newStreak, var p = currentUserProfile {
                p.streakCount = s
                p.streakLastDate = Date()
                currentUserProfile = p
            }
        }
    }
    
    func addContribution(ideaId: UUID, content: String, isPublic: Bool = true, voicePath: String? = nil, attachments: [Attachment] = [], contributionId: UUID? = nil) {
        guard let userId = currentUserId, let index = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        let idea = ideas[index]
        let contribution = Contribution(id: contributionId ?? UUID(), authorDisplayName: currentUserName, content: content, isPublic: isPublic, voicePath: voicePath, authorId: userId, attachments: attachments)
        ideas[index].contributions.append(contribution)
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[index].contributions, attachments: ideas[index].attachments)
            if idea.authorDisplayName != currentUserName {
                try? await SupabaseService.addNotification(AppNotification(type: .contribution, ideaId: ideaId, contributionId: contribution.id, actorDisplayName: currentUserName, targetDisplayName: idea.authorDisplayName))
            }
            let newStreak = try? await SupabaseService.recordActivity()
            await MainActor.run {
                if let s = newStreak, var p = currentUserProfile {
                    p.streakCount = s
                    p.streakLastDate = Date()
                    currentUserProfile = p
                }
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
    
    func addComment(ideaId: UUID, contributionId: UUID, content: String, voicePath: String? = nil) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = !trimmed.isEmpty || voicePath != nil
        guard hasContent,
              let userId = currentUserId,
              let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }) else { return }
        var idea = ideas[ideaIndex]
        var contrib = idea.contributions[contribIndex]
        let authorName = contrib.authorDisplayName
        contrib.comments.append(Comment(authorDisplayName: currentUserName, content: trimmed, voicePath: voicePath, authorId: userId))
        idea.contributions[contribIndex] = contrib
        ideas[ideaIndex] = idea
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[ideaIndex].contributions, attachments: ideas[ideaIndex].attachments)
            if authorName != currentUserName {
                try? await SupabaseService.addNotification(AppNotification(type: .comment, ideaId: ideaId, contributionId: contributionId, actorDisplayName: currentUserName, targetDisplayName: authorName))
            }
            let newStreak = try? await SupabaseService.recordActivity()
            await MainActor.run {
                if let s = newStreak, var p = currentUserProfile {
                    p.streakCount = s
                    p.streakLastDate = Date()
                    currentUserProfile = p
                }
            }
        }
    }
    
    func currentUserReactionType(for contribution: Contribution) -> String? {
        guard let userId = currentUserId else { return nil }
        return contribution.reactions.first { $0.accountId == userId }?.type
    }
    
    func currentUserReactionType(for comment: Comment) -> String? {
        guard let userId = currentUserId else { return nil }
        return comment.reactions.first { $0.accountId == userId }?.type
    }
    
    func toggleReactionOnComment(ideaId: UUID, contributionId: UUID, commentId: UUID, type: String) {
        guard let userId = currentUserId,
              let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }),
              let commentIndex = ideas[ideaIndex].contributions[contribIndex].comments.firstIndex(where: { $0.id == commentId }) else { return }
        var idea = ideas[ideaIndex]
        var contrib = idea.contributions[contribIndex]
        var comment = contrib.comments[commentIndex]
        let existingIndex = comment.reactions.firstIndex { $0.accountId == userId }
        if let idx = existingIndex {
            if comment.reactions[idx].type == type {
                comment.reactions.remove(at: idx)
            } else {
                comment.reactions[idx] = Reaction(accountId: userId, type: type)
            }
        } else {
            comment.reactions.append(Reaction(accountId: userId, type: type))
            let authorName = comment.authorDisplayName
            contrib.comments[commentIndex] = comment
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
        contrib.comments[commentIndex] = comment
        idea.contributions[contribIndex] = contrib
        ideas[ideaIndex] = idea
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[ideaIndex].contributions, attachments: ideas[ideaIndex].attachments)
        }
    }
    
    func didCurrentUserLike(contribution: Contribution) -> Bool {
        currentUserReactionType(for: contribution) == ReactionType.heart.rawValue
    }
    
    /// Returns whether the current user can edit/delete this contribution (author).
    func canCurrentUserEditContribution(_ contribution: Contribution) -> Bool {
        guard let userId = currentUserId else { return false }
        if let aid = contribution.authorId { return aid == userId }
        return contribution.authorDisplayName == currentUserName
    }
    
    /// Returns whether the current user can edit/delete this comment.
    func canCurrentUserEditComment(_ comment: Comment) -> Bool {
        guard let userId = currentUserId else { return false }
        if let aid = comment.authorId { return aid == userId }
        return comment.authorDisplayName == currentUserName
    }
    
    func updateContribution(ideaId: UUID, contributionId: UUID, newContent: String, newVoicePath: String?) {
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }),
              canCurrentUserEditContribution(ideas[ideaIndex].contributions[contribIndex]) else { return }
        ideas[ideaIndex].contributions[contribIndex].content = newContent
        ideas[ideaIndex].contributions[contribIndex].voicePath = newVoicePath
        ideas[ideaIndex].contributions[contribIndex].editedAt = Date()
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[ideaIndex].contributions, attachments: ideas[ideaIndex].attachments)
        }
    }
    
    func deleteContribution(ideaId: UUID, contributionId: UUID) {
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }),
              canCurrentUserEditContribution(ideas[ideaIndex].contributions[contribIndex]) else { return }
        ideas[ideaIndex].contributions.remove(at: contribIndex)
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[ideaIndex].contributions, attachments: ideas[ideaIndex].attachments)
        }
    }
    
    func updateComment(ideaId: UUID, contributionId: UUID, commentId: UUID, newContent: String, newVoicePath: String?) {
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }),
              let commentIndex = ideas[ideaIndex].contributions[contribIndex].comments.firstIndex(where: { $0.id == commentId }),
              canCurrentUserEditComment(ideas[ideaIndex].contributions[contribIndex].comments[commentIndex]) else { return }
        ideas[ideaIndex].contributions[contribIndex].comments[commentIndex].content = newContent
        ideas[ideaIndex].contributions[contribIndex].comments[commentIndex].voicePath = newVoicePath
        ideas[ideaIndex].contributions[contribIndex].comments[commentIndex].editedAt = Date()
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[ideaIndex].contributions, attachments: ideas[ideaIndex].attachments)
        }
    }
    
    func deleteComment(ideaId: UUID, contributionId: UUID, commentId: UUID) {
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }),
              let commentIndex = ideas[ideaIndex].contributions[contribIndex].comments.firstIndex(where: { $0.id == commentId }),
              canCurrentUserEditComment(ideas[ideaIndex].contributions[contribIndex].comments[commentIndex]) else { return }
        ideas[ideaIndex].contributions[contribIndex].comments.remove(at: commentIndex)
        Task {
            try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: ideas[ideaIndex].contributions, attachments: ideas[ideaIndex].attachments)
        }
    }
    
    /// Upload voice audio for an idea; returns storage path e.g. "ideas/ideaId/voice.m4a".
    func uploadVoiceForIdea(ideaId: UUID, fileURL: URL) async throws -> String {
        let data = try Data(contentsOf: fileURL)
        let fileName = "voice.m4a"
        _ = try await SupabaseService.uploadAttachmentData(ideaId: ideaId, data: data, fileName: fileName)
        return "ideas/\(ideaId.uuidString)/\(fileName)"
    }
    
    /// Upload voice audio for a contribution; returns storage path.
    func uploadVoiceForContribution(ideaId: UUID, fileURL: URL) async throws -> String {
        let data = try Data(contentsOf: fileURL)
        let fileName = "voice_\(UUID().uuidString).m4a"
        _ = try await SupabaseService.uploadAttachmentData(ideaId: ideaId, data: data, fileName: fileName)
        return "ideas/\(ideaId.uuidString)/\(fileName)"
    }
    
    /// Upload voice audio for a comment; returns storage path.
    func uploadVoiceForComment(ideaId: UUID, fileURL: URL) async throws -> String {
        let data = try Data(contentsOf: fileURL)
        let fileName = "voice_comment_\(UUID().uuidString).m4a"
        _ = try await SupabaseService.uploadAttachmentData(ideaId: ideaId, data: data, fileName: fileName)
        return "ideas/\(ideaId.uuidString)/\(fileName)"
    }
    
    /// Signed URL for playing a voice recording (idea, contribution, or comment voice path).
    func voiceURL(storagePath: String) async -> URL? {
        try? await SupabaseService.downloadURL(forStoragePath: storagePath)
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
        let isOwner = idea.authorId == currentUserId
            || (idea.authorId == nil && idea.authorDisplayName == currentUserName)
        guard isOwner else {
            throw NSError(domain: "IdeaStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "You can only delete your own ideas."])
        }
        try await SupabaseService.deleteIdea(ideaId: ideaId)
        await MainActor.run {
            ideas.removeAll { $0.id == ideaId }
        }
    }
}

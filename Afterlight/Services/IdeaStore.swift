//
//  IdeaStore.swift
//  Unfin
//

import Foundation
import SwiftUI
import UserNotifications

final class IdeaStore: ObservableObject {
    /// Runs async work from a synchronous context. Use this instead of inline `Task { await ... }` to avoid "async call in a function that does not support" in some toolchains.
    private func runAsync(_ work: @escaping () async -> Void) {
        Task { await work() }
    }
    
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
    
    /// Current user’s rating (1–5) per idea id. Loaded when ideas load and when user is logged in.
    @Published var myIdeaRatings: [UUID: Int] = [:]
    
    /// Idea ids the current user has hidden (“Don’t show this again”). Loaded when signed in; filter feed/explore by this.
    @Published var hiddenIdeaIds: Set<UUID> = []
    
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
    
    private func handleSignedIn() async {
        do {
            guard let result = try await SupabaseService.fetchUserProfile() else { return }
            currentUserId = result.appUserId
            currentUserName = result.displayName
            currentUserProfile = result.profile
            if result.profile.glyphGrid != nil {
                UserDefaults.standard.removeObject(forKey: Self.justSignedUpForOnboardingKey)
            }
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
        hiddenIdeaIds = []
        currentUserId = nil
        currentUserName = "Anonymous"
        currentUserProfile = nil
    }
    
    private func startListeners() {
        ideasListener?.remove()
        categoriesListener?.remove()
        notificationsListener?.remove()
        ideasListener = SupabaseService.listenIdeas { [weak self] list in
            DispatchQueue.main.async {
                self?.ideas = list
                self?.loadMyIdeaRatingsIfNeeded()
            }
        }
        runAsync { await self.loadHiddenIdeaIds() }
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
        runAsync { await self.markNotificationReadInBackground(id: id) }
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            var n = notifications[idx]
            n.isRead = true
            notifications[idx] = n
        }
    }
    
    func markAllNotificationsRead() {
        let ids = notificationsForCurrentUser.filter { !$0.isRead }.map(\.id)
        runAsync { await self.markAllNotificationsReadInBackground(ids: ids) }
        notifications = notifications.map { var n = $0; n.isRead = true; return n }
    }
    
    private func markNotificationReadInBackground(id: UUID) async {
        try? await SupabaseService.markNotificationRead(id: id)
    }
    
    private func markAllNotificationsReadInBackground(ids: [UUID]) async {
        try? await SupabaseService.markAllNotificationsRead(ids: ids)
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
    
    private static let justSignedUpForOnboardingKey = "justSignedUpForOnboarding"
    
    /// Onboarding (aura shuffle) only for new users who just signed up, not when logging in.
    var needsOnboarding: Bool {
        (currentUserProfile?.glyphGrid == nil) && UserDefaults.standard.bool(forKey: Self.justSignedUpForOnboardingKey)
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
            UserDefaults.standard.set(true, forKey: Self.justSignedUpForOnboardingKey)
        }
    }
    
    func login(email: String, password: String) async throws {
        authError = nil
        let emailLower = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let (appUserId, displayName, profileFromLogin) = try await SupabaseService.login(email: emailLower, password: password)
        UserDefaults.standard.removeObject(forKey: Self.justSignedUpForOnboardingKey)
        // Use profile from login response (includes saved aura) so avatar is correct immediately; fallback to fetch if nil
        let fetchedProfile = try? await SupabaseService.fetchUserProfile()
        let profile = profileFromLogin ?? fetchedProfile?.profile
        await MainActor.run {
            currentUserId = appUserId
            currentUserName = displayName
            currentUserProfile = profile
            startListeners()
        }
    }
    
    func logout() {
        runAsync { await self.logoutInBackground() }
    }
    
    private func logoutInBackground() async {
        try? await SupabaseService.logout()
        await MainActor.run { handleSignedOut() }
    }
    
    var currentAccount: Account? {
        guard let id = currentUserId else { return nil }
        return account(byId: id)
    }
    
    /// Pull-to-refresh: fetches ideas, categories, notifications, profile, hidden ids, and ratings so the feed feels current.
    func refreshContent() async {
        let newIdeas = (try? await SupabaseService.fetchIdeas()) ?? ideas
        let newCategories = (try? await SupabaseService.fetchCategories()) ?? categories
        await MainActor.run {
            ideas = newIdeas
            categories = newCategories
            loadMyIdeaRatingsIfNeeded()
        }
        await loadHiddenIdeaIds()
        if currentUserId != nil {
            await refreshUserProfileInBackground()
            let newNotifications = (try? await SupabaseService.fetchNotifications(targetDisplayName: currentUserName)) ?? notifications
            await MainActor.run {
                notifications = newNotifications
            }
        }
    }

    /// Refreshes current user's profile from Supabase (aura, display name, etc.). Call when opening Profile tab so gradient and avatar show saved aura.
    func refreshUserProfileIfNeeded() {
        guard currentUserId != nil else { return }
        runAsync { await self.refreshUserProfileInBackground() }
    }
    
    private func refreshUserProfileInBackground() async {
        guard let result = try? await SupabaseService.fetchUserProfile() else { return }
        await MainActor.run {
            currentUserName = result.displayName
            currentUserProfile = result.profile
        }
    }
    
    /// Updates display name if it's not already taken by another user. Returns true if updated, false if name is taken.
    func updateAccountDisplayName(_ name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let authId = await SupabaseService.currentAuthUserId() else { return false }
        if (try? await SupabaseService.isDisplayNameTaken(trimmed, excludingAuthId: authId)) == true {
            return false
        }
        do {
            try await SupabaseService.updateUserProfile(displayName: trimmed)
            await MainActor.run {
                currentUserName = trimmed
                currentUserProfile?.displayName = trimmed
            }
            return true
        } catch {
            return false
        }
    }
    
    /// Returns true if this display name is already taken by another user (for onboarding / profile edit).
    func isDisplayNameTakenForCurrentUser(_ name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard let authId = await SupabaseService.currentAuthUserId() else { return false }
        return (try? await SupabaseService.isDisplayNameTaken(trimmed, excludingAuthId: authId)) ?? false
    }

    /// Returns a display name that is not taken (for signup). Does not update anything.
    func generateAvailableDisplayName() async -> String? {
        try? await SupabaseService.generateUniqueDisplayName(excludingAuthId: nil)
    }

    /// Generates a display name that is not taken and updates the account with it. Returns the new name or nil on failure.
    func generateAndSetRandomDisplayName() async -> String? {
        let authId = await SupabaseService.currentAuthUserId()
        guard let name = try? await SupabaseService.generateUniqueDisplayName(excludingAuthId: authId) else { return nil }
        do {
            try await SupabaseService.updateUserProfile(displayName: name)
            await MainActor.run {
                currentUserName = name
                currentUserProfile?.displayName = name
            }
            return name
        } catch {
            return nil
        }
    }
    
    func completeOnboarding(glyphGrid: String, auraPaletteIndex: Int?, auraVariant: Int?, displayName: String?) {
        UserDefaults.standard.removeObject(forKey: Self.justSignedUpForOnboardingKey)
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
        runAsync { await self.completeOnboardingInBackground(displayName: displayName, auraVariant: auraVariant, auraPaletteIndex: auraPaletteIndex, glyphGrid: glyphGrid) }
    }
    
    private func completeOnboardingInBackground(displayName: String?, auraVariant: Int?, auraPaletteIndex: Int?, glyphGrid: String?) async {
        try? await SupabaseService.updateUserProfile(displayName: displayName, auraVariant: auraVariant, auraPaletteIndex: auraPaletteIndex, glyphGrid: glyphGrid)
    }
    
    func updateAccountAura(auraVariant: Int) {
        // Update local state immediately so background and avatar reflect right away
        if var p = currentUserProfile {
            p.auraVariant = auraVariant
            p.auraPaletteIndex = nil
            currentUserProfile = p
        } else if let id = currentUserId {
            currentUserProfile = FirestoreUserProfile(
                appUserId: id.uuidString,
                displayName: currentUserName,
                email: nil,
                auraVariant: auraVariant,
                auraPaletteIndex: nil,
                glyphGrid: nil,
                createdAt: nil,
                streakCount: 0,
                streakLastDate: nil
            )
        }
        runAsync { await self.updateAuraInBackground(auraVariant: auraVariant) }
    }
    
    private func updateAuraInBackground(auraVariant: Int) async {
        try? await SupabaseService.updateUserProfile(auraVariant: auraVariant, auraPaletteIndex: nil)
        await MainActor.run { refreshUserProfileIfNeeded() }
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
        let creatorId = currentUserId
        let cat = Category(id: UUID(), displayName: displayName, actionVerb: actionVerb, isSystem: false, creatorId: creatorId)
        categories.append(cat)
        runAsync { await self.addCategoryInBackground(cat, creatorId: creatorId) }
        return cat
    }
    
    func removeCategory(id: UUID) {
        guard let cat = category(byId: id), !cat.isSystem else { return }
        guard cat.creatorId == currentUserId else { return }
        categories.removeAll { $0.id == id }
        runAsync { await self.removeCategoryInBackground(id: id) }
    }
    
    private func addCategoryInBackground(_ cat: Category, creatorId: UUID?) async {
        guard let creatorId = creatorId else { return }
        try? await SupabaseService.addCategory(cat, creatorId: creatorId)
    }
    
    private func removeCategoryInBackground(id: UUID) async {
        try? await SupabaseService.removeCategory(id: id)
    }
    
    func deleteAccount() {
        guard let authorId = currentUserId else {
            currentUserName = "Anonymous"
            handleSignedOut()
            return
        }
        runAsync { await self.deleteAccountInBackground(authorId: authorId) }
    }
    
    private func deleteAccountInBackground(authorId: UUID) async {
        do {
            try await SupabaseService.deleteIdeasByAuthor(authorId: authorId)
            await MainActor.run { ideas.removeAll { $0.authorId == authorId } }
            try await SupabaseService.logout()
            await MainActor.run {
                currentUserId = nil
                currentUserName = "Anonymous"
                currentUserProfile = nil
                handleSignedOut()
            }
        } catch {
            await MainActor.run {
                currentUserId = nil
                currentUserName = "Anonymous"
                currentUserProfile = nil
                handleSignedOut()
            }
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
    
    func addContribution(ideaId: UUID, content: String, isPublic: Bool = true, voicePath: String? = nil, attachments: [Attachment] = [], drawingPath: String? = nil, contributionId: UUID? = nil) {
        guard let userId = currentUserId, let index = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        guard !isCurrentUserIdeaAuthor(ideaId: ideaId) else { return }
        let idea = ideas[index]
        let contribution = Contribution(id: contributionId ?? UUID(), authorDisplayName: currentUserName, content: content, isPublic: isPublic, voicePath: voicePath, authorId: userId, attachments: attachments, drawingPath: drawingPath)
        ideas[index].contributions.append(contribution)
        let contributionsSnapshot = ideas[index].contributions
        let attachmentsSnapshot = ideas[index].attachments
        runAsync { await self.syncContributionAdded(ideaId: ideaId, contributions: contributionsSnapshot, attachments: attachmentsSnapshot, contributionId: contribution.id, ideaAuthorDisplayName: idea.authorDisplayName) }
    }
    
    private func syncContributionAdded(ideaId: UUID, contributions: [Contribution], attachments: [Attachment], contributionId: UUID, ideaAuthorDisplayName: String) async {
        try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: contributions, attachments: attachments)
        if ideaAuthorDisplayName != currentUserName {
            try? await SupabaseService.addNotification(AppNotification(type: .contribution, ideaId: ideaId, contributionId: contributionId, actorDisplayName: currentUserName, targetDisplayName: ideaAuthorDisplayName))
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
            let contribs = ideas[ideaIndex].contributions
            let atts = ideas[ideaIndex].attachments
            runAsync { await self.syncIdeaUpdate(ideaId: ideaId, contributions: contribs, attachments: atts, notifyReaction: authorName != self.currentUserName, contributionId: contributionId, authorName: authorName) }
            return
        }
        idea.contributions[contribIndex] = contrib
        ideas[ideaIndex] = idea
        let contribs2 = ideas[ideaIndex].contributions
        let atts2 = ideas[ideaIndex].attachments
        runAsync { await self.syncIdeaUpdate(ideaId: ideaId, contributions: contribs2, attachments: atts2, notifyReaction: false, contributionId: nil, authorName: nil) }
    }
    
    private func syncIdeaUpdate(ideaId: UUID, contributions: [Contribution], attachments: [Attachment], notifyReaction: Bool, contributionId: UUID?, authorName: String?) async {
        try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: contributions, attachments: attachments)
        if notifyReaction, let cid = contributionId, let name = authorName, name != currentUserName {
            try? await SupabaseService.addNotification(AppNotification(type: .reaction, ideaId: ideaId, contributionId: cid, actorDisplayName: currentUserName, targetDisplayName: name))
        }
    }
    
    private func syncIdeaOnly(ideaId: UUID, contributions: [Contribution], attachments: [Attachment]) async {
        try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: contributions, attachments: attachments)
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
        let contribs = ideas[ideaIndex].contributions
        let atts = ideas[ideaIndex].attachments
        runAsync { await self.syncCommentAdded(ideaId: ideaId, contributions: contribs, attachments: atts, contributionId: contributionId, ideaAuthorDisplayName: authorName) }
    }
    
    private func syncCommentAdded(ideaId: UUID, contributions: [Contribution], attachments: [Attachment], contributionId: UUID, ideaAuthorDisplayName: String) async {
        try? await SupabaseService.updateIdea(ideaId: ideaId, contributions: contributions, attachments: attachments)
        if ideaAuthorDisplayName != currentUserName {
            try? await SupabaseService.addNotification(AppNotification(type: .comment, ideaId: ideaId, contributionId: contributionId, actorDisplayName: currentUserName, targetDisplayName: ideaAuthorDisplayName))
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
            let contribsA = ideas[ideaIndex].contributions
            let attsA = ideas[ideaIndex].attachments
            runAsync { await self.syncIdeaUpdate(ideaId: ideaId, contributions: contribsA, attachments: attsA, notifyReaction: authorName != self.currentUserName, contributionId: contributionId, authorName: authorName) }
            return
        }
        contrib.comments[commentIndex] = comment
        idea.contributions[contribIndex] = contrib
        ideas[ideaIndex] = idea
        let contribsB = ideas[ideaIndex].contributions
        let attsB = ideas[ideaIndex].attachments
        runAsync { await self.syncIdeaOnly(ideaId: ideaId, contributions: contribsB, attachments: attsB) }
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
        let contribs = ideas[ideaIndex].contributions
        let atts = ideas[ideaIndex].attachments
        runAsync { await self.syncIdeaOnly(ideaId: ideaId, contributions: contribs, attachments: atts) }
    }
    
    func deleteContribution(ideaId: UUID, contributionId: UUID) {
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }),
              canCurrentUserEditContribution(ideas[ideaIndex].contributions[contribIndex]) else { return }
        ideas[ideaIndex].contributions.remove(at: contribIndex)
        let contribs = ideas[ideaIndex].contributions
        let atts = ideas[ideaIndex].attachments
        runAsync { await self.syncIdeaOnly(ideaId: ideaId, contributions: contribs, attachments: atts) }
    }
    
    func updateComment(ideaId: UUID, contributionId: UUID, commentId: UUID, newContent: String, newVoicePath: String?) {
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }),
              let commentIndex = ideas[ideaIndex].contributions[contribIndex].comments.firstIndex(where: { $0.id == commentId }),
              canCurrentUserEditComment(ideas[ideaIndex].contributions[contribIndex].comments[commentIndex]) else { return }
        ideas[ideaIndex].contributions[contribIndex].comments[commentIndex].content = newContent
        ideas[ideaIndex].contributions[contribIndex].comments[commentIndex].voicePath = newVoicePath
        ideas[ideaIndex].contributions[contribIndex].comments[commentIndex].editedAt = Date()
        let contribs = ideas[ideaIndex].contributions
        let atts = ideas[ideaIndex].attachments
        runAsync { await self.syncIdeaOnly(ideaId: ideaId, contributions: contribs, attachments: atts) }
    }
    
    func deleteComment(ideaId: UUID, contributionId: UUID, commentId: UUID) {
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }),
              let commentIndex = ideas[ideaIndex].contributions[contribIndex].comments.firstIndex(where: { $0.id == commentId }),
              canCurrentUserEditComment(ideas[ideaIndex].contributions[contribIndex].comments[commentIndex]) else { return }
        ideas[ideaIndex].contributions[contribIndex].comments.remove(at: commentIndex)
        let contribs = ideas[ideaIndex].contributions
        let atts = ideas[ideaIndex].attachments
        runAsync { await self.syncIdeaOnly(ideaId: ideaId, contributions: contribs, attachments: atts) }
    }

    /// Idea author rates a contribution 1–5. Only the idea owner can set/change the rating. You cannot rate your own contribution.
    func setContributionRating(ideaId: UUID, contributionId: UUID, rating: Int) {
        let clamped = min(5, max(1, rating))
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }) else { return }
        let idea = ideas[ideaIndex]
        let isIdeaAuthor = idea.authorId == currentUserId
            || (idea.authorId == nil && idea.authorDisplayName == currentUserName)
        guard isIdeaAuthor else { return }
        let contrib = ideas[ideaIndex].contributions[contribIndex]
        let isOwnContrib = contrib.authorId == currentUserId
            || (contrib.authorId == nil && contrib.authorDisplayName == currentUserName)
        guard !isOwnContrib else { return }
        ideas[ideaIndex].contributions[contribIndex].authorRating = clamped
        ideas[ideaIndex].contributions[contribIndex].authorRatingAt = Date()
        let contribs = ideas[ideaIndex].contributions
        let atts = ideas[ideaIndex].attachments
        runAsync { await self.syncIdeaOnly(ideaId: ideaId, contributions: contribs, attachments: atts) }
    }
    
    /// Idea author removes their rating from a contribution.
    func clearContributionRating(ideaId: UUID, contributionId: UUID) {
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }) else { return }
        let idea = ideas[ideaIndex]
        let isIdeaAuthor = idea.authorId == currentUserId
            || (idea.authorId == nil && idea.authorDisplayName == currentUserName)
        guard isIdeaAuthor else { return }
        ideas[ideaIndex].contributions[contribIndex].authorRating = nil
        ideas[ideaIndex].contributions[contribIndex].authorRatingAt = nil
        let contribs = ideas[ideaIndex].contributions
        let atts = ideas[ideaIndex].attachments
        runAsync { await self.syncIdeaOnly(ideaId: ideaId, contributions: contribs, attachments: atts) }
    }

    /// Average star rating received by this user (from idea authors rating their contributions). Nil if no ratings.
    func averageRatingForUser(displayName: String, authorId: UUID?) -> Double? {
        let ratings = ideas.flatMap(\.contributions).filter { c in
            if let aid = authorId, let cid = c.authorId { return cid == aid }
            return c.authorDisplayName == displayName
        }.compactMap(\.authorRating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
    
    /// Average idea rating for ideas this user authored (idea maker quality). Nil if none of their ideas have ratings.
    func averageIdeaRatingForUser(displayName: String, authorId: UUID?) -> Double? {
        let myIdeas = ideas.filter { idea in
            if let aid = authorId { return idea.authorId == aid }
            return idea.authorId == nil && idea.authorDisplayName == displayName
        }
        let withRating = myIdeas.compactMap(\.averageRating)
        guard !withRating.isEmpty else { return nil }
        return withRating.reduce(0, +) / Double(withRating.count)
    }
    
    private func loadHiddenIdeaIds() async {
        do {
            let ids = try await SupabaseService.getHiddenIdeaIds()
            await MainActor.run { [weak self] in
                self?.hiddenIdeaIds = Set(ids)
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.hiddenIdeaIds = []
            }
        }
    }
    
    private func loadMyIdeaRatingsIfNeeded() {
        guard currentUserId != nil else { return }
        runAsync { await self.loadMyIdeaRatings() }
    }
    
    private func loadMyIdeaRatings() async {
        guard let map = try? await SupabaseService.getMyIdeaRatings() else { return }
        await MainActor.run { myIdeaRatings = map }
    }
    
    /// Rate an idea 1–5 (reader rating; one per user per idea). You cannot rate your own idea.
    func setIdeaRating(ideaId: UUID, rating: Int) {
        guard !isCurrentUserIdeaAuthor(ideaId: ideaId) else { return }
        let clamped = min(5, max(1, rating))
        myIdeaRatings[ideaId] = clamped
        runAsync { await self.setIdeaRatingInBackground(ideaId: ideaId, rating: clamped) }
    }
    
    private func setIdeaRatingInBackground(ideaId: UUID, rating: Int) async {
        try? await SupabaseService.setIdeaRating(ideaId: ideaId, rating: rating)
        if let updated = try? await SupabaseService.getIdea(ideaId: ideaId) {
            await MainActor.run {
                if let idx = ideas.firstIndex(where: { $0.id == ideaId }) {
                    ideas[idx] = updated
                }
            }
        }
    }
    
    /// Remove the current user's rating for an idea.
    func clearIdeaRating(ideaId: UUID) {
        guard !isCurrentUserIdeaAuthor(ideaId: ideaId) else { return }
        myIdeaRatings.removeValue(forKey: ideaId)
        runAsync { await self.clearIdeaRatingInBackground(ideaId: ideaId) }
    }
    
    private func clearIdeaRatingInBackground(ideaId: UUID) async {
        try? await SupabaseService.deleteIdeaRating(ideaId: ideaId)
        if let updated = try? await SupabaseService.getIdea(ideaId: ideaId) {
            await MainActor.run {
                if let idx = ideas.firstIndex(where: { $0.id == ideaId }) {
                    ideas[idx] = updated
                }
            }
        }
    }
    
    /// Hide an idea from the current user’s feed (“Don’t show this again”). Requires session.
    func hideIdea(ideaId: UUID) {
        hiddenIdeaIds.insert(ideaId)
        runAsync { await self.hideIdeaInBackground(ideaId: ideaId) }
    }
    
    private func hideIdeaInBackground(ideaId: UUID) async {
        try? await SupabaseService.hideIdea(ideaId: ideaId)
    }
    
    /// Report an idea (for later moderation). Requires session.
    func reportIdea(ideaId: UUID, reason: String, details: String? = nil) {
        runAsync { await self.reportIdeaInBackground(ideaId: ideaId, reason: reason, details: details, contributionId: nil) }
    }
    
    /// Report a contribution (for later moderation). Requires session.
    func reportContribution(ideaId: UUID, contributionId: UUID, reason: String, details: String? = nil) {
        runAsync { await self.reportIdeaInBackground(ideaId: ideaId, reason: reason, details: details, contributionId: contributionId) }
    }
    
    private func reportIdeaInBackground(ideaId: UUID, reason: String, details: String?, contributionId: UUID?) async {
        try? await SupabaseService.reportIdea(ideaId: ideaId, reason: reason, details: details, contributionId: contributionId)
    }

    /// Whether the current user is the idea author (and can rate contributions).
    func isCurrentUserIdeaAuthor(ideaId: UUID) -> Bool {
        guard let idea = idea(byId: ideaId) else { return false }
        if let aid = idea.authorId { return aid == currentUserId }
        return idea.authorDisplayName == currentUserName
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

    /// Mark an idea as finished (idea author only). Stops new completions.
    func markIdeaAsFinished(ideaId: UUID) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        let idea = ideas[index]
        let isOwner = idea.authorId == currentUserId
            || (idea.authorId == nil && idea.authorDisplayName == currentUserName)
        guard isOwner else { return }
        let now = Date()
        ideas[index].finishedAt = now
        runAsync { await self.updateIdeaFinishedInBackground(ideaId: ideaId, finishedAt: now) }
    }
    
    private func updateIdeaFinishedInBackground(ideaId: UUID, finishedAt: Date) async {
        try? await SupabaseService.updateIdeaFinished(ideaId: ideaId, finishedAt: finishedAt)
    }
    
    /// Idea author sets how complete the idea is (0–100%). Others see the progress; idea stays open until 100% or marked finished.
    func setIdeaCompletionPercentage(ideaId: UUID, percentage: Int) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        let idea = ideas[index]
        let isOwner = idea.authorId == currentUserId
            || (idea.authorId == nil && idea.authorDisplayName == currentUserName)
        guard isOwner else { return }
        let clamped = min(100, max(0, percentage))
        ideas[index].completionPercentage = clamped
        runAsync { await self.updateIdeaCompletionPercentageInBackground(ideaId: ideaId, percentage: clamped) }
    }
    
    private func updateIdeaCompletionPercentageInBackground(ideaId: UUID, percentage: Int) async {
        try? await SupabaseService.updateIdeaCompletionPercentage(ideaId: ideaId, percentage: percentage)
    }
    
    /// Idea author removes a contribution they don’t want (e.g. not useful or not 50% complete). Only the idea owner can remove.
    func removeContribution(ideaId: UUID, contributionId: UUID) {
        guard let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        let idea = ideas[ideaIndex]
        let isOwner = idea.authorId == currentUserId
            || (idea.authorId == nil && idea.authorDisplayName == currentUserName)
        guard isOwner else { return }
        guard ideas[ideaIndex].contributions.contains(where: { $0.id == contributionId }) else { return }
        ideas[ideaIndex].contributions.removeAll { $0.id == contributionId }
        let contribs = ideas[ideaIndex].contributions
        let atts = ideas[ideaIndex].attachments
        runAsync { await self.syncIdeaOnly(ideaId: ideaId, contributions: contribs, attachments: atts) }
    }
}

// MARK: - Drafts (persist idea/completion drafts locally; used by CreateIdeaView and IdeaDetailView)

struct IdeaDraft: Codable {
    var content: String
    var categoryId: UUID
    var isSensitive: Bool
}

struct CompletionDraft: Codable {
    var text: String
    var isPublic: Bool
}

enum DraftStore {
    private static let ideaKey = "unfin_ideaDraft"
    private static func completionKey(ideaId: UUID) -> String {
        "unfin_completionDraft_\(ideaId.uuidString)"
    }

    static func loadIdeaDraft() -> IdeaDraft? {
        guard let data = UserDefaults.standard.data(forKey: ideaKey) else { return nil }
        return try? JSONDecoder().decode(IdeaDraft.self, from: data)
    }

    static func saveIdeaDraft(content: String, categoryId: UUID, isSensitive: Bool) {
        let draft = IdeaDraft(content: content, categoryId: categoryId, isSensitive: isSensitive)
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: ideaKey)
        }
    }

    static func clearIdeaDraft() {
        UserDefaults.standard.removeObject(forKey: ideaKey)
    }

    static var hasIdeaDraft: Bool { loadIdeaDraft() != nil }

    static func loadCompletionDraft(ideaId: UUID) -> CompletionDraft? {
        guard let data = UserDefaults.standard.data(forKey: completionKey(ideaId: ideaId)) else { return nil }
        return try? JSONDecoder().decode(CompletionDraft.self, from: data)
    }

    static func saveCompletionDraft(ideaId: UUID, text: String, isPublic: Bool) {
        let draft = CompletionDraft(text: text, isPublic: isPublic)
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: completionKey(ideaId: ideaId))
        }
    }

    static func clearCompletionDraft(ideaId: UUID) {
        UserDefaults.standard.removeObject(forKey: completionKey(ideaId: ideaId))
    }
}

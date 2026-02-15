//
//  IdeaStore.swift
//  Unfin
//

import Foundation
import SwiftUI
import CryptoKit

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
    
    private let fileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ideas.json")
    }()
    
    private let categoriesURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("categories.json")
    }()
    
    private let accountsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("accounts.json")
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
    
    private(set) var accounts: [Account] = []
    
    init() {
        let savedUserId = UserDefaults.standard.string(forKey: "currentUserId").flatMap { UUID(uuidString: $0) }
        self.currentUserId = savedUserId
        self.currentUserName = UserDefaults.standard.string(forKey: "currentUserName") ?? "Anonymous"
        loadAccounts()
        if let id = savedUserId, let acc = account(byId: id) {
            self.currentUserName = acc.displayName
        }
        loadCategories()
        if categories.isEmpty {
            categories = Category.defaultSystemCategories
            saveCategories()
        }
        loadIdeas()
        if ideas.isEmpty {
            seedSampleIdeas()
        }
    }
    
    var isLoggedIn: Bool { currentUserId != nil }
    
    var needsOnboarding: Bool {
        guard let id = currentUserId, let acc = account(byId: id) else { return false }
        return !acc.hasCompletedOnboarding
    }
    
    func loadAccounts() {
        guard FileManager.default.fileExists(atPath: accountsURL.path),
              let data = try? Data(contentsOf: accountsURL),
              let decoded = try? JSONDecoder().decode([Account].self, from: data) else {
            return
        }
        accounts = decoded
    }
    
    func saveAccounts() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? data.write(to: accountsURL)
    }
    
    func account(byId id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }
    
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    func signUp(email: String, password: String, displayName: String) -> Bool {
        authError = nil
        let emailLower = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !emailLower.isEmpty, !password.isEmpty, !name.isEmpty else {
            authError = "Fill in all fields."
            return false
        }
        guard !accounts.contains(where: { $0.email.lowercased() == emailLower }) else {
            authError = "An account with this email already exists."
            return false
        }
        let account = Account(
            email: emailLower,
            passwordHash: hashPassword(password),
            displayName: name.isEmpty ? emailLower : name
        )
        accounts.append(account)
        saveAccounts()
        currentUserId = account.id
        currentUserName = account.displayName
        return true
    }
    
    func login(email: String, password: String) -> Bool {
        authError = nil
        let emailLower = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = hashPassword(password)
        guard let acc = accounts.first(where: { $0.email.lowercased() == emailLower && $0.passwordHash == hash }) else {
            authError = "Invalid email or password."
            return false
        }
        currentUserId = acc.id
        currentUserName = acc.displayName
        return true
    }
    
    func logout() {
        currentUserId = nil
        currentUserName = "Anonymous"
    }
    
    var currentAccount: Account? {
        guard let id = currentUserId else { return nil }
        return account(byId: id)
    }

    func updateAccountDisplayName(_ name: String) {
        guard let id = currentUserId, let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        let acc = accounts[idx]
        accounts[idx] = Account(id: acc.id, email: acc.email, passwordHash: acc.passwordHash, displayName: name, glyphGrid: acc.glyphGrid, auraPaletteIndex: acc.auraPaletteIndex, auraVariant: acc.auraVariant)
        saveAccounts()
        currentUserName = name
    }

    func completeOnboarding(glyphGrid: String, auraPaletteIndex: Int?, auraVariant: Int?, displayName: String?) {
        guard let id = currentUserId, let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        var acc = accounts[idx]
        acc.glyphGrid = glyphGrid
        acc.auraPaletteIndex = auraPaletteIndex
        acc.auraVariant = auraVariant
        if let name = displayName, !name.isEmpty {
            acc.displayName = name
            currentUserName = name
        }
        accounts[idx] = acc
        saveAccounts()
    }

    /// Update the current user's profile picture (aura) variant. Use after onboarding to change aura.
    func updateAccountAura(auraVariant: Int) {
        guard let id = currentUserId, let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        var acc = accounts[idx]
        acc.auraVariant = auraVariant
        acc.auraPaletteIndex = nil
        accounts[idx] = acc
        saveAccounts()
    }
    
    func loadCategories() {
        guard FileManager.default.fileExists(atPath: categoriesURL.path),
              let data = try? Data(contentsOf: categoriesURL),
              let decoded = try? JSONDecoder().decode([Category].self, from: data) else {
            return
        }
        categories = decoded
    }
    
    func saveCategories() {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        try? data.write(to: categoriesURL)
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
    
    func addCategory(displayName: String, actionVerb: String = "Complete") {
        let cat = Category(id: UUID(), displayName: displayName, actionVerb: actionVerb, isSystem: false)
        categories.append(cat)
        saveCategories()
    }
    
    func removeCategory(id: UUID) {
        guard let cat = category(byId: id), !cat.isSystem else { return }
        categories.removeAll { $0.id == id }
        saveCategories()
    }
    
    func deleteAccount() {
        let nameToRemove = currentUserName
        if let id = currentUserId {
            accounts.removeAll { $0.id == id }
            saveAccounts()
            currentUserId = nil
        }
        currentUserName = "Anonymous"
        ideas = ideas.filter { $0.authorDisplayName != nameToRemove }
        saveIdeas()
    }
    
    func loadIdeas() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Idea].self, from: data) else {
            return
        }
        ideas = decoded.sorted { $0.createdAt > $1.createdAt }
    }
    
    func saveIdeas() {
        guard let data = try? JSONEncoder().encode(ideas) else { return }
        try? data.write(to: fileURL)
    }
    
    func addIdea(_ idea: Idea) {
        ideas.insert(idea, at: 0)
        saveIdeas()
    }
    
    func addContribution(ideaId: UUID, content: String, isPublic: Bool = true) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        let contribution = Contribution(authorDisplayName: currentUserName, content: content, isPublic: isPublic)
        ideas[index].contributions.append(contribution)
        saveIdeas()
    }
    
    /// Toggle or set reaction. If user already has this reaction type, remove it; otherwise set it (replacing any previous reaction from this user).
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
        }
        idea.contributions[contribIndex] = contrib
        ideas[ideaIndex] = idea
        saveIdeas()
    }
    
    func addComment(ideaId: UUID, contributionId: UUID, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let ideaIndex = ideas.firstIndex(where: { $0.id == ideaId }),
              let contribIndex = ideas[ideaIndex].contributions.firstIndex(where: { $0.id == contributionId }) else { return }
        var idea = ideas[ideaIndex]
        var contrib = idea.contributions[contribIndex]
        contrib.comments.append(Comment(authorDisplayName: currentUserName, content: trimmed))
        idea.contributions[contribIndex] = contrib
        ideas[ideaIndex] = idea
        saveIdeas()
    }
    
    /// The current user's reaction type on this contribution, if any.
    func currentUserReactionType(for contribution: Contribution) -> String? {
        guard let userId = currentUserId else { return nil }
        return contribution.reactions.first { $0.accountId == userId }?.type
    }
    
    func didCurrentUserLike(contribution: Contribution) -> Bool {
        return currentUserReactionType(for: contribution) == ReactionType.heart.rawValue
    }
    
    func updateIdeaContent(ideaId: UUID, newContent: String) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaId }) else { return }
        ideas[index].content = newContent
        saveIdeas()
    }
    
    func idea(byId id: UUID) -> Idea? {
        ideas.first { $0.id == id }
    }
    
    private func seedSampleIdeas() {
        ideas = [
            Idea(
                categoryId: Category.melodyId,
                content: "Humming a bridge for this melancholic loop. Needs a resolution.",
                authorDisplayName: "Anonymous",
                contributions: []
            ),
            Idea(
                categoryId: Category.fictionId,
                content: "\"The train station was empty, save for a single yellow chair in the center of the platform. I sat down, and the world...\" finish this sentence",
                authorDisplayName: "K",
                contributions: []
            ),
            Idea(
                categoryId: Category.conceptId,
                content: "An app that deletes your photos if you don't look at them once a year. Digital impermanence.",
                authorDisplayName: "M",
                contributions: []
            ),
            Idea(
                categoryId: Category.poetryId,
                content: "The sun dips low\nThe shadows grow\nBut I am still waiting for...",
                authorDisplayName: "L",
                contributions: []
            )
        ]
        saveIdeas()
    }
}

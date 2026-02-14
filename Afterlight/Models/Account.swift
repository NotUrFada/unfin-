//
//  Account.swift
//  Unfin
//

import Foundation

struct Account: Codable, Identifiable {
    let id: UUID
    let email: String
    let passwordHash: String
    var displayName: String
    var glyphGrid: String?
    var auraPaletteIndex: Int?
    /// 0 ..< 1_080_000 for 1M+ aura variations (100 palettes × 360 rotations × 30 blur steps)
    var auraVariant: Int?

    init(id: UUID = UUID(), email: String, passwordHash: String, displayName: String, glyphGrid: String? = nil, auraPaletteIndex: Int? = nil, auraVariant: Int? = nil) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.displayName = displayName
        self.glyphGrid = glyphGrid
        self.auraPaletteIndex = auraPaletteIndex
        self.auraVariant = auraVariant
    }

    var hasCompletedOnboarding: Bool { glyphGrid != nil }

    enum CodingKeys: String, CodingKey {
        case id, email, passwordHash, displayName, glyphGrid, auraPaletteIndex, auraVariant
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        passwordHash = try c.decode(String.self, forKey: .passwordHash)
        displayName = try c.decode(String.self, forKey: .displayName)
        glyphGrid = try c.decodeIfPresent(String.self, forKey: .glyphGrid)
        auraPaletteIndex = try c.decodeIfPresent(Int.self, forKey: .auraPaletteIndex)
        auraVariant = try c.decodeIfPresent(Int.self, forKey: .auraVariant)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(email, forKey: .email)
        try c.encode(passwordHash, forKey: .passwordHash)
        try c.encode(displayName, forKey: .displayName)
        try c.encodeIfPresent(glyphGrid, forKey: .glyphGrid)
        try c.encodeIfPresent(auraPaletteIndex, forKey: .auraPaletteIndex)
        try c.encodeIfPresent(auraVariant, forKey: .auraVariant)
    }
}

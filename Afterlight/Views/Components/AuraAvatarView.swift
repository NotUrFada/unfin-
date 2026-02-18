//
//  AuraAvatarView.swift
//  Unfin
//

import SwiftUI

// 1M+ variations: 100 palettes × 360 rotation steps × 30 blur steps = 1_080_000
private let auraPaletteCount = 100
private let darkAuraPaletteCount = 50
private let auraRotationSteps = 360
private let auraBlurSteps = 30
let auraTotalVariations = auraPaletteCount * auraRotationSteps * auraBlurSteps
let darkAuraTotalVariations = darkAuraPaletteCount * auraRotationSteps * auraBlurSteps

/// Deterministic bright palette from index (0..<100). Returns (Color, Color, Color).
private func auraPalette(at index: Int) -> (Color, Color, Color) {
    let i = index % auraPaletteCount
    // Spread hues; vary saturation/lightness for distinct triples
    let hue1 = Double((i * 137) % 360) / 360.0
    let hue2 = Double((i * 97 + 120) % 360) / 360.0
    let hue3 = Double((i * 67 + 240) % 360) / 360.0
    let s: Double = 0.5 + Double(i % 30) / 100.0
    let b: Double = 0.7 + Double(i % 20) / 80.0
    return (
        Color(hue: hue1, saturation: s, brightness: b),
        Color(hue: hue2, saturation: s * 0.9, brightness: min(1, b + 0.15)),
        Color(hue: hue3, saturation: s * 0.85, brightness: min(1, b + 0.1))
    )
}

/// Deterministic dark palette from index (0..<50). Returns (Color, Color, Color).
private func darkAuraPalette(at index: Int) -> (Color, Color, Color) {
    let i = index % darkAuraPaletteCount
    // Very dark colors with a touch of hue; more black, richer shadows
    let hue1 = Double((i * 137) % 360) / 360.0
    let hue2 = Double((i * 97 + 120) % 360) / 360.0
    let hue3 = Double((i * 67 + 240) % 360) / 360.0
    let s: Double = 0.5 + Double(i % 30) / 100.0
    let b: Double = 0.05 + Double(i % 15) / 100.0 // 0.05–0.20 base (more black)
    return (
        Color(hue: hue1, saturation: min(1, s), brightness: b),
        Color(hue: hue2, saturation: min(1, s * 0.95), brightness: min(0.22, b + 0.08)),
        Color(hue: hue3, saturation: min(1, s * 0.9), brightness: min(0.28, b + 0.12))
    )
}

/// Legacy 3 palettes from onboarding (for accounts without auraVariant).
private let legacyAuraPalettes: [(Color, Color, Color)] = [
    (Color(red: 0.63, green: 0.77, blue: 1), Color(red: 0.79, green: 1, blue: 0.75), Color(red: 0.99, green: 1, blue: 0.71)),
    (Color(red: 1, green: 0.84, blue: 0.65), Color(red: 1, green: 0.68, blue: 0.68), Color(red: 1, green: 0.78, blue: 1)),
    (Color(red: 0.74, green: 0.70, blue: 1), Color(red: 0.63, green: 0.77, blue: 1), Color(red: 1, green: 0.78, blue: 1))
]

struct AuraConfig {
    let colors: (Color, Color, Color)
    let rotationDegrees: Double
    let blurRadius: CGFloat
    let isDark: Bool

    init(colors: (Color, Color, Color), rotationDegrees: Double = 0, blurRadius: CGFloat = 60, isDark: Bool = false) {
        self.colors = colors
        self.rotationDegrees = rotationDegrees
        self.blurRadius = blurRadius
        self.isDark = isDark
    }

    /// Custom color variants: base + (c1<<18)|(c2<<9)|c3, each c = 9 bits (3 bits R,G,B = 0–7).
    private static let customColorBase = 2_000_000_000

    static func encodeCustomColors(_ c1: Color, _ c2: Color, _ c3: Color) -> Int {
        func pack(_ color: Color) -> Int {
            let r = (color.components.red * 7.999).rounded(.down); let ri = max(0, min(7, Int(r)))
            let g = (color.components.green * 7.999).rounded(.down); let gi = max(0, min(7, Int(g)))
            let b = (color.components.blue * 7.999).rounded(.down); let bi = max(0, min(7, Int(b)))
            return (ri << 6) | (gi << 3) | bi
        }
        return customColorBase + (pack(c1) << 18) + (pack(c2) << 9) + pack(c3)
    }

    static func decodeCustomColors(from variant: Int) -> (Color, Color, Color)? {
        guard variant >= customColorBase else { return nil }
        let val = variant - customColorBase
        let p1 = (val >> 18) & 0x1FF
        let p2 = (val >> 9) & 0x1FF
        let p3 = val & 0x1FF
        func unpack(_ p: Int) -> Color {
            let r = Double((p >> 6) & 7) / 7.0
            let g = Double((p >> 3) & 7) / 7.0
            let b = Double(p & 7) / 7.0
            return Color(red: r, green: g, blue: b)
        }
        return (unpack(p1), unpack(p2), unpack(p3))
    }

    static func from(variant: Int) -> AuraConfig {
        // Custom color variants (>= 2B) - decode stored RGB
        if let colors = decodeCustomColors(from: variant) {
            return AuraConfig(colors: colors, rotationDegrees: 0, blurRadius: 60, isDark: false)
        }
        // Negative variants indicate dark auras
        if variant < 0 {
            let v = abs(variant) % darkAuraTotalVariations
            let paletteIndex = v % darkAuraPaletteCount
            let rotationIndex = (v / darkAuraPaletteCount) % auraRotationSteps
            let blurIndex = (v / (darkAuraPaletteCount * auraRotationSteps)) % auraBlurSteps
            let colors = darkAuraPalette(at: paletteIndex)
            let rotationDegrees = Double(rotationIndex)
            let blurRadius = CGFloat(40 + blurIndex * 3) // 40..<130
            return AuraConfig(colors: colors, rotationDegrees: rotationDegrees, blurRadius: blurRadius, isDark: true)
        } else {
            let v = variant % auraTotalVariations
            let paletteIndex = v % auraPaletteCount
            let rotationIndex = (v / auraPaletteCount) % auraRotationSteps
            let blurIndex = (v / (auraPaletteCount * auraRotationSteps)) % auraBlurSteps
            let colors = auraPalette(at: paletteIndex)
            let rotationDegrees = Double(rotationIndex)
            let blurRadius = CGFloat(40 + blurIndex * 3) // 40..<130
            return AuraConfig(colors: colors, rotationDegrees: rotationDegrees, blurRadius: blurRadius, isDark: false)
        }
    }

    static func custom(colors: (Color, Color, Color), rotationDegrees: Double = 0, blurRadius: CGFloat = 60) -> AuraConfig {
        return AuraConfig(colors: colors, rotationDegrees: rotationDegrees, blurRadius: blurRadius, isDark: false)
    }

    static func fromLegacy(paletteIndex: Int) -> AuraConfig {
        let idx = max(0, min(paletteIndex, legacyAuraPalettes.count - 1))
        return AuraConfig(
            colors: legacyAuraPalettes[idx],
            rotationDegrees: 0,
            blurRadius: 60,
            isDark: false
        )
    }
}

/// Deterministic aura variant from a display name so every user gets a consistent avatar without fetching their profile.
func auraVariantForDisplayName(_ displayName: String) -> Int {
    var hasher = Hasher()
    hasher.combine(displayName)
    let h = hasher.finalize()
    return abs(h) % auraTotalVariations
}

/// Renders the user's aura as a circular avatar (profile picture).
struct AuraAvatarView: View {
    var size: CGFloat = 44
    var auraVariant: Int?
    var customColors: (Color, Color, Color)?
    var legacyPaletteIndex: Int?

    private var config: AuraConfig? {
        if let custom = customColors {
            return AuraConfig.custom(colors: custom)
        }
        if let v = auraVariant {
            return .from(variant: v)
        }
        if let p = legacyPaletteIndex {
            return .fromLegacy(paletteIndex: p)
        }
        return nil
    }

    var body: some View {
        Group {
            if let config = config {
                ZStack {
                    LinearGradient(
                        colors: [config.colors.0, config.colors.1, config.colors.2, .white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(config.rotationDegrees))
                    .blur(radius: config.blurRadius * (size / 320.0))
                    .scaleEffect(1.3)
                    .overlay(
                        LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                    )
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(.white.opacity(0.6))
                    )
            }
        }
    }
}

/// Full aura viewport (same as onboarding preview) for reuse in onboarding.
struct AuraViewportView: View {
    var auraVariant: Int?
    var customColors: (Color, Color, Color)?
    var legacyPaletteIndex: Int?
    var height: CGFloat = 320

    private var config: AuraConfig? {
        if let custom = customColors {
            return AuraConfig.custom(colors: custom)
        }
        if let v = auraVariant {
            return .from(variant: v)
        }
        if let p = legacyPaletteIndex {
            return .fromLegacy(paletteIndex: p)
        }
        return nil
    }

    var body: some View {
        ZStack {
            if let config = config {
                LinearGradient(
                    colors: [config.colors.0, config.colors.1, config.colors.2, .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(config.rotationDegrees))
                .blur(radius: config.blurRadius)
                .scaleEffect(1.3)
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                )
            } else {
                Color.white.opacity(0.3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: height)
    }
}

#if DEBUG
#Preview("Aura avatars") {
    HStack(spacing: 16) {
        AuraAvatarView(size: 44, auraVariant: 0)
        AuraAvatarView(size: 44, auraVariant: 50000)
        AuraAvatarView(size: 44, legacyPaletteIndex: 1)
        AuraAvatarView(size: 44, auraVariant: nil, legacyPaletteIndex: nil)
    }
    .padding()
    .background(Color(white: 0.15))
}
#endif

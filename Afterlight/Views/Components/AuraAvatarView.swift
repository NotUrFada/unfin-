//
//  AuraAvatarView.swift
//  Unfin
//

import SwiftUI

// 1M+ variations: 100 palettes × 360 rotation steps × 30 blur steps = 1_080_000
private let auraPaletteCount = 100
private let auraRotationSteps = 360
private let auraBlurSteps = 30
let auraTotalVariations = auraPaletteCount * auraRotationSteps * auraBlurSteps

/// Deterministic palette from index (0..<100). Returns (Color, Color, Color).
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

    static func from(variant: Int) -> AuraConfig {
        let v = variant % auraTotalVariations
        let paletteIndex = v % auraPaletteCount
        let rotationIndex = (v / auraPaletteCount) % auraRotationSteps
        let blurIndex = (v / (auraPaletteCount * auraRotationSteps)) % auraBlurSteps
        let colors = auraPalette(at: paletteIndex)
        let rotationDegrees = Double(rotationIndex)
        let blurRadius = CGFloat(40 + blurIndex * 3) // 40..<130
        return AuraConfig(colors: colors, rotationDegrees: rotationDegrees, blurRadius: blurRadius)
    }

    static func fromLegacy(paletteIndex: Int) -> AuraConfig {
        let idx = max(0, min(paletteIndex, legacyAuraPalettes.count - 1))
        return AuraConfig(
            colors: legacyAuraPalettes[idx],
            rotationDegrees: 0,
            blurRadius: 60
        )
    }
}

/// Renders the user's aura as a circular avatar (profile picture).
struct AuraAvatarView: View {
    var size: CGFloat = 44
    var auraVariant: Int?
    var legacyPaletteIndex: Int?

    private var config: AuraConfig? {
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
    var legacyPaletteIndex: Int?
    var height: CGFloat = 320

    private var config: AuraConfig? {
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

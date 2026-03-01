//
//  AppTheme.swift
//  Unfin
//
//  Shared design system: colors, typography, spacing for a cohesive look.
//

import SwiftUI

enum AppTheme {
    // MARK: - Semantic colors (adapt to light/dark)
    enum Colors {
        static func primaryText(isLight: Bool) -> Color {
            isLight ? Color(white: 0.1) : .white
        }
        static func secondaryText(isLight: Bool) -> Color {
            isLight ? Color(white: 0.3) : Color.white.opacity(0.88)
        }
        static func mutedText(isLight: Bool) -> Color {
            isLight ? Color(white: 0.45) : Color.white.opacity(0.6)
        }
        static func surfaceOpacity(isLight: Bool) -> Double {
            isLight ? 0.12 : 0.14
        }
        /// Default gradient when user has no aura: consistent dark gradient
        static let defaultGradientDark = (
            Color(red: 0.06, green: 0.06, blue: 0.09),
            Color(red: 0.10, green: 0.10, blue: 0.14),
            Color(red: 0.14, green: 0.14, blue: 0.18)
        )
    }

    // MARK: - Typography
    enum Typography {
        /// Brand wordmark "UNFIN" (use with .tracking(-0.6))
        static let brand = Font.system(size: 15, weight: .semibold)
        /// Large screen title (e.g. Explore, Profile)
        static let titleLarge = Font.system(size: 28, weight: .medium)
        /// Section title
        static let title = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let bodySmall = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let label = Font.system(size: 11, weight: .medium)
        static let labelSmall = Font.system(size: 10, weight: .semibold)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        /// Horizontal padding for main content
        static let screenHorizontal: CGFloat = 24
        /// Top safe area for headers
        static let headerTop: CGFloat = 56
        static let headerBottom: CGFloat = 16
    }
}

// MARK: - Consistent brand wordmark
struct UnfinWordmark: View {
    var size: CGFloat = 15
    var color: Color = .white
    var body: some View {
        Text("UNFIN")
            .font(.system(size: size, weight: .semibold))
            .tracking(-0.6)
            .foregroundStyle(color)
    }
}

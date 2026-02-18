//
//  ChangeAuraView.swift
//  Unfin
//

import SwiftUI

struct ChangeAuraView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedVariant: Int
    @State private var isDarkMode: Bool = false
    @State private var showCustomColors: Bool = false
    @State private var customColor1: Color = .blue
    @State private var customColor2: Color = .purple
    @State private var customColor3: Color = .pink

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }

    init(initialVariant: Int? = nil) {
        let initial = initialVariant ?? 0
        _selectedVariant = State(initialValue: initial)
        _isDarkMode = State(initialValue: initial < 0)
    }

    private var currentConfig: AuraConfig {
        if showCustomColors {
            return AuraConfig.custom(colors: (customColor1, customColor2, customColor3))
        } else {
            return AuraConfig.from(variant: selectedVariant)
        }
    }

    private var effectiveVariant: Int {
        if showCustomColors {
            return AuraConfig.encodeCustomColors(customColor1, customColor2, customColor3)
        } else {
            return selectedVariant
        }
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView {
                VStack(spacing: 28) {
                    Text("Profile picture")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(primaryFg)
                        .padding(.top, 24)

                    AuraViewportView(auraVariant: showCustomColors ? nil : selectedVariant, customColors: showCustomColors ? (customColor1, customColor2, customColor3) : nil, legacyPaletteIndex: nil, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(primaryFg.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 24)

                    AuraAvatarView(size: 80, auraVariant: showCustomColors ? nil : selectedVariant, customColors: showCustomColors ? (customColor1, customColor2, customColor3) : nil, legacyPaletteIndex: nil)
                        .overlay(Circle().stroke(primaryFg.opacity(0.25), lineWidth: 2))

                    // Dark/Light toggle
                    HStack(spacing: 12) {
                        Button {
                            isDarkMode = false
                            if !showCustomColors {
                                selectedVariant = Int.random(in: 0..<auraTotalVariations)
                            }
                        } label: {
                            Text("Light")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isDarkMode ? primaryFg.opacity(0.6) : (isLight ? Color.white : primaryFg))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isDarkMode ? Color.clear : (isLight ? primaryFg : Color.white.opacity(0.2)))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        Button {
                            isDarkMode = true
                            if !showCustomColors {
                                selectedVariant = -Int.random(in: 1..<(darkAuraTotalVariations + 1))
                            }
                        } label: {
                            Text("Dark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isDarkMode ? (isLight ? Color.white : primaryFg) : primaryFg.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isDarkMode ? (isLight ? primaryFg : Color.white.opacity(0.2)) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)

                    // Custom colors toggle
                    Button {
                        showCustomColors.toggle()
                        if showCustomColors {
                            // Initialize custom colors from current aura
                            let config = currentConfig
                            customColor1 = config.colors.0
                            customColor2 = config.colors.1
                            customColor3 = config.colors.2
                        } else {
                            // Reset to random when turning off custom
                            if isDarkMode {
                                selectedVariant = -Int.random(in: 1..<(darkAuraTotalVariations + 1))
                            } else {
                                selectedVariant = Int.random(in: 0..<auraTotalVariations)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: showCustomColors ? "paintpalette.fill" : "paintpalette")
                                .font(.system(size: 14))
                            Text(showCustomColors ? "Custom Colors" : "Use Custom Colors")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(primaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(primaryFg.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    // Custom color pickers
                    if showCustomColors {
                        VStack(spacing: 16) {
                            ColorPickerRow(label: "Color 1", color: $customColor1)
                            ColorPickerRow(label: "Color 2", color: $customColor2)
                            ColorPickerRow(label: "Color 3", color: $customColor3)
                        }
                        .padding(.horizontal, 24)
                    }

                    VStack(spacing: 16) {
                        if !showCustomColors {
                            Button {
                                if isDarkMode {
                                    selectedVariant = -Int.random(in: 1..<(darkAuraTotalVariations + 1))
                                } else {
                                    selectedVariant = Int.random(in: 0..<auraTotalVariations)
                                }
                            } label: {
                                Text("Shuffle")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(primaryFg)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(primaryFg.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            store.updateAccountAura(auraVariant: effectiveVariant)
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isLight ? Color.white : Color(white: 0.15))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(primaryFg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            if selectedVariant == 0, let current = store.currentAccount?.auraVariant {
                selectedVariant = current
                isDarkMode = current < 0
                // If it's a custom color variant, decode and show custom colors
                if let decoded = AuraConfig.decodeCustomColors(from: current) {
                    showCustomColors = true
                    customColor1 = decoded.0
                    customColor2 = decoded.1
                    customColor3 = decoded.2
                }
            } else if store.currentAccount?.auraVariant == nil, store.currentAccount?.auraPaletteIndex != nil {
                selectedVariant = Int.random(in: 0..<auraTotalVariations)
                isDarkMode = false
            } else if selectedVariant != 0 {
                isDarkMode = selectedVariant < 0
                if let decoded = AuraConfig.decodeCustomColors(from: selectedVariant) {
                    showCustomColors = true
                    customColor1 = decoded.0
                    customColor2 = decoded.1
                    customColor3 = decoded.2
                }
            }
        }
    }
}

private struct ColorPickerRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    @Binding var color: Color

    private var primaryFg: Color { colorScheme == .light ? Color(white: 0.12) : .white }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(primaryFg.opacity(0.9))
                .frame(width: 70, alignment: .leading)
            ColorPicker("", selection: $color)
                .labelsHidden()
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 40)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(primaryFg.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
        #else
        let nsColor = NSColor(self)
        return (Double(nsColor.redComponent), Double(nsColor.greenComponent), Double(nsColor.blueComponent), Double(nsColor.alphaComponent))
        #endif
    }
}

#Preview {
    ChangeAuraView(initialVariant: 42)
        .environmentObject(IdeaStore())
}

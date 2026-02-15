//
//  ChangeAuraView.swift
//  Unfin
//

import SwiftUI

struct ChangeAuraView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: IdeaStore
    @State private var selectedVariant: Int

    init(initialVariant: Int? = nil) {
        _selectedVariant = State(initialValue: initialVariant ?? 0)
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()
            VStack(spacing: 28) {
                Text("Profile picture")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                AuraViewportView(auraVariant: selectedVariant, legacyPaletteIndex: nil, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 24)

                AuraAvatarView(size: 80, auraVariant: selectedVariant, legacyPaletteIndex: nil)
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))

                VStack(spacing: 16) {
                    Button {
                        selectedVariant = Int.random(in: 0..<auraTotalVariations)
                    } label: {
                        Text("Shuffle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.updateAccountAura(auraVariant: selectedVariant)
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(white: 0.15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                Spacer()
            }
        }
        .onAppear {
            if selectedVariant == 0, let current = store.currentAccount?.auraVariant {
                selectedVariant = current
            } else if store.currentAccount?.auraVariant == nil, store.currentAccount?.auraPaletteIndex != nil {
                selectedVariant = Int.random(in: 0..<auraTotalVariations)
            }
        }
    }
}

#Preview {
    ChangeAuraView(initialVariant: 42)
        .environmentObject(IdeaStore())
}

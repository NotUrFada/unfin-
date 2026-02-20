//
//  OnboardingView.swift
//  Unfin
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var displayName = ""
    @State private var auraVariant: Int = 0
    @State private var showNameTakenAlert = false
    @State private var isContinuing = false
    @State private var isGeneratingName = false

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }

    var body: some View {
        ZStack {
            BackgroundGradientView()
            auraStep
        }
        .onAppear {
            displayName = store.currentUserName
            shuffleAura()
        }
    }
    
    // MARK: - Aura profile (display name + aura + continue)
    private var auraStep: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                AuraViewportView(auraVariant: auraVariant, legacyPaletteIndex: nil, height: geo.size.height)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Text("GEN. \(monthYear)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .tracking(0.05)
                            .foregroundStyle(primaryFg.opacity(0.6))
                            .padding(24)
                    }
                    Spacer(minLength: 0)
                    controlsPanel
                        .padding(.bottom, 40)
                }
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var monthYear: String {
        let f = DateFormatter()
        f.dateFormat = "MM/yyyy"
        return f.string(from: Date())
    }
    
    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display name")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(0.1)
                        .foregroundStyle(primaryFg.opacity(0.6))
                    TextField("How you'll appear", text: $displayName)
                        .font(.system(size: 28, weight: .regular))
                        .tracking(-0.03)
                        .foregroundStyle(primaryFg)
                }
                Button {
                    isGeneratingName = true
                    Task {
                        if let name = await store.generateAndSetRandomDisplayName() {
                            await MainActor.run { displayName = name }
                        }
                        await MainActor.run { isGeneratingName = false }
                    }
                } label: {
                    Text(isGeneratingName ? "…" : "Random")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(0.1)
                        .foregroundStyle(isLight ? Color.white : primaryFg)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(isLight ? primaryFg : primaryFg.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isLight ? Color.clear : primaryFg.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isGeneratingName)
            }
            
            HStack(spacing: 12) {
                Button("Shuffle aura") {
                    shuffleAura()
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.1)
                .foregroundStyle(isLight ? Color.white : primaryFg)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(isLight ? primaryFg : primaryFg.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isLight ? Color.clear : primaryFg.opacity(0.2), lineWidth: 1))
                
                Spacer()
            }
            
            Button {
                Task { await tryCompleteOnboarding() }
            } label: {
                Text(isContinuing ? "Checking…" : "Continue")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(0.1)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [syncButtonAuraConfig.colors.0, syncButtonAuraConfig.colors.1, syncButtonAuraConfig.colors.2],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)
            .disabled(isContinuing)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(primaryFg.opacity(0.15), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, -40)
        .alert("Display name taken", isPresented: $showNameTakenAlert) {
            Button("OK", role: .cancel) { }
            Button("Generate random name") {
                Task {
                    if let newName = await store.generateAndSetRandomDisplayName() {
                        await MainActor.run { displayName = newName }
                    }
                }
            }
        } message: {
            Text("That display name is already taken. Choose another or use a random one.")
        }
    }
    
    // MARK: - Helpers
    private var syncButtonAuraConfig: AuraConfig {
        AuraConfig.from(variant: auraVariant)
    }

    private func shuffleAura() {
        auraVariant = Int.random(in: 0..<auraTotalVariations)
    }

    private func completeOnboarding(withName name: String?) {
        let defaultGlyphGrid = String(repeating: "0", count: 12 * 12)
        store.completeOnboarding(
            glyphGrid: defaultGlyphGrid,
            auraPaletteIndex: nil,
            auraVariant: auraVariant,
            displayName: name
        )
    }

    private func tryCompleteOnboarding() async {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run { isContinuing = true }
        let nameToUse = name.isEmpty ? nil : name
        var taken = false
        if let n = nameToUse {
            taken = await store.isDisplayNameTakenForCurrentUser(n)
        }
        await MainActor.run { isContinuing = false }
        if taken {
            await MainActor.run { showNameTakenAlert = true }
        } else {
            completeOnboarding(withName: nameToUse?.isEmpty == true ? nil : nameToUse)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(IdeaStore())
}

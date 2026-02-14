//
//  OnboardingView.swift
//  Unfin
//

import SwiftUI

private let gridSize = 12
private let glyphCellCount = gridSize * gridSize

struct OnboardingView: View {
    @EnvironmentObject var store: IdeaStore
    @State private var step = 0
    @State private var gridState: [Bool] = Array(repeating: false, count: glyphCellCount)
    @State private var displayName = ""
    @State private var auraVariant: Int = 0

    var body: some View {
        ZStack {
            BackgroundGradientView()
            if step == 0 {
                identityStep
            } else {
                auraStep
            }
        }
        .onAppear {
            displayName = store.currentUserName
            randomizeGlyph()
            if step == 1 { shuffleAura() }
        }
        .onChange(of: step) { _, newStep in
            if newStep == 1 { shuffleAura() }
        }
    }
    
    // MARK: - Step 1: Identity glyph (Design 1 – Nothing OS)
    private var identityStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    glyphGridCard
                    controlsSection
                }
                .padding(24)
                .padding(.top, 50)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Identity ( 1 )")
                    .font(.system(size: 28, weight: .regular, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(-1)
                    .foregroundStyle(.white)
                Spacer()
                Circle()
                    .fill(Color(red: 0.84, green: 0.10, blue: 0.13))
                    .frame(width: 14, height: 14)
            }
            HStack {
                Text("Gen_V1.0")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("UNFIN")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, 8)
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
    
    private var glyphGridCard: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: gridSize), spacing: 4) {
                ForEach(0..<glyphCellCount, id: \.self) { index in
                    Button {
                        toggleDot(index)
                    } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(gridState[index] ? Color.white : Color.white.opacity(0.08))
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
    
    private var controlsSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Button("Randomize") {
                    randomizeGlyph()
                }
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.4), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button("Continue") {
                    withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
                }
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .foregroundStyle(Color(white: 0.12))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Step 2: Aura profile (Design 2 – Generative Aura)
    private var auraStep: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { step = 0 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(16)
                }
                Spacer()
            }
            ScrollView {
                VStack(spacing: 0) {
                    auraViewport
                    controlsPanel
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private var auraViewport: some View {
        AuraViewportView(auraVariant: auraVariant, legacyPaletteIndex: nil, height: 320)
            .overlay(alignment: .topTrailing) {
                Text("GEN. \(monthYear)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(0.05)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(24)
            }
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
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("How you'll appear", text: $displayName)
                        .font(.system(size: 28, weight: .regular))
                        .tracking(-0.03)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("Shuffle aura") {
                    shuffleAura()
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.1)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
            }
            
            Button {
                completeOnboarding()
            } label: {
                Text("Continue")
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
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, -40)
    }
    
    // MARK: - Helpers
    private var syncButtonAuraConfig: AuraConfig {
        AuraConfig.from(variant: auraVariant)
    }

    private func toggleDot(_ index: Int) {
        guard index >= 0, index < gridState.count else { return }
        gridState[index].toggle()
        let mirror = (index / gridSize) * gridSize + (gridSize - 1 - (index % gridSize))
        if mirror != index, mirror >= 0, mirror < gridState.count {
            gridState[mirror] = gridState[index]
        }
    }
    
    private func randomizeGlyph() {
        for y in 0..<gridSize {
            for x in 0..<(gridSize / 2) {
                let on = Bool.random() && Bool.random()
                let index = y * gridSize + x
                let mirror = y * gridSize + (gridSize - 1 - x)
                gridState[index] = on
                gridState[mirror] = on
            }
        }
    }
    
    private var glyphGridString: String {
        gridState.map { $0 ? "1" : "0" }.joined()
    }
    
    private func shuffleAura() {
        auraVariant = Int.random(in: 0..<auraTotalVariations)
    }

    private func completeOnboarding() {
        store.completeOnboarding(
            glyphGrid: glyphGridString,
            auraPaletteIndex: nil,
            auraVariant: auraVariant,
            displayName: displayName.isEmpty ? nil : displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(IdeaStore())
}

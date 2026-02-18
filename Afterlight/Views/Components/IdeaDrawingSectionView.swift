//
//  IdeaDrawingSectionView.swift
//  Unfin
//

import SwiftUI
import PencilKit

/// Shows collaborative drawing: version history and current merged view, Replay.
struct IdeaDrawingSectionView: View {
    @EnvironmentObject var store: IdeaStore
    let idea: Idea
    @State private var loadedDrawings: [PKDrawing?] = []
    @State private var selectedVersionIndex: Int = 0
    @State private var showReplay = false
    
    private var drawingPaths: [String] {
        var paths: [String] = []
        if let p = idea.drawingPath { paths.append(p) }
        for c in idea.contributions {
            if let p = c.drawingPath { paths.append(p) }
        }
        return paths
    }
    
    private var versionLabels: [String] {
        var labels = [String]()
        if idea.drawingPath != nil { labels.append("Initial") }
        for c in idea.contributions where c.drawingPath != nil {
            labels.append("+ \(c.authorDisplayName)")
        }
        if labels.isEmpty { labels.append("—") }
        return labels
    }
    
    /// Merged drawing up to and including the given index (0 = initial only, 1 = initial + first contrib, etc.).
    private func mergedDrawing(upTo index: Int) -> PKDrawing {
        var allStrokes: [PKStroke] = []
        for i in 0...min(index, loadedDrawings.count - 1) {
            guard let d = loadedDrawings[i] else { continue }
            allStrokes.append(contentsOf: d.strokes)
        }
        return PKDrawing(strokes: allStrokes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Drawing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                if drawingPaths.count > 1 {
                    Picker("Version", selection: $selectedVersionIndex) {
                        ForEach(Array(versionLabels.enumerated()), id: \.offset) { i, label in
                            Text(label).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                    .colorScheme(.dark)
                    .labelsHidden()
                }
            }
            
            if selectedVersionIndex < loadedDrawings.count {
                let merged = mergedDrawing(upTo: selectedVersionIndex)
                if merged.strokes.isEmpty {
                    Text("No strokes in this version.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    DrawingThumbnailView(drawing: merged, maxSize: 500)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 220)
                }
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }
            
            if drawingPaths.count > 1 {
                Button {
                    showReplay = true
                } label: {
                    Label("Replay", systemImage: "play.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { loadAllDrawings() }
        .sheet(isPresented: $showReplay) {
            DrawingReplayView(drawings: loadedDrawings.compactMap { $0 }, onDismiss: { showReplay = false })
                .environmentObject(store)
        }
    }
    
    private func loadAllDrawings() {
        let paths = drawingPaths
        guard !paths.isEmpty else { return }
        Task {
            var drawings: [PKDrawing?] = []
            for path in paths {
                let d = await store.loadDrawing(storagePath: path)
                drawings.append(d)
            }
            await MainActor.run {
                loadedDrawings = drawings
                if selectedVersionIndex >= drawings.count { selectedVersionIndex = max(0, drawings.count - 1) }
            }
        }
    }
    
}

/// Full-screen replay: animates through each stroke of each drawing in order.
struct DrawingReplayView: View {
    @EnvironmentObject var store: IdeaStore
    let drawings: [PKDrawing]
    var onDismiss: () -> Void
    @State private var currentDrawingIndex = 0
    @State private var currentStrokeIndex = 0
    @State private var isPlaying = false
    @State private var accumulatedStrokes: [PKStroke] = []
    
    private var replayedDrawing: PKDrawing {
        PKDrawing(strokes: accumulatedStrokes)
    }
    
    private var totalStrokes: Int {
        drawings.reduce(0) { $0 + $1.strokes.count }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.12).ignoresSafeArea()
                VStack(spacing: 16) {
                    DrawingThumbnailView(drawing: replayedDrawing, maxSize: 600)
                        .frame(maxWidth: .infinity)
                        .padding()
                    HStack(spacing: 16) {
                        Button { isPlaying.toggle() } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                        Text("\(currentDrawingIndex + 1)/\(drawings.count) · stroke \(currentStrokeInDrawing + 1)/\(drawings.isEmpty ? 0 : drawings[currentDrawingIndex].strokes.count)")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .navigationTitle("Replay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.12), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    currentDrawingIndex = 0
                    currentStrokeIndex = 0
                    accumulatedStrokes = []
                    advanceReplay()
                }
            }
        }
    }
    
    private var currentStrokeInDrawing: Int { currentStrokeIndex }
    
    private func advanceReplay() {
        guard isPlaying, currentDrawingIndex < drawings.count else { return }
        let drawing = drawings[currentDrawingIndex]
        let strokes = drawing.strokes
        if currentStrokeIndex < strokes.count {
            accumulatedStrokes.append(strokes[currentStrokeIndex])
            currentStrokeIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { advanceReplay() }
        } else {
            currentDrawingIndex += 1
            currentStrokeIndex = 0
            if currentDrawingIndex < drawings.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { advanceReplay() }
            } else {
                isPlaying = false
            }
        }
    }
}

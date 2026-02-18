//
//  VoicePlaybackView.swift
//  Unfin
//

import SwiftUI
import AVKit

/// Shows a play button; on tap loads the voice from storage and plays in a sheet.
struct VoicePlaybackView: View {
    @EnvironmentObject var store: IdeaStore
    let storagePath: String
    @State private var playURL: URL?
    @State private var showPlayer = false
    @State private var isLoading = false
    
    var body: some View {
        Button {
            Task {
                isLoading = true
                let url = await store.voiceURL(storagePath: storagePath)
                await MainActor.run {
                    playURL = url
                    isLoading = false
                    if url != nil { showPlayer = true }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                Text("Play voice")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .sheet(isPresented: $showPlayer) {
            if let url = playURL {
                VoicePlayerSheet(url: url)
            }
        }
    }
}

private struct VoicePlayerSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = AVPlayer(url: url)
        vc.player?.play()
        return vc
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

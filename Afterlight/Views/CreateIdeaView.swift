//
//  CreateIdeaView.swift
//  Unfin
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

struct ImageFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in ImageFile(data: data) }
    }
}

struct PendingPhoto: Identifiable {
    let id = UUID()
    let item: PhotosPickerItem
}

struct PendingFile: Identifiable {
    let id = UUID()
    let localURL: URL
    let displayName: String
    let kind: AttachmentKind
}

struct CreateIdeaView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var content = ""
    @State private var selectedCategoryId: UUID = Category.fictionId
    @State private var showAlert = false
    @State private var showConfetti = false
    @State private var isPosting = false
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingFiles: [PendingFile] = []
    @State private var showFileImporter = false
    
    @State private var showNewCategorySheet = false
    @State private var newCategoryName = ""
    @State private var newCategoryVerb = "Complete"
    
    @State private var isSensitive = false

    enum TimeLimitOption: String, CaseIterable {
        case none
        case hours24
        case hours48
        case week
        var label: String {
            switch self {
            case .none: return "No limit"
            case .hours24: return "24 hours"
            case .hours48: return "48 hours"
            case .week: return "1 week"
            }
        }
        var interval: TimeInterval? {
            switch self {
            case .none: return nil
            case .hours24: return 24 * 3600
            case .hours48: return 48 * 3600
            case .week: return 7 * 24 * 3600
            }
        }
    }
    @State private var timeLimitOption: TimeLimitOption = .none
    
    @State private var showRestoreDraftAlert = false
    @State private var hasCheckedDraft = false
    
    @StateObject private var voiceRecorder = VoiceRecorder()
    @State private var recordedVoiceURL: URL?
    
    private var hasContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || recordedVoiceURL != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        categorySection
                        ideaSection
                        sensitiveSection
                        timeLimitSection
                        hintText
                        if hasContent {
                            Button {
                                saveDraftAndDismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Save draft")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundStyle(Color.white.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    .padding(AppTheme.Spacing.screenHorizontal)
                    .padding(.bottom, 32)
                }

                ConfettiView(isActive: showConfetti, duration: 2.5)
                    .ignoresSafeArea()
            }
            .navigationTitle("New idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .presentationCornerRadius(24)
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.white.opacity(0.92))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { postIdea() }
                        .fontWeight(.semibold)
                        .foregroundStyle(hasContent ? Color.white : Color.gray)
                        .disabled(!hasContent || isPosting)
                }
            }
            .onAppear {
                if !hasCheckedDraft, let draft = DraftStore.loadIdeaDraft(), !draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    showRestoreDraftAlert = true
                }
                hasCheckedDraft = true
            }
            .alert("Resume draft?", isPresented: $showRestoreDraftAlert) {
                Button("Start fresh") {
                    DraftStore.clearIdeaDraft()
                }
                Button("Restore") {
                    if let d = DraftStore.loadIdeaDraft() {
                        content = d.content
                        selectedCategoryId = d.categoryId
                        isSensitive = d.isSensitive
                    }
                }
            } message: {
                Text("You have a saved draft. Restore it or start a new idea.")
            }
            .alert("Idea posted", isPresented: $showAlert) {
                Button("OK") {
                    showConfetti = false
                    dismiss()
                }
            } message: {
                Text("Your idea is now in the feed. Others can complete it.")
            }
            .alert("Couldn’t post idea", isPresented: Binding(
                get: { store.postError != nil },
                set: { if !$0 { store.postError = nil } }
            )) {
                Button("OK") { store.postError = nil }
            } message: {
                Text(store.postError ?? "")
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [
                    .audio,
                    .pdf,
                    .plainText,
                    .content,
                    .data,
                    .image,
                    .movie
                ],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result: result)
            }
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.categories) { category in
                        Button {
                            selectedCategoryId = category.id
                        } label: {
                            Text(category.displayName)
                                .font(.system(size: 14))
                                .foregroundStyle(selectedCategoryId == category.id ? Color(white: 0.12) : Color.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedCategoryId == category.id ? Color.white : Color.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        newCategoryName = ""
                        newCategoryVerb = "Complete"
                        showNewCategorySheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12))
                            Text("New category")
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showNewCategorySheet) {
            newCategorySheet
        }
    }
    
    private var newCategorySheet: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.12).ignoresSafeArea()
                Form {
                    TextField("Category name", text: $newCategoryName)
                        .foregroundStyle(Color(white: 0.1))
                    TextField("Action verb (e.g. Complete, Write)", text: $newCategoryVerb)
                        .foregroundStyle(Color(white: 0.1))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.12), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNewCategorySheet = false
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let verb = newCategoryVerb.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            let cat = store.addCategory(displayName: name, actionVerb: verb.isEmpty ? "Complete" : verb)
                            selectedCategoryId = cat.id
                            showNewCategorySheet = false
                        }
                    }
                    .foregroundStyle(.white)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var ideaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your idea")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $content)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                Divider()
                    .background(Color.white.opacity(0.15))
                HStack(spacing: 12) {
                    if voiceRecorder.isRecording {
                        Button {
                            if let url = voiceRecorder.stop() {
                                recordedVoiceURL = url
                            }
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    } else if recordedVoiceURL != nil {
                        Button {
                            recordedVoiceURL = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            voiceRecorder.requestPermission { granted in
                                guard granted else { return }
                                _ = try? voiceRecorder.start()
                            }
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.white)
                        }
                        .buttonStyle(.plain)
                    }
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Spacer()
                }
                if !selectedPhotoItems.isEmpty || !pendingFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(selectedPhotoItems.enumerated()), id: \.offset) { _, _ in
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundStyle(Color.white.opacity(0.9))
                                Text("Photo")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        ForEach(pendingFiles) { file in
                            HStack {
                                Image(systemName: file.kind.iconName)
                                    .foregroundStyle(Color.white.opacity(0.9))
                                Text(file.displayName)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.white)
                                Spacer()
                                Button {
                                    pendingFiles.removeAll { $0.id == file.id }
                                    try? FileManager.default.removeItem(at: file.localURL)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.white.opacity(0.75))
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                if voiceRecorder.permissionDenied {
                    Text("Microphone access was denied. Enable it in Settings to record.")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
    }
    
    private var sensitiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isSensitive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sensitive content")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Text("Blur until readers choose to reveal")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
            }
            .tint(Color.white.opacity(0.9))
        }
    }

    private var timeLimitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time limit")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text("Close this idea to new completions after a set time. People can still read it.")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.65))
            Picker("Time limit", selection: $timeLimitOption) {
                ForEach(TimeLimitOption.allCases, id: \.self) { opt in
                    Text(opt.label).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)
        }
    }
    
    private var hintText: some View {
        Text("Share a song hook, story start, show concept, or any incomplete idea. Add photos, audio, or documents.")
            .font(.system(size: 13))
            .foregroundStyle(Color.white.opacity(0.85))
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        let inbox = FileManager.default.temporaryDirectory.appendingPathComponent("UnfinInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        for url in urls {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            let name = url.lastPathComponent
            let dest = inbox.appendingPathComponent("\(UUID().uuidString)_\(name)")
            if (try? FileManager.default.copyItem(at: url, to: dest)) != nil {
                let kind = attachmentKind(for: url)
                pendingFiles.append(PendingFile(localURL: dest, displayName: name, kind: kind))
            }
        }
    }
    
    private func saveDraftAndDismiss() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty || recordedVoiceURL != nil {
            DraftStore.saveIdeaDraft(content: content, categoryId: selectedCategoryId, isSensitive: isSensitive)
        }
        dismiss()
    }

    private func attachmentKind(for url: URL) -> AttachmentKind {
        let ext = url.pathExtension.lowercased()
        let audio = ["mp3", "m4a", "wav", "aac", "ogg"]
        let images = ["jpg", "jpeg", "png", "heic", "gif", "webp"]
        if audio.contains(ext) { return .audio }
        if images.contains(ext) { return .image }
        if ["pdf", "doc", "docx", "txt", "rtf"].contains(ext) { return .document }
        return .document
    }
    
    private func postIdea() {
        guard hasContent else { return }
        isPosting = true
        let limitOption = timeLimitOption
        let ideaId = UUID()
        let dir = store.attachmentsDirectory(for: ideaId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var attachments: [Attachment] = []
        let voiceURL = recordedVoiceURL
        
        Task {
            guard let authorId = store.currentUserId else {
                await MainActor.run {
                    isPosting = false
                    store.postError = "You must be signed in to post."
                }
                return
            }
            var voicePath: String?
            if let url = voiceURL {
                do {
                    voicePath = try await store.uploadVoiceForIdea(ideaId: ideaId, fileURL: url)
                } catch {
                    await MainActor.run {
                        isPosting = false
                        store.postError = "Failed to upload voice: \(error.localizedDescription)"
                    }
                    return
                }
            }
            for item in selectedPhotoItems {
                if let imageFile = try? await item.loadTransferable(type: ImageFile.self) {
                    let fileName = "\(UUID().uuidString).jpg"
                    let fileURL = dir.appendingPathComponent(fileName)
                    try? imageFile.data.write(to: fileURL)
                    attachments.append(Attachment(fileName: fileName, displayName: "Photo", kind: .image))
                }
            }
            await MainActor.run {
                for file in pendingFiles {
                    let fileName = "\(UUID().uuidString)_\(file.displayName)"
                    let dest = dir.appendingPathComponent(fileName)
                    if (try? FileManager.default.copyItem(at: file.localURL, to: dest)) != nil {
                        attachments.append(Attachment(fileName: fileName, displayName: file.displayName, kind: file.kind))
                    }
                    try? FileManager.default.removeItem(at: file.localURL)
                }
            }
            let textContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let closesAt: Date? = limitOption.interval.map { Date().addingTimeInterval($0) }
            let idea = Idea(
                id: ideaId,
                categoryId: selectedCategoryId,
                content: textContent.isEmpty && voicePath == nil ? "Attachment" : (textContent.isEmpty ? "Voice note" : textContent),
                voicePath: voicePath,
                drawingPath: nil,
                authorId: authorId,
                authorDisplayName: store.currentUserName,
                attachments: attachments,
                closesAt: closesAt,
                isSensitive: isSensitive
            )
            do {
                try await store.addIdea(idea)
                await MainActor.run {
                    DraftStore.clearIdeaDraft()
                    isPosting = false
                    showConfetti = true
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    store.postError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Confetti (in-scope for CreateIdeaView)
private struct ConfettiView: View {
    var isActive: Bool
    var duration: TimeInterval = 2.5
    var particleCount: Int = 70

    @State private var progress: CGFloat = 0
    @State private var hasStarted = false
    @State private var particles: [ConfettiParticle] = []

    private static let colors: [Color] = [
        .white, Color(red: 1, green: 0.4, blue: 0.4), Color(red: 0.4, green: 0.8, blue: 1),
        Color(red: 0.5, green: 1, blue: 0.5), Color(red: 1, green: 0.85, blue: 0.4),
        Color(red: 0.9, green: 0.5, blue: 1)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    confettiShape(p, in: geo.size)
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: isActive) { _, active in
            if active && !hasStarted { startConfetti() }
        }
        .onAppear {
            if isActive && !hasStarted { startConfetti() }
        }
    }

    private func startConfetti() {
        guard !hasStarted else { return }
        hasStarted = true
        #if os(iOS)
        let size = UIScreen.main.bounds.size
        #else
        let size = CGSize(width: 400, height: 600)
        #endif
        particles = (0..<particleCount).map { _ in ConfettiParticle(size: size, colors: Self.colors) }
        withAnimation(.easeOut(duration: duration)) { progress = 1 }
    }

    private func confettiShape(_ p: ConfettiParticle, in size: CGSize) -> some View {
        let endY = p.fallDistance * progress
        let endX = p.driftX * progress
        let opacity = Double(1 - progress)
        let rotation = p.rotationStart + progress * p.rotationEnd
        return Group {
            if p.isCircle {
                Circle().fill(p.color).frame(width: p.size, height: p.size)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(p.color).frame(width: p.size * 1.4, height: p.size * 0.6)
            }
        }
        .rotationEffect(.degrees(rotation))
        .position(x: size.width * 0.5 + p.startX + endX, y: size.height * 0.35 + p.startY + endY)
        .opacity(opacity)
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let driftX: CGFloat
    let fallDistance: CGFloat
    let rotationStart: CGFloat
    let rotationEnd: CGFloat
    let color: Color
    let size: CGFloat
    let isCircle: Bool

    init(size: CGSize, colors: [Color]) {
        startX = CGFloat.random(in: -size.width * 0.4...size.width * 0.4)
        startY = CGFloat.random(in: -30...20)
        driftX = CGFloat.random(in: -80...80)
        fallDistance = CGFloat.random(in: 200...400)
        rotationStart = CGFloat.random(in: 0...360)
        rotationEnd = CGFloat.random(in: 360...720)
        color = colors.randomElement() ?? .white
        self.size = CGFloat.random(in: 6...14)
        isCircle = Bool.random()
    }
}

#Preview {
    CreateIdeaView()
        .environmentObject(IdeaStore())
}

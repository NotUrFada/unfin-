//
//  IdeaDetailView.swift
//  Unfin
//

import SwiftUI
import QuickLook
import PhotosUI
import UniformTypeIdentifiers

struct IdeaDetailView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.dismiss) private var dismiss

    let ideaId: UUID
    var onOpenUserProfile: ((String, UUID?) -> Void)? = nil
    @State private var completionText = ""
    @State private var completionIsPublic = true
    @State private var showSubmitted = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var expandedCommentContributionId: UUID?
    @State private var showReportIdeaSheet = false
    @State private var showHideIdeaConfirm = false
    @State private var sensitiveContentRevealed = false
    @FocusState private var focusField: Bool
    
    @StateObject private var completionVoiceRecorder = VoiceRecorder()
    @State private var completionRecordedVoiceURL: URL?
    @State private var selectedCompletionPhotoItems: [PhotosPickerItem] = []
    @State private var completionPendingFiles: [PendingFile] = []
    @State private var showCompletionFileImporter = false
    
    private var ideaToShow: Idea? {
        store.idea(byId: ideaId)
    }
    
    private var canDelete: Bool {
        guard let idea = ideaToShow, let userId = store.currentUserId else { return false }
        if let aid = idea.authorId { return aid == userId }
        return idea.authorDisplayName == store.currentUserName
    }

    @ViewBuilder
    private func authorLine(idea: Idea) -> some View {
        if let onOpen = onOpenUserProfile {
            Button {
                onOpen(idea.authorDisplayName, idea.authorId)
            } label: {
                Text("By \(idea.authorDisplayName)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        } else {
            Text("By \(idea.authorDisplayName)")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    var body: some View {
        Group {
            if let idea = ideaToShow {
                detailContent(idea: idea)
            } else {
                Text("Idea not found")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if canDelete, let idea = ideaToShow, !idea.isFinished {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.markIdeaAsFinished(ideaId: ideaId)
                    } label: {
                        Label("Mark as finished", systemImage: "checkmark.circle")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            if store.currentUserId != nil, !canDelete {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showReportIdeaSheet = true
                        } label: { Label("Report", systemImage: "exclamationmark.triangle") }
                        Button {
                            showHideIdeaConfirm = true
                        } label: { Label("Don't show this again", systemImage: "eye.slash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            if canDelete {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .foregroundStyle(.red.opacity(0.9))
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .alert("Submitted", isPresented: $showSubmitted) {
            Button("OK") {
                completionText = ""
                focusField = false
            }
        } message: {
            Text("Your completion was added. Thanks for finishing the idea.")
        }
        .alert("Delete idea?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performDelete()
            }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Couldn’t delete", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .alert("Don't show this again?", isPresented: $showHideIdeaConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Hide") {
                store.hideIdea(ideaId: ideaId)
                dismiss()
            }
        } message: {
            Text("This idea will be removed from your feed.")
        }
        .sheet(isPresented: $showReportIdeaSheet) {
            ReportReasonSheet(
                title: "Report idea",
                onSubmit: { reason, details in
                    store.reportIdea(ideaId: ideaId, reason: reason, details: details)
                    showReportIdeaSheet = false
                },
                onCancel: { showReportIdeaSheet = false }
            )
        }
    }
    
    private func performDelete() {
        isDeleting = true
        Task {
            do {
                try await store.deleteIdea(ideaId: ideaId)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                }
            }
            await MainActor.run { isDeleting = false }
        }
    }
    
    private var progressBarColor: Color {
        if let v = store.currentAccount?.auraVariant {
            return AuraConfig.from(variant: v).colors.0
        }
        if let p = store.currentAccount?.auraPaletteIndex {
            return AuraConfig.fromLegacy(paletteIndex: p).colors.0
        }
        return Color.white.opacity(0.9)
    }
    
    private func completionProgressSection(idea: Idea) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text("\(idea.completionPercentage)%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressBarColor)
                        .frame(width: max(0, geo.size.width * CGFloat(idea.completionPercentage) / 100), height: 10)
                }
            }
            .frame(height: 10)
            if canDelete {
                Slider(value: Binding(
                    get: { Double(idea.completionPercentage) },
                    set: { store.setIdeaCompletionPercentage(ideaId: idea.id, percentage: Int($0)) }
                ), in: 0...100, step: 5)
                .tint(progressBarColor)
                Text("Set how complete this is. Still accepting until 100% or you mark as finished.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                if idea.completionPercentage < 100 {
                    Text("Author is still accepting contributions.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func ideaRatingRow(idea: Idea) -> some View {
        let myRating = store.myIdeaRatings[idea.id] ?? 0
        return HStack(alignment: .center, spacing: 16) {
            if idea.ratingCount > 0, let avg = idea.averageRating {
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", avg))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                    Text("(\(idea.ratingCount))")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            if store.currentUserId != nil, !store.isCurrentUserIdeaAuthor(ideaId: idea.id) {
                HStack(spacing: 2) {
                    Text("Your rating:")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            store.setIdeaRating(ideaId: idea.id, rating: star)
                        } label: {
                            Image(systemName: myRating >= star ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundStyle(myRating >= star ? Color.yellow : Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    if myRating > 0 {
                        Button {
                            store.clearIdeaRating(ideaId: idea.id)
                        } label: {
                            Text("Clear")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func ideaBodyContent(idea: Idea) -> some View {
        Group {
            if idea.isSensitive, !store.isCurrentUserIdeaAuthor(ideaId: idea.id), !sensitiveContentRevealed {
                ZStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(idea.content)
                            .font(.system(size: 18))
                            .lineSpacing(6)
                            .foregroundStyle(.white)
                    }
                    .blur(radius: 14)
                    Button {
                        sensitiveContentRevealed = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 36))
                            Text("Sensitive content")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Tap to reveal")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(idea.content)
                        .font(.system(size: 18))
                        .lineSpacing(6)
                        .foregroundStyle(.white)
                    if let voicePath = idea.voicePath {
                        VoicePlaybackView(storagePath: voicePath)
                            .environmentObject(store)
                    }
                    if !idea.attachments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attachments")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                            ForEach(idea.attachments) { att in
                                AttachmentRowView(ideaId: idea.id, attachment: att)
                                    .environmentObject(store)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func detailContent(idea: Idea) -> some View {
        
        ZStack {
            Color(white: 0.12).ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        categoryTag(categoryId: idea.categoryId)
                        if idea.isSensitive {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 10))
                                Text("Sensitive")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        if idea.isFinished {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                Text("Finished")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        Spacer()
                        Text(idea.timeAgo)
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                    }

                    authorLine(idea: idea)

                    ideaRatingRow(idea: idea)

                    completionProgressSection(idea: idea)

                    ideaBodyContent(idea: idea)
                    
                    if !idea.contributions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Completions")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                            
                            ForEach(idea.contributions) { c in
                                CompletionRowView(
                                    ideaId: idea.id,
                                    contribution: c,
                                    isCommentExpanded: expandedCommentContributionId == c.id,
                                    onOpenUserProfile: onOpenUserProfile,
                                    onToggleComments: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            expandedCommentContributionId = expandedCommentContributionId == c.id ? nil : c.id
                                        }
                                    },
                                    onSubmitComment: { draft, voiceFileURL in
                                        if let url = voiceFileURL {
                                            Task {
                                                let path = try? await store.uploadVoiceForComment(ideaId: idea.id, fileURL: url)
                                                await MainActor.run {
                                                    store.addComment(ideaId: idea.id, contributionId: c.id, content: draft, voicePath: path)
                                                }
                                            }
                                        } else {
                                            store.addComment(ideaId: idea.id, contributionId: c.id, content: draft)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    if !idea.isFinished, !store.isCurrentUserIdeaAuthor(ideaId: idea.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add your completion")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                        Picker("Visibility", selection: $completionIsPublic) {
                            Text("Public").tag(true)
                            Text("Private").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .colorScheme(.dark)
                        VStack(alignment: .leading, spacing: 0) {
                            TextEditor(text: $completionText)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                                .padding(16)
                                .focused($focusField)
                            HStack(spacing: 16) {
                                completionVoiceIconButton
                                PhotosPicker(
                                    selection: $selectedCompletionPhotoItems,
                                    maxSelectionCount: 5,
                                    matching: .images
                                ) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .buttonStyle(.plain)
                                Button {
                                    showCompletionFileImporter = true
                                } label: {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.06))
                            if !selectedCompletionPhotoItems.isEmpty || !completionPendingFiles.isEmpty {
                                completionSelectedAttachmentsRow
                            }
                        }
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                    .fileImporter(
                        isPresented: $showCompletionFileImporter,
                        allowedContentTypes: [.audio, .pdf, .plainText, .content, .data, .image, .movie],
                        allowsMultipleSelection: true
                    ) { result in
                        handleCompletionFileImport(result: result)
                    }
                    
                    Button {
                        submitCompletion()
                    } label: {
                        HStack {
                            Text(store.categoryActionVerb(byId: idea.categoryId))
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(white: 0.12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(!completionHasContent)
                    .opacity(completionHasContent ? 1 : 0.6)
                    
                    Color.clear.frame(height: 40)
                    } else if !idea.isFinished, store.isCurrentUserIdeaAuthor(ideaId: idea.id) {
                        Text("You started this idea. Others can add completions.")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        Color.clear.frame(height: 40)
                    } else {
                        Text("This idea is finished. No new completions.")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        Color.clear.frame(height: 40)
                    }
                }
                .padding(24)
            }
        }
    }
    
    private var completionHasContent: Bool {
        !completionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || completionRecordedVoiceURL != nil
            || !selectedCompletionPhotoItems.isEmpty
            || !completionPendingFiles.isEmpty
    }
    
    private func handleCompletionFileImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        let inbox = FileManager.default.temporaryDirectory.appendingPathComponent("UnfinCompletionInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        for url in urls {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            let name = url.lastPathComponent
            let dest = inbox.appendingPathComponent("\(UUID().uuidString)_\(name)")
            if (try? FileManager.default.copyItem(at: url, to: dest)) != nil {
                let kind = attachmentKind(for: url)
                completionPendingFiles.append(PendingFile(localURL: dest, displayName: name, kind: kind))
            }
        }
    }
    
    private func attachmentKind(for url: URL) -> AttachmentKind {
        let ext = url.pathExtension.lowercased()
        if ["mp3", "m4a", "wav", "aac", "ogg"].contains(ext) { return .audio }
        if ["jpg", "jpeg", "png", "heic", "gif", "webp"].contains(ext) { return .image }
        if ["pdf", "doc", "docx", "txt", "rtf"].contains(ext) { return .document }
        return .document
    }
    
    private var completionVoiceIconButton: some View {
        Group {
            if completionVoiceRecorder.isRecording {
                Button {
                    completionRecordedVoiceURL = completionVoiceRecorder.stop()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else if completionRecordedVoiceURL != nil {
                Button {
                    completionRecordedVoiceURL = nil
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.9))
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    completionVoiceRecorder.requestPermission { granted in
                        guard granted else { return }
                        _ = try? completionVoiceRecorder.start()
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var completionSelectedAttachmentsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(selectedCompletionPhotoItems.enumerated()), id: \.offset) { _, _ in
                HStack {
                    Image(systemName: "photo").foregroundStyle(.white.opacity(0.8))
                    Text("Photo").font(.system(size: 12)).foregroundStyle(.white)
                    Spacer()
                    Button {
                        selectedCompletionPhotoItems.removeAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            ForEach(completionPendingFiles) { file in
                HStack {
                    Image(systemName: file.kind.iconName).foregroundStyle(.white.opacity(0.8))
                    Text(file.displayName).font(.system(size: 12)).lineLimit(1).foregroundStyle(.white)
                    Spacer()
                    Button {
                        completionPendingFiles.removeAll { $0.id == file.id }
                        try? FileManager.default.removeItem(at: file.localURL)
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private func categoryTag(categoryId: UUID) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(store.categoryDisplayName(byId: categoryId))
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.85))
        }
    }
    
    private func submitCompletion() {
        let trimmed = completionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard completionHasContent else { return }
        let voiceURL = completionRecordedVoiceURL
        let photoItems = selectedCompletionPhotoItems
        let pendingFiles = completionPendingFiles
        let hasAsync = voiceURL != nil || !photoItems.isEmpty || !pendingFiles.isEmpty
        if hasAsync {
            Task {
                do {
                    let contribId = UUID()
                    var voicePath: String? = nil
                    if let url = voiceURL {
                        voicePath = try await store.uploadVoiceForContribution(ideaId: ideaId, fileURL: url)
                    }
                    var filesToUpload: [(url: URL, displayName: String, kind: AttachmentKind)] = pendingFiles.map { ($0.localURL, $0.displayName, $0.kind) }
                    for item in photoItems {
                        if let img = try? await item.loadTransferable(type: ImageFile.self) {
                            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("UnfinCompletionPhotos", isDirectory: true)
                            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                            let fileURL = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")
                            if (try? img.data.write(to: fileURL)) != nil {
                                filesToUpload.append((fileURL, "Photo", .image))
                            }
                        }
                    }
                    let attachments = try await store.uploadCompletionAttachments(ideaId: ideaId, contributionId: contribId, files: filesToUpload)
                    let contentForContrib = trimmed.isEmpty && voicePath == nil && attachments.isEmpty ? "Attachment" : (trimmed.isEmpty ? "Attachment" : trimmed)
                    await MainActor.run {
                        store.addContribution(ideaId: ideaId, content: contentForContrib, isPublic: completionIsPublic, voicePath: voicePath, attachments: attachments, contributionId: contribId)
                        completionRecordedVoiceURL = nil
                        completionText = ""
                        selectedCompletionPhotoItems = []
                        completionPendingFiles.forEach { try? FileManager.default.removeItem(at: $0.localURL) }
                        completionPendingFiles = []
                        focusField = false
                        showSubmitted = true
                    }
                } catch {
                    await MainActor.run { store.postError = error.localizedDescription }
                }
            }
        } else {
            store.addContribution(ideaId: ideaId, content: trimmed, isPublic: completionIsPublic)
            completionText = ""
            focusField = false
            showSubmitted = true
        }
    }
}

// MARK: - Completion row with reactions, share, comments
struct CompletionRowView: View {
    @EnvironmentObject var store: IdeaStore
    let ideaId: UUID
    let contribution: Contribution
    let isCommentExpanded: Bool
    var onOpenUserProfile: ((String, UUID?) -> Void)? = nil
    var onToggleComments: () -> Void
    var onSubmitComment: (String, URL?) -> Void
    @State private var commentDraft = ""
    @State private var commentVoiceURL: URL?
    @State private var showStickerPicker = false
    @State private var commentIdShowingStickerPicker: UUID?
    @StateObject private var commentVoiceRecorder = VoiceRecorder()
    @StateObject private var editVoiceRecorder = VoiceRecorder()
    @State private var showDeleteContribConfirm = false
    @State private var showRemoveContribConfirm = false
    @State private var showEditContrib = false
    @State private var editContribDraft = ""
    @State private var editContribVoiceURL: URL?
    @State private var showReportContribSheet = false
    
    private var canEditContrib: Bool { store.canCurrentUserEditContribution(contribution) }
    private var isIdeaAuthor: Bool { store.isCurrentUserIdeaAuthor(ideaId: ideaId) }
    /// True if this contribution was posted by the current user (so idea author can’t rate their own completion).
    private var isOwnContribution: Bool {
        if let cid = contribution.authorId, let uid = store.currentUserId { return cid == uid }
        return contribution.authorDisplayName == store.currentUserName
    }

    private var contributionRatingRow: some View {
        HStack(spacing: 2) {
            Text("Rate:")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))
            ForEach(1...5, id: \.self) { star in
                Button {
                    store.setContributionRating(ideaId: ideaId, contributionId: contribution.id, rating: star)
                } label: {
                    Image(systemName: (contribution.authorRating ?? 0) >= star ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle((contribution.authorRating ?? 0) >= star ? Color.yellow : Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            if contribution.authorRating != nil {
                Button {
                    store.clearContributionRating(ideaId: ideaId, contributionId: contribution.id)
                } label: {
                    Text("Clear")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let voicePath = contribution.voicePath {
                        VoicePlaybackView(storagePath: voicePath)
                            .environmentObject(store)
                    }
                    if !contribution.content.isEmpty {
                        Text(contribution.content)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                    }
                    HStack(spacing: 6) {
                        if let onOpen = onOpenUserProfile {
                            Button {
                                onOpen(contribution.authorDisplayName, contribution.authorId)
                            } label: {
                                Text("— \(contribution.authorDisplayName)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("— \(contribution.authorDisplayName)")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        if contribution.editedAt != nil {
                            Text("· Edited")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        if !contribution.isPublic {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    if store.isCurrentUserIdeaAuthor(ideaId: ideaId), !isOwnContribution {
                        contributionRatingRow
                    } else if let rating = contribution.authorRating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundStyle(star <= rating ? Color.yellow : Color.white.opacity(0.3))
                            }
                            Text("Idea author’s rating")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.leading, 4)
                        }
                        .padding(.top, 4)
                    }
                }
                Spacer()
                if canEditContrib || isIdeaAuthor || (store.currentUserId != nil && !isOwnContribution) {
                    Menu {
                        if store.currentUserId != nil, !isOwnContribution {
                            Button {
                                showReportContribSheet = true
                            } label: { Label("Report", systemImage: "exclamationmark.triangle") }
                        }
                        if isIdeaAuthor {
                            Button(role: .destructive) {
                                showRemoveContribConfirm = true
                            } label: { Label("Remove from idea", systemImage: "xmark.circle") }
                        }
                        if canEditContrib {
                            Button(role: .destructive) {
                                showDeleteContribConfirm = true
                            } label: { Label("Delete", systemImage: "trash") }
                            Button {
                                editContribDraft = contribution.content
                                editContribVoiceURL = nil
                                showEditContrib = true
                            } label: { Label("Edit", systemImage: "pencil") }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if contribution.isPublic {
                if !contribution.attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Attachments")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                        ForEach(contribution.attachments) { att in
                            AttachmentRowView(ideaId: ideaId, attachment: att, contributionId: contribution.id)
                                .environmentObject(store)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 16) {
                        reactionBar
                        ShareLink(item: contribution.content) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Button(action: onToggleComments) {
                            HStack(spacing: 5) {
                                Image(systemName: "bubble.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("Comment")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                if contribution.comments.count > 0 {
                                    Text("(\(contribution.comments.count))")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !contribution.reactions.isEmpty {
                        reactionSummaryRow
                    }
                    if showStickerPicker {
                        stickerPicker
                    }
                }
                
                if isCommentExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comments")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.bottom, 2)
                        ForEach(contribution.comments) { comment in
                            CommentCellView(
                                ideaId: ideaId,
                                contributionId: contribution.id,
                                comment: comment,
                                showStickerPicker: commentIdShowingStickerPicker == comment.id,
                                onOpenUserProfile: onOpenUserProfile,
                                onToggleStickerPicker: { commentIdShowingStickerPicker = commentIdShowingStickerPicker == comment.id ? nil : comment.id },
                                onEdit: { store.updateComment(ideaId: ideaId, contributionId: contribution.id, commentId: comment.id, newContent: $0, newVoicePath: $1) },
                                onDelete: { store.deleteComment(ideaId: ideaId, contributionId: contribution.id, commentId: comment.id) }
                            )
                            .environmentObject(store)
                        }
                        commentInputRow
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .alert("Delete completion?", isPresented: $showDeleteContribConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                store.deleteContribution(ideaId: ideaId, contributionId: contribution.id)
            }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Remove this contribution?", isPresented: $showRemoveContribConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                store.removeContribution(ideaId: ideaId, contributionId: contribution.id)
            }
        } message: {
            Text("It will be removed from your idea. The contributor can still see it was removed.")
        }
        .sheet(isPresented: $showEditContrib) {
            editContributionSheet
        }
        .sheet(isPresented: $showReportContribSheet) {
            ReportReasonSheet(
                title: "Report contribution",
                onSubmit: { reason, details in
                    store.reportContribution(ideaId: ideaId, contributionId: contribution.id, reason: reason, details: details)
                    showReportContribSheet = false
                },
                onCancel: { showReportContribSheet = false }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var reactionBar: some View {
        HStack(spacing: 12) {
            ForEach(ReactionType.allCases, id: \.rawValue) { type in
                reactionButton(type: type.rawValue, symbolName: type.symbolName)
            }
            Button {
                showStickerPicker.toggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 14))
                }
                .foregroundStyle(store.currentUserReactionType(for: contribution)?.hasPrefix("sticker:") == true ? Color.orange : .white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func reactionButton(type: String, symbolName: String) -> some View {
        let count = contribution.count(for: type)
        let isSelected = store.currentUserReactionType(for: contribution) == type
        return Button {
            store.toggleReaction(ideaId: ideaId, contributionId: contribution.id, type: type)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: symbolName)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? (type == ReactionType.heart.rawValue ? Color.red : Color.orange) : .white.opacity(0.8))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var reactionSummaryRow: some View {
        let typesWithCount = ReactionType.allCases.filter { contribution.count(for: $0.rawValue) > 0 }
        let stickerReactions = contribution.reactions.filter { $0.type.hasPrefix("sticker:") }
        let stickerEmojiString = stickerReactions.compactMap { r -> String? in
            let id = r.type.replacingOccurrences(of: "sticker:", with: "")
            return ReactionStickers.all.first(where: { $0.id == id })?.emoji
        }.prefix(3).joined()
        return HStack(spacing: 8) {
            ForEach(typesWithCount, id: \.rawValue) { type in
                HStack(spacing: 4) {
                    Image(systemName: type.symbolName)
                        .font(.system(size: 12))
                        .foregroundStyle(type == .heart ? .red : .white.opacity(0.9))
                    Text("\(contribution.count(for: type.rawValue))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            if !stickerReactions.isEmpty {
                Text(stickerEmojiString)
                    .font(.system(size: 14))
                if stickerReactions.count > 1 {
                    Text("×\(stickerReactions.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.top, 4)
    }
    
    private var commentInputRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Add a comment...", text: $commentDraft)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button("Post") {
                    let text = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    let hasContent = !text.isEmpty || commentVoiceURL != nil
                    if hasContent {
                        onSubmitComment(text, commentVoiceURL)
                        commentDraft = ""
                        commentVoiceURL = nil
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && commentVoiceURL == nil)
            }
            HStack(spacing: 8) {
                if commentVoiceRecorder.isRecording {
                    Button { commentVoiceURL = commentVoiceRecorder.stop() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundStyle(.red)
                            Text("Stop")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .buttonStyle(.plain)
                } else if commentVoiceURL != nil {
                    Text("Voice added")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                    Button { commentVoiceURL = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        commentVoiceRecorder.requestPermission { granted in
                            guard granted else { return }
                            _ = try? commentVoiceRecorder.start()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                            Text("Voice")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }
    
    private var editContributionSheet: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.12).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    TextEditor(text: $editContribDraft)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    if editVoiceRecorder.isRecording {
                        Button { editContribVoiceURL = editVoiceRecorder.stop() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Stop recording")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    } else if editContribVoiceURL != nil {
                        HStack {
                            Text("Voice recorded")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.9))
                            Button { editContribVoiceURL = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button {
                            editVoiceRecorder.requestPermission { granted in
                                guard granted else { return }
                                _ = try? editVoiceRecorder.start()
                            }
                        } label: {
                            Label("Record voice", systemImage: "mic.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Edit completion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.12), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditContrib = false }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newContent = editContribDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !newContent.isEmpty || editContribVoiceURL != nil else { return }
                        if let url = editContribVoiceURL {
                            Task {
                                let path = try? await store.uploadVoiceForContribution(ideaId: ideaId, fileURL: url)
                                await MainActor.run {
                                    store.updateContribution(ideaId: ideaId, contributionId: contribution.id, newContent: newContent.isEmpty ? "Voice reply" : newContent, newVoicePath: path)
                                    showEditContrib = false
                                }
                            }
                        } else {
                            store.updateContribution(ideaId: ideaId, contributionId: contribution.id, newContent: newContent, newVoicePath: nil)
                            showEditContrib = false
                        }
                    }
                    .foregroundStyle(.white)
                    .disabled(editContribDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && editContribVoiceURL == nil)
                }
            }
        }
    }
    
    private var stickerPicker: some View {
        HStack(spacing: 12) {
            ForEach(Array(ReactionStickers.all.enumerated()), id: \.offset) { _, sticker in
                let stickerType = "sticker:\(sticker.id)"
                Button {
                    store.toggleReaction(ideaId: ideaId, contributionId: contribution.id, type: stickerType)
                    showStickerPicker = false
                } label: {
                    Text(sticker.emoji)
                        .font(.system(size: 28))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Comment row with like and sticker reactions
private struct CommentCellView: View {
    @EnvironmentObject var store: IdeaStore
    let ideaId: UUID
    let contributionId: UUID
    let comment: Comment
    let showStickerPicker: Bool
    var onOpenUserProfile: ((String, UUID?) -> Void)? = nil
    var onToggleStickerPicker: () -> Void
    var onEdit: (String, String?) -> Void
    var onDelete: () -> Void
    
    @State private var showDeleteCommentConfirm = false
    @State private var showEditComment = false
    @State private var editCommentDraft = ""
    
    private var canEditComment: Bool { store.canCurrentUserEditComment(comment) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let voicePath = comment.voicePath {
                        VoicePlaybackView(storagePath: voicePath)
                            .environmentObject(store)
                    }
                    if !comment.content.isEmpty {
                        Text(comment.content)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    HStack(spacing: 4) {
                        if let onOpen = onOpenUserProfile {
                            Button {
                                onOpen(comment.authorDisplayName, comment.authorId)
                            } label: {
                                Text("— \(comment.authorDisplayName)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("— \(comment.authorDisplayName)")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        if comment.editedAt != nil {
                            Text("· Edited")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                Spacer()
                if canEditComment {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteCommentConfirm = true
                        } label: { Label("Delete", systemImage: "trash") }
                        Button {
                            editCommentDraft = comment.content
                            showEditComment = true
                        } label: { Label("Edit", systemImage: "pencil") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                commentReactionBar
            }
            if showStickerPicker {
                commentStickerPicker
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .alert("Delete comment?", isPresented: $showDeleteCommentConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $showEditComment) {
            editCommentSheet
        }
    }
    
    private var editCommentSheet: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.12).ignoresSafeArea()
                TextField("Comment", text: $editCommentDraft, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .padding(16)
                    .lineLimit(3...6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(24)
            }
            .navigationTitle("Edit comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.12), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditComment = false }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let text = editCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        onEdit(text, comment.voicePath)
                        showEditComment = false
                    }
                    .foregroundStyle(.white)
                    .disabled(editCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var commentReactionBar: some View {
        HStack(spacing: 10) {
            ForEach(ReactionType.allCases, id: \.rawValue) { type in
                commentReactionButton(type: type.rawValue, symbolName: type.symbolName)
            }
            Button(action: onToggleStickerPicker) {
                Image(systemName: "face.smiling.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(store.currentUserReactionType(for: comment)?.hasPrefix("sticker:") == true ? Color.orange : .white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func commentReactionButton(type: String, symbolName: String) -> some View {
        let count = comment.count(for: type)
        let isSelected = store.currentUserReactionType(for: comment) == type
        return Button {
            store.toggleReactionOnComment(ideaId: ideaId, contributionId: contributionId, commentId: comment.id, type: type)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: symbolName)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? (type == ReactionType.heart.rawValue ? Color.red : Color.orange) : .white.opacity(0.8))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var commentStickerPicker: some View {
        HStack(spacing: 12) {
            ForEach(Array(ReactionStickers.all.enumerated()), id: \.offset) { _, sticker in
                let stickerType = "sticker:\(sticker.id)"
                Button {
                    store.toggleReactionOnComment(ideaId: ideaId, contributionId: contributionId, commentId: comment.id, type: stickerType)
                    onToggleStickerPicker()
                } label: {
                    Text(sticker.emoji)
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

struct AttachmentRowView: View {
    @EnvironmentObject var store: IdeaStore
    let ideaId: UUID
    let attachment: Attachment
    var contributionId: UUID? = nil
    @State private var previewItem: IdentifiableURL?
    @State private var resolvedURL: URL?
    @State private var loadTaskId = UUID()
    
    var body: some View {
        Button {
            if let url = resolvedURL {
                previewItem = IdentifiableURL(url: url)
            } else {
                loadTaskId = UUID()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 36, height: 36)
                    if resolvedURL == nil {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: attachment.kind.iconName)
                            .font(.system(size: 18))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.displayName)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text(resolvedURL == nil ? "Loading…" : "Tap to preview")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                if resolvedURL != nil {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .task(id: loadTaskId) {
            if let cid = contributionId {
                resolvedURL = await store.attachmentURLForCompletion(ideaId: ideaId, contributionId: cid, attachment: attachment)
            } else {
                resolvedURL = await store.attachmentURL(ideaId: ideaId, attachment: attachment)
            }
        }
        .sheet(item: $previewItem) { item in
            QuickLookPreviewView(url: item.url)
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct QuickLookPreviewView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let ql = QLPreviewController()
        ql.dataSource = context.coordinator
        let nav = UINavigationController(rootViewController: ql)
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as QLPreviewItem }
    }
}

// MARK: - Report reason sheet (idea or contribution)
struct ReportReasonSheet: View {
    let title: String
    let onSubmit: (String, String?) -> Void
    let onCancel: () -> Void
    
    private static let reasons: [(value: String, label: String)] = [
        ("spam", "Spam"),
        ("harmful", "Harmful"),
        ("harassment", "Harassment"),
        ("other", "Other")
    ]
    
    @State private var selectedReason = "spam"
    @State private var detailsText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.12).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Reason")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(Self.reasons, id: \.value) { r in
                            Text(r.label).tag(r.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .colorScheme(.dark)
                    TextField("Details (optional)", text: $detailsText, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.12), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit(selectedReason, detailsText.isEmpty ? nil : detailsText)
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        IdeaDetailView(ideaId: UUID())
            .environmentObject(IdeaStore())
    }
}

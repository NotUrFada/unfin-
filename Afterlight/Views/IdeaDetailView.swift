//
//  IdeaDetailView.swift
//  Unfin
//

import SwiftUI
import QuickLook

struct IdeaDetailView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.dismiss) private var dismiss
    
    let ideaId: UUID
    @State private var completionText = ""
    @State private var completionIsPublic = true
    @State private var showSubmitted = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var expandedCommentContributionId: UUID?
    @FocusState private var focusField: Bool
    
    @StateObject private var completionVoiceRecorder = VoiceRecorder()
    @State private var completionRecordedVoiceURL: URL?
    
    private var ideaToShow: Idea? {
        store.idea(byId: ideaId)
    }
    
    private var canDelete: Bool {
        guard let idea = ideaToShow, let userId = store.currentUserId else { return false }
        if let aid = idea.authorId { return aid == userId }
        return idea.authorDisplayName == store.currentUserName
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
        .toolbarBackground(Color(white: 0.12), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
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
    
    private func detailContent(idea: Idea) -> some View {
        
        ZStack {
            Color(white: 0.12).ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        categoryTag(categoryId: idea.categoryId)
                        Spacer()
                        Text(idea.timeAgo)
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                    }
                    
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
                    
                    VStack(alignment: .leading, spacing: 8) {
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
                        }
                        TextEditor(text: $completionText)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .focused($focusField)
                        completionVoiceRow
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
                }
                .padding(24)
            }
        }
    }
    
    private var completionHasContent: Bool {
        !completionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || completionRecordedVoiceURL != nil
    }
    
    private var completionVoiceRow: some View {
        HStack(spacing: 12) {
            if completionVoiceRecorder.isRecording {
                Button {
                    completionRecordedVoiceURL = completionVoiceRecorder.stop()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 22))
                        Text("Stop")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                Text("Recording…")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.8))
            } else if completionRecordedVoiceURL != nil {
                Text("Voice recorded")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.9))
                Button {
                    completionRecordedVoiceURL = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    completionVoiceRecorder.requestPermission { granted in
                        guard granted else { return }
                        _ = try? completionVoiceRecorder.start()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                        Text("Record voice")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Color.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        if let url = voiceURL {
            Task {
                do {
                    let path = try await store.uploadVoiceForContribution(ideaId: ideaId, fileURL: url)
                    await MainActor.run {
                        store.addContribution(ideaId: ideaId, content: trimmed.isEmpty ? "Voice reply" : trimmed, isPublic: completionIsPublic, voicePath: path)
                        completionRecordedVoiceURL = nil
                        completionText = ""
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
    var onToggleComments: () -> Void
    var onSubmitComment: (String, URL?) -> Void
    @State private var commentDraft = ""
    @State private var commentVoiceURL: URL?
    @State private var showStickerPicker = false
    @State private var commentIdShowingStickerPicker: UUID?
    @StateObject private var commentVoiceRecorder = VoiceRecorder()
    @StateObject private var editVoiceRecorder = VoiceRecorder()
    @State private var showDeleteContribConfirm = false
    @State private var showEditContrib = false
    @State private var editContribDraft = ""
    @State private var editContribVoiceURL: URL?
    
    private var canEditContrib: Bool { store.canCurrentUserEditContribution(contribution) }
    
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
                        Text("— \(contribution.authorDisplayName)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75))
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
                }
                Spacer()
                if canEditContrib {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteContribConfirm = true
                        } label: { Label("Delete", systemImage: "trash") }
                        Button {
                            editContribDraft = contribution.content
                            editContribVoiceURL = nil
                            showEditContrib = true
                        } label: { Label("Edit", systemImage: "pencil") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if contribution.isPublic {
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
        .sheet(isPresented: $showEditContrib) {
            editContributionSheet
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
                        Text("— \(comment.authorDisplayName)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
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
            resolvedURL = await store.attachmentURL(ideaId: ideaId, attachment: attachment)
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

#Preview {
    NavigationStack {
        IdeaDetailView(ideaId: UUID())
            .environmentObject(IdeaStore())
    }
}

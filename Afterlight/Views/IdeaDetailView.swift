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
    @State private var expandedCommentContributionId: UUID?
    @FocusState private var focusField: Bool
    
    private var ideaToShow: Idea? {
        store.idea(byId: ideaId)
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
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
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
                    
                    if !idea.attachments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attachments")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                            ForEach(idea.attachments) { att in
                                AttachmentRowView(
                                    attachment: att,
                                    fileURL: store.fileURL(ideaId: idea.id, attachment: att)
                                )
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
                                    onSubmitComment: { draft in
                                        store.addComment(ideaId: idea.id, contributionId: c.id, content: draft)
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
                            .frame(minHeight: 120)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .focused($focusField)
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
                    .disabled(completionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(completionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                    
                    Color.clear.frame(height: 40)
                }
                .padding(24)
            }
        }
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
        guard !trimmed.isEmpty else { return }
        store.addContribution(ideaId: ideaId, content: trimmed, isPublic: completionIsPublic)
        showSubmitted = true
    }
}

// MARK: - Completion row with like, share, comments
struct CompletionRowView: View {
    @EnvironmentObject var store: IdeaStore
    let ideaId: UUID
    let contribution: Contribution
    let isCommentExpanded: Bool
    var onToggleComments: () -> Void
    var onSubmitComment: (String) -> Void
    @State private var commentDraft = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(contribution.content)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text("— \(contribution.authorDisplayName)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75))
                        if !contribution.isPublic {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                Spacer()
            }
            
            if contribution.isPublic {
                HStack(spacing: 16) {
                    Button {
                        store.toggleLikeContribution(ideaId: ideaId, contributionId: contribution.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: store.didCurrentUserLike(contribution: contribution) ? "heart.fill" : "heart")
                                .foregroundStyle(store.didCurrentUserLike(contribution: contribution) ? .red : .white.opacity(0.8))
                            if contribution.likeCount > 0 {
                                Text("\(contribution.likeCount)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    ShareLink(item: contribution.content) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    
                    Button(action: onToggleComments) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .foregroundStyle(.white.opacity(0.8))
                            Text("\(contribution.comments.count)")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if isCommentExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(contribution.comments) { comment in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(comment.content)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.95))
                                Text("— \(comment.authorDisplayName)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        HStack(spacing: 8) {
                            TextField("Add a comment...", text: $commentDraft)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Button("Post") {
                                let text = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty {
                                    onSubmitComment(text)
                                    commentDraft = ""
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AttachmentRowView: View {
    let attachment: Attachment
    let fileURL: URL
    @State private var previewItem: IdentifiableURL?
    
    var body: some View {
        Button {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                previewItem = IdentifiableURL(url: fileURL)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: attachment.kind.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(attachment.displayName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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

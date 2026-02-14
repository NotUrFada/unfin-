//
//  CreateIdeaView.swift
//  Unfin
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

private struct ImageFile: Transferable {
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
    @State private var isPosting = false
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingFiles: [PendingFile] = []
    @State private var showFileImporter = false
    
    private var hasContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.12).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        categorySection
                        ideaSection
                        attachmentsSection
                        hintText
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.12), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            .alert("Idea posted", isPresented: $showAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your idea is now in the feed. Others can complete it.")
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
                }
            }
        }
    }
    
    private var ideaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your idea")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            TextEditor(text: $content)
                .font(.system(size: 16))
                .foregroundStyle(Color.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .padding(16)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
    }
    
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachments")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            
            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Photos", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    showFileImporter = true
                } label: {
                    Label("Files", systemImage: "doc.badge.plus")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
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
        let ideaId = UUID()
        let dir = store.attachmentsDirectory(for: ideaId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var attachments: [Attachment] = []
        
        Task {
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
                let idea = Idea(
                    id: ideaId,
                    categoryId: selectedCategoryId,
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    authorDisplayName: store.currentUserName,
                    attachments: attachments
                )
                store.addIdea(idea)
                isPosting = false
                showAlert = true
            }
        }
    }
}

#Preview {
    CreateIdeaView()
        .environmentObject(IdeaStore())
}

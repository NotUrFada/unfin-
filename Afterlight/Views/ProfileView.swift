//
//  ProfileView.swift
//  Unfin
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showCreateIdea: Bool
    @State private var displayName: String = ""
    @State private var editingName = false

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }
    private var secondaryFg: Color { isLight ? Color(white: 0.4) : Color.white.opacity(0.9) }
    
    private var myIdeas: [Idea] {
        guard let userId = store.currentUserId else { return [] }
        return store.ideas.filter { idea in
            if let aid = idea.authorId { return aid == userId }
            return idea.authorDisplayName == store.currentUserName
        }
    }

    private var myContributionsCount: Int {
        guard let userId = store.currentUserId else { return 0 }
        return store.ideas.flatMap(\.contributions).filter { c in
            if let cid = c.authorId { return cid == userId }
            return c.authorDisplayName == store.currentUserName
        }.count
    }

    /// (Contribution, parent Idea) for current user's contributions, for listing.
    private var myContributionsWithIdeas: [(contribution: Contribution, idea: Idea)] {
        guard let userId = store.currentUserId else { return [] }
        return store.ideas.flatMap { idea in
            idea.contributions.compactMap { c -> (Contribution, Idea)? in
                let isMine = c.authorId == userId || c.authorDisplayName == store.currentUserName
                return isMine ? (c, idea) : nil
            }
        }
    }

    enum ProfileSegment { case ideas, contributions }
    @State private var selectedProfileSegment: ProfileSegment = .ideas
    @State private var profilePath = NavigationPath()
    @State private var showChangeAura = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $profilePath) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    BackgroundGradientView()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            header
                            if selectedProfileSegment == .ideas {
                                myIdeasSection
                            } else {
                                myContributionsSection
                            }
                        }
                    }
                }
                
                addButton
            }
            .navigationDestination(for: UUID.self) { id in
                IdeaDetailView(ideaId: id, onOpenUserProfile: { name, authorId in
                    profilePath.append(UserProfileDestination(displayName: name, authorId: authorId))
                })
            }
            .navigationDestination(for: UserProfileDestination.self) { dest in
                UserProfileView(displayName: dest.displayName, authorId: dest.authorId) { ideaId in
                    profilePath.append(ideaId)
                }
                .environmentObject(store)
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showChangeAura) {
            ChangeAuraView(initialVariant: store.currentAccount?.auraVariant ?? 0)
                .environmentObject(store)
        }
        .onAppear {
            displayName = store.currentUserName
            store.refreshUserProfileIfNeeded()
        }
    }
    
    private var addButton: some View {
        Button {
            showCreateIdea = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(isLight ? Color.white : Color(white: 0.1))
                .frame(width: 56, height: 56)
                .background(isLight ? Color(white: 0.12) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 100)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundStyle(primaryFg)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            
            if editingName {
                HStack {
                    TextField("Display name", text: $displayName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(primaryFg)
                        .padding(12)
                        .background(primaryFg.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("Save") {
                        let name = displayName.isEmpty ? "Anonymous" : displayName
                        if store.isLoggedIn {
                            store.updateAccountDisplayName(name)
                        } else {
                            store.currentUserName = name
                        }
                        editingName = false
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(primaryFg)
                }
                .padding(.horizontal, 24)
            } else {
                HStack(spacing: 14) {
                    Button {
                        showChangeAura = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            AuraAvatarView(
                                size: 52,
                                auraVariant: store.currentAccount?.auraVariant,
                                legacyPaletteIndex: store.currentAccount?.auraPaletteIndex,
                                fallbackDisplayName: store.currentUserName
                            )
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(isLight ? Color(white: 0.12) : .white)
                                .background(Circle().fill(isLight ? Color.white.opacity(0.8) : Color(white: 0.2)))
                                .offset(x: 4, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.currentUserName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(primaryFg)
                        Button {
                            editingName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundStyle(secondaryFg)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            }

            profileStats(
                ideasCount: myIdeas.count,
                contributionsCount: myContributionsCount,
                selectedSegment: $selectedProfileSegment,
                averageContributionRating: store.averageRatingForUser(displayName: store.currentUserName, authorId: store.currentUserId),
                averageIdeaRating: store.averageIdeaRatingForUser(displayName: store.currentUserName, authorId: store.currentUserId)
            )
            
            Text(selectedProfileSegment == .ideas ? "Ideas you started" : "Your contributions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondaryFg)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
    }

    private func profileStats(ideasCount: Int, contributionsCount: Int, selectedSegment: Binding<ProfileSegment>, averageContributionRating: Double? = nil, averageIdeaRating: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    selectedSegment.wrappedValue = .ideas
                } label: {
                    HStack(spacing: 6) {
                        Text("\(ideasCount)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(primaryFg)
                        Text("ideas shared")
                            .font(.system(size: 13))
                            .foregroundStyle(secondaryFg)
                    }
                }
                .buttonStyle(.plain)
                Button {
                    selectedSegment.wrappedValue = .contributions
                } label: {
                    HStack(spacing: 6) {
                        Text("\(contributionsCount)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(primaryFg)
                        Text("contributions")
                            .font(.system(size: 13))
                            .foregroundStyle(secondaryFg)
                    }
                }
                .buttonStyle(.plain)
                if store.currentStreak > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                        Text("\(store.currentStreak) day streak")
                            .font(.system(size: 13))
                            .foregroundStyle(secondaryFg)
                    }
                }
            }
            if averageContributionRating != nil || averageIdeaRating != nil {
                HStack(spacing: 20) {
                    if let avg = averageContributionRating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", avg))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(primaryFg)
                            Text("completions")
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryFg)
                        }
                    }
                    if let avg = averageIdeaRating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", avg))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(primaryFg)
                            Text("ideas")
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryFg)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    private var myIdeasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if myIdeas.isEmpty {
                Text("You haven’t posted any ideas yet. Tap + to share one.")
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryFg)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(primaryFg.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
            } else {
                ForEach(myIdeas) { idea in
                    IdeaCardView(idea: idea, onOpenUserProfile: { name, authorId in
                        profilePath.append(UserProfileDestination(displayName: name, authorId: authorId))
                    }) {
                        profilePath.append(idea.id)
                    }
                }
                .padding(.horizontal, 24)
            }
            Color.clear.frame(height: 120)
        }
    }

    private var myContributionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if myContributionsWithIdeas.isEmpty {
                Text("You haven’t added any completions yet. Open an idea and add yours.")
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryFg)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(primaryFg.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
            } else {
                ForEach(Array(myContributionsWithIdeas.enumerated()), id: \.element.contribution.id) { _, pair in
                    Button {
                        profilePath.append(pair.idea.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            let preview = pair.contribution.content.isEmpty ? "Voice or attachment" : String(pair.contribution.content.prefix(120))
                            let previewText = preview.count == 120 ? preview + "…" : preview
                            Text(previewText)
                                .font(.system(size: 15))
                                .foregroundStyle(primaryFg)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text("Added to: \(String(pair.idea.content.prefix(60)))\(pair.idea.content.count > 60 ? "…" : "")")
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryFg)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(primaryFg.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }
            Color.clear.frame(height: 120)
        }
    }
}


#Preview {
    ProfileView(showCreateIdea: .constant(false))
        .environmentObject(IdeaStore())
}

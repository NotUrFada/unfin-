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
                            myIdeasSection
                        }
                    }
                }
                
                addButton
            }
            .navigationDestination(for: UUID.self) { id in
                IdeaDetailView(ideaId: id)
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
                                legacyPaletteIndex: store.currentAccount?.auraPaletteIndex
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
                        if store.currentStreak > 0 {
                            HStack(spacing: 5) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.orange)
                                Text("\(store.currentStreak) day streak")
                                    .font(.system(size: 14))
                                    .foregroundStyle(secondaryFg)
                            }
                        }
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
            
            Text("Ideas you started")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondaryFg)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
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
                    IdeaCardView(idea: idea) {
                        profilePath.append(idea.id)
                    }
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

//
//  ProfileView.swift
//  Unfin
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: IdeaStore
    @Binding var showCreateIdea: Bool
    @State private var displayName: String = ""
    @State private var editingName = false
    
    private var myIdeas: [Idea] {
        store.ideas.filter { $0.authorDisplayName == store.currentUserName }
    }
    
    @State private var profilePath = NavigationPath()
    
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
            .navigationDestination(for: ProfileDest.self) { dest in
                if case .settings = dest {
                    SettingsView()
                }
            }
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
                .foregroundStyle(Color(white: 0.1))
                .frame(width: 56, height: 56)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 100)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                Text("UNFIN")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    profilePath.append(ProfileDest.settings)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            
            if editingName {
                HStack {
                    TextField("Display name", text: $displayName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
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
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
            } else {
                HStack(spacing: 14) {
                    AuraAvatarView(
                        size: 52,
                        auraVariant: store.currentAccount?.auraVariant,
                        legacyPaletteIndex: store.currentAccount?.auraPaletteIndex
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.currentUserName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                        Button {
                            editingName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            
            Text("Ideas you started")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
    }
    
    private var myIdeasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if myIdeas.isEmpty {
                Text("You haven’t posted any ideas yet. Tap + to share one.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
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

private enum ProfileDest: Hashable {
    case settings
}

#Preview {
    ProfileView(showCreateIdea: .constant(false))
        .environmentObject(IdeaStore())
}

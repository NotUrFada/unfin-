//
//  SettingsView.swift
//  Unfin
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryVerb = "Complete"
    
    private var customCategories: [Category] {
        store.categories.filter { !$0.isSystem }
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.12).ignoresSafeArea()
            
            List {
                Section {
                    HStack(spacing: 14) {
                        AuraAvatarView(
                            size: 44,
                            auraVariant: store.currentAccount?.auraVariant,
                            legacyPaletteIndex: store.currentAccount?.auraPaletteIndex
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Display name")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(store.currentUserName)
                                .font(.body)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                    .foregroundStyle(.white)
                    Button {
                        store.logout()
                        dismiss()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.orange)
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                } header: {
                    Text("Account").foregroundStyle(.white.opacity(0.8))
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete my account", systemImage: "person.crop.circle.badge.minus")
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                } header: {
                    Text("Danger zone").foregroundStyle(.white.opacity(0.8))
                } footer: {
                    Text("This will remove all ideas you’ve posted and reset your name. Ideas you’ve contributed to will keep your past display name.")
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Section {
                    ForEach(customCategories) { cat in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.displayName)
                                    .font(.body)
                                Text("Action: \"\(cat.actionVerb)\"")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                store.removeCategory(id: cat.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                        .foregroundStyle(.white)
                    }
                    Button {
                        newCategoryName = ""
                        newCategoryVerb = "Complete"
                        showAddCategory = true
                    } label: {
                        Label("Add category", systemImage: "plus.circle.fill")
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                    .foregroundStyle(.white)
                } header: {
                    Text("Categories").foregroundStyle(.white.opacity(0.8))
                } footer: {
                    Text("Add custom categories for your ideas. Built-in categories can’t be removed.")
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                    .foregroundStyle(.white)
                } header: {
                    Text("About").foregroundStyle(.white.opacity(0.8))
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(white: 0.12), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
        .alert("Delete account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteAccount()
                dismiss()
            }
        } message: {
            Text("All ideas you posted will be removed and your display name will reset to Anonymous. This can’t be undone.")
        }
        .sheet(isPresented: $showAddCategory) {
            addCategorySheet
        }
    }
    
    private var addCategorySheet: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.12).ignoresSafeArea()
                Form {
                    TextField("Category name", text: $newCategoryName)
                        .foregroundStyle(.white)
                    TextField("Action verb (e.g. Complete, Write)", text: $newCategoryVerb)
                        .foregroundStyle(.white)
                }
                .scrollContentBackground(.hidden)
                .onAppear { newCategoryVerb = "Complete" }
            }
            .navigationTitle("New category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.12), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddCategory = false }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let verb = newCategoryVerb.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            store.addCategory(displayName: name, actionVerb: verb.isEmpty ? "Complete" : verb)
                            showAddCategory = false
                        }
                    }
                    .foregroundStyle(.white)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(IdeaStore())
    }
}

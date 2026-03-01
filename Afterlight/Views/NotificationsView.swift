//
//  NotificationsView.swift
//  Unfin
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.dismiss) private var dismiss
    var onSelectIdea: ((UUID) -> Void)?
    
    private var list: [AppNotification] {
        store.notificationsForCurrentUser
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()
                Group {
                if list.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("No notifications yet")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if list.contains(where: { !$0.isRead }) {
                            Button("Mark all as read") {
                                store.markAllNotificationsRead()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .listRowBackground(Color.white.opacity(0.08))
                        }
                        ForEach(list) { n in
                            Button {
                                store.markNotificationRead(id: n.id)
                                onSelectIdea?(n.ideaId)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: n.iconName)
                                        .font(.system(size: 18))
                                        .foregroundStyle(n.isRead ? .white.opacity(0.5) : .white)
                                        .frame(width: 28, alignment: .center)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(n.summaryText)
                                            .font(.system(size: 15, weight: n.isRead ? .regular : .medium))
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.leading)
                                        Text(n.createdAt, style: .relative)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(n.isRead ? Color.white.opacity(0.08).opacity(0.7) : Color.white.opacity(0.08))
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    NotificationsView()
        .environmentObject(IdeaStore())
}

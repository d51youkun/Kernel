// SidebarView.swift
// 会話一覧 (ピン留め / 日付グループ / アーカイブ)

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var modelManager: ModelManager
    @State private var renamingConversation: Conversation?
    @State private var renameText = ""

    var body: some View {
        List {
            // 新しいチャット
            Button {
                chatVM.newConversation(modelId: modelManager.selectedModel?.id)
            } label: {
                Label("新しいチャット", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            // 検索
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("会話を検索", text: $chatVM.searchQuery)
            }

            if !chatVM.visibleConversations.isEmpty {
                ForEach(groups, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.items) { conv in
                            row(conv)
                        }
                    }
                }
            }

            if !chatVM.archivedConversations.isEmpty {
                Section("アーカイブ") {
                    ForEach(chatVM.archivedConversations) { conv in
                        row(conv)
                    }
                }
            }

            if chatVM.visibleConversations.isEmpty && chatVM.archivedConversations.isEmpty {
                Text("会話はまだありません")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .alert("会話名を変更", isPresented: Binding(
            get: { renamingConversation != nil },
            set: { if !$0 { renamingConversation = nil } })) {
            TextField("タイトル", text: $renameText)
            Button("保存") {
                if let conv = renamingConversation {
                    chatVM.renameConversation(conv, to: renameText)
                }
                renamingConversation = nil
            }
            Button("キャンセル", role: .cancel) { renamingConversation = nil }
        }
    }

    // ── 行 ─────────────────────────────────────

    private func row(_ conv: Conversation) -> some View {
        Button {
            chatVM.selectConversation(conv)
        } label: {
            HStack {
                if conv.isPinned {
                    Image(systemName: "pin.fill").font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(conv.title).lineLimit(1)
                    Text("\(conv.messages.count) メッセージ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listRowBackground(
            chatVM.currentConversation?.id == conv.id
                ? ThemeEngine.selectedRow : nil
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                chatVM.deleteConversation(conv)
            } label: { Label("削除", systemImage: "trash") }

            if conv.isArchived {
                Button {
                    chatVM.unarchiveConversation(conv)
                } label: { Label("戻す", systemImage: "tray.and.arrow.up") }
            } else {
                Button {
                    chatVM.archiveConversation(conv)
                } label: { Label("アーカイブ", systemImage: "archivebox") }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                chatVM.togglePin(conv)
            } label: {
                Label(conv.isPinned ? "ピン解除" : "ピン留め",
                      systemImage: conv.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)

            Button {
                renamingConversation = conv
                renameText = conv.title
            } label: { Label("名前変更", systemImage: "pencil") }
        }
    }

    // ── 日付グループ化 ─────────────────────────

    private struct Group {
        let label: String
        let items: [Conversation]
    }

    private var groups: [Group] {
        let calendar = Calendar.current
        let sorted = chatVM.visibleConversations

        var pinned: [Conversation] = []
        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var previous7Days: [Conversation] = []
        var older: [Conversation] = []

        for conv in sorted {
            if conv.isPinned {
                pinned.append(conv)
            } else if calendar.isDateInToday(conv.updatedAt) {
                today.append(conv)
            } else if calendar.isDateInYesterday(conv.updatedAt) {
                yesterday.append(conv)
            } else if let days = calendar.dateComponents([.day],
                                                         from: calendar.startOfDay(for: conv.updatedAt),
                                                         to: calendar.startOfDay(for: Date())).day,
                      days < 7 {
                previous7Days.append(conv)
            } else {
                older.append(conv)
            }
        }

        var result: [Group] = []
        if !pinned.isEmpty { result.append(Group(label: "ピン留め", items: pinned)) }
        if !today.isEmpty { result.append(Group(label: "今日", items: today)) }
        if !yesterday.isEmpty { result.append(Group(label: "昨日", items: yesterday)) }
        if !previous7Days.isEmpty { result.append(Group(label: "過去7日間", items: previous7Days)) }
        if !older.isEmpty { result.append(Group(label: "それ以前", items: older)) }
        return result
    }
}

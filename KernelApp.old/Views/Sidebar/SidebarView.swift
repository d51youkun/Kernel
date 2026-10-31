// SidebarView.swift
// テーマ対応左サイドバー（Magic Keyboard: Cmd+F で検索フォーカス）

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var chatVM: ChatViewModel
    @Binding var showSettings: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.themeTokens) var tokens

    @State private var showSearch = false
    @State private var showRenameAlert = false
    @State private var renamingConv: Conversation?
    @State private var renameText = ""
    @FocusState private var searchFocused: Bool

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { chatVM.currentConversation?.id },
            set: { id in
                if let id, let c = chatVM.conversations.first(where: { $0.id == id }) {
                    chatVM.selectConversation(c)
                }
            }
        )
    }

    var body: some View {
        ZStack {
            tokens.sidebarBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── ヘッダー ──
                sidebarHeader

                // ── 検索バー ──
                if showSearch { searchBar }

                // ── モデルセレクター ──
                modelSelector
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider().background(tokens.separator)

                // ── 新規チャット ──
                newChatButton

                Divider().background(tokens.separator)

                // ── 会話リスト ──
                conversationList

                Divider().background(tokens.separator)

                // ── フッター ──
                sidebarFooter
            }
        }
        .navigationTitle("Kernel")
        .navigationBarTitleDisplayMode(.large)
        .alert("Rename", isPresented: $showRenameAlert) {
            TextField("Title", text: $renameText).autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let c = renamingConv, !renameText.isEmpty {
                    chatVM.renameConversation(c, to: renameText)
                }
            }
        } message: { Text("会話のタイトルを変更") }
        // Cmd+F: 検索
        .background(
            Button("") { withAnimation { showSearch.toggle() }; searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
        )
    }

    // ── ヘッダー ─────────────────────────────────────

    private var sidebarHeader: some View {
        HStack {
            Text("Kernel")
                .font(.title2.bold())
                .foregroundStyle(tokens.textPrimary)
            Spacer()
            Button {
                withAnimation { showSearch.toggle() }
                if showSearch { searchFocused = true }
            } label: {
                Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                    .foregroundStyle(tokens.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // ── 検索バー ──────────────────────────────────────

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(tokens.textSecondary)
                .font(.callout)
            TextField("Search conversations", text: $chatVM.searchQuery)
                .font(.callout)
                .foregroundStyle(tokens.textPrimary)
                .tint(settings.accentColor.color)
                .focused($searchFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // ── モデルセレクター ──────────────────────────────

    @ViewBuilder
    private var modelSelector: some View {
        if modelManager.models.isEmpty {
            Button { showSettings = true } label: {
                HStack {
                    Image(systemName: "cpu").foregroundStyle(tokens.textSecondary)
                    Text("モデルを追加").foregroundStyle(tokens.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(tokens.textSecondary)
                }
            }
            .buttonStyle(.plain)
        } else {
            Menu {
                ForEach(modelManager.models) { m in
                    Button {
                        withAnimation { modelManager.selectedModel = m }
                    } label: {
                        Label(
                            m.displayName,
                            systemImage: modelManager.selectedModel?.id == m.id
                                ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
                Divider()
                Button("Manage Models…") { showSettings = true }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(settings.accentColor.color.opacity(0.2))
                            .frame(width: 26, height: 26)
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(settings.accentColor.color)
                    }
                    Text(modelManager.selectedModel?.displayName ?? "Select Model")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(tokens.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(tokens.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // ── 新規チャット ──────────────────────────────────

    private var newChatButton: some View {
        Button {
            chatVM.newConversation(modelId: modelManager.selectedModel?.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.callout)
                    .foregroundStyle(settings.accentColor.color)
                Text("New Chat")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(tokens.textPrimary)
                Spacer()
                Text("⌘N")
                    .font(.caption2)
                    .foregroundStyle(tokens.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // ── 会話リスト（日付グループ化） ─────────────────────

    private var conversationList: some View {
        List(selection: selectionBinding) {
            ForEach(chatVM.conversationsByDate, id: \.0) { section in
                Section {
                    ForEach(section.1) { conv in
                        ConversationRowView(
                            conversation: conv,
                            isSelected: chatVM.currentConversation?.id == conv.id,
                            tokens: tokens,
                            accentColor: settings.accentColor.color
                        )
                        .tag(conv.id)
                        .listRowBackground(
                            chatVM.currentConversation?.id == conv.id
                                ? settings.accentColor.color.opacity(0.15)
                                : Color.clear
                        )
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation { chatVM.deleteConversation(conv) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                chatVM.togglePin(conv)
                            } label: {
                                Label(conv.isPinned ? "Unpin" : "Pin",
                                      systemImage: conv.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(.orange)

                            Button {
                                renamingConv = conv
                                renameText   = conv.title
                                showRenameAlert = true
                            } label: { Label("Rename", systemImage: "pencil") }
                            .tint(.blue)
                            
                            Button {
                                chatVM.archiveConversation(conv)
                            } label: { Label("Archive", systemImage: "archivebox") }
                            .tint(.gray)
                        }
                    }
                } header: {
                    Text(section.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tokens.textSecondary)
                        .textCase(.uppercase)
                }
            }
            
            // アーカイブセクション
            if !chatVM.archivedConversations.isEmpty {
                Section {
                    ForEach(chatVM.archivedConversations) { conv in
                        ConversationRowView(
                            conversation: conv,
                            isSelected: chatVM.currentConversation?.id == conv.id,
                            tokens: tokens,
                            accentColor: settings.accentColor.color
                        )
                        .tag(conv.id)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                        .swipeActions(edge: .leading) {
                            Button {
                                chatVM.unarchiveConversation(conv)
                            } label: { Label("Unarchive", systemImage: "tray.and.arrow.up") }
                            .tint(.blue)
                        }
                    }
                } header: {
                    Text("アーカイブ")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tokens.textSecondary)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // ── フッター ──────────────────────────────────────

    private var sidebarFooter: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.callout)
                    .foregroundStyle(tokens.textSecondary)
                Text("Settings")
                    .font(.callout)
                    .foregroundStyle(tokens.textPrimary)
                Spacer()
                Text("⌘,")
                    .font(.caption2)
                    .foregroundStyle(tokens.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// ── 会話行 ────────────────────────────────────────────

struct ConversationRowView: View {
    let conversation: Conversation
    let isSelected: Bool
    let tokens: ThemeTokens
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            if conversation.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(accentColor.opacity(0.8))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? tokens.textPrimary : tokens.textPrimary.opacity(0.85))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(tokens.textSecondary)
                    if let last = conversation.messages.last(where: { $0.role != .system }) {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(tokens.textSecondary)
                        Text(last.content)
                            .font(.caption2)
                            .foregroundStyle(tokens.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
    }
}

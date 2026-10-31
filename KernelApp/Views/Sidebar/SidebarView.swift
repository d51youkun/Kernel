import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var chatVM: ChatViewModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var jitService: JITService

    @State private var showingArchive = false
    @State private var showingSettings = false
    @State private var showingJITSettings = false

    var body: some View {
        ZStack {
            ThemeEngine.sidebarBackgroundColor(for: settings.theme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Search
                searchBar

                // Conversation List
                if showingArchive {
                    archiveList
                } else {
                    conversationList
                }

                Spacer()

                // Footer
                footerView
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingJITSettings) {
            JITSettingsView()
        }
    }

    private var headerView: some View {
        HStack {
            Text("Kernel")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ThemeEngine.textColor(for: settings.theme))

            Spacer()

            Button(action: { chatVM.newConversation(modelId: nil) }) {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(settings.accentColor.color)
            }
        }
        .padding(16)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ThemeEngine.secondaryTextColor(for: settings.theme))

            TextField("検索...", text: $chatVM.searchQuery)
                .textFieldStyle(.plain)
                .foregroundColor(ThemeEngine.textColor(for: settings.theme))

            if !chatVM.searchQuery.isEmpty {
                Button(action: { chatVM.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ThemeEngine.secondaryTextColor(for: settings.theme))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ThemeEngine.messageUserBackgroundColor(for: settings.theme))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(chatVM.conversationsByDate, id: \.0) { group in
                    Section(header: sectionHeader(group.0)) {
                        ForEach(group.1) { conv in
                            ConversationRow(
                                conversation: conv,
                                isSelected: chatVM.currentConversation?.id == conv.id,
                                accentColor: settings.accentColor.color,
                                theme: settings.theme,
                                onSelect: { chatVM.selectConversation(conv) },
                                onRename: { newName in chatVM.renameConversation(conv, to: newName) },
                                onDelete: { chatVM.deleteConversation(conv) },
                                onTogglePin: { chatVM.togglePin(conv) },
                                onArchive: { chatVM.archiveConversation(conv) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var archiveList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(chatVM.archivedConversations) { conv in
                    ConversationRow(
                        conversation: conv,
                        isSelected: chatVM.currentConversation?.id == conv.id,
                        accentColor: settings.accentColor.color,
                        theme: settings.theme,
                        onSelect: { chatVM.selectConversation(conv) },
                        onRename: { newName in chatVM.renameConversation(conv, to: newName) },
                        onDelete: { chatVM.deleteConversation(conv) },
                        onTogglePin: { chatVM.togglePin(conv) },
                        onArchive: { chatVM.unarchiveConversation(conv) }
                    )
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(ThemeEngine.secondaryTextColor(for: settings.theme))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(ThemeEngine.secondaryTextColor(for: settings.theme).opacity(0.3))

            HStack(spacing: 16) {
                Button(action: { showingArchive.toggle() }) {
                    Label(showingArchive ? "会話" : "アーカイブ", systemImage: showingArchive ? "tray" : "archivebox")
                        .foregroundColor(ThemeEngine.textColor(for: settings.theme))
                }

                Spacer()

                Button(action: { showingJITSettings = true }) {
                    Label("JIT", systemImage: jitService.status == .enabled ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundColor(jitService.status == .enabled ? .green : .orange)
                }

                Button(action: { showingSettings = true }) {
                    Label("設定", systemImage: "gearshape")
                        .foregroundColor(ThemeEngine.textColor(for: settings.theme))
                }
            }
            .font(.caption)
            .padding(16)
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let accentColor: Color
    let theme: UITheme
    let onSelect: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onArchive: () -> Void

    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            if conversation.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundColor(accentColor)
                    .font(.caption)
            }

            if isEditing {
                TextField("タイトル", text: $editedTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onSubmit {
                        onRename(editedTitle)
                        isEditing = false
                    }
            } else {
                Text(conversation.title)
                    .font(.body)
                    .foregroundColor(ThemeEngine.textColor(for: theme))
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button(isEditing ? "保存" : "名前を変更") {
                    if isEditing {
                        onRename(editedTitle)
                        isEditing = false
                    } else {
                        editedTitle = conversation.title
                        isEditing = true
                    }
                }

                Button(conversation.isPinned ? "ピン留め解除" : "ピン留め") {
                    onTogglePin()
                }

                Button(conversation.isArchived ? "アーカイブ解除" : "アーカイブ") {
                    onArchive()
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(ThemeEngine.secondaryTextColor(for: theme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onSelect()
            }
        }
        .alert("会話を削除", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("この会話を削除しますか？")
        }
    }
}

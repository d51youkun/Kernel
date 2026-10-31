// SidebarView.swift
// 左サイドバー: モデルセレクター + 会話履歴 + 設定ボタン

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var chatVM: ChatViewModel
    @Binding var showSettings: Bool

    // 選択中会話 ID を Binding として扱う
    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { chatVM.currentConversation?.id },
            set: { id in
                if let id, let conv = chatVM.conversations.first(where: { $0.id == id }) {
                    chatVM.selectConversation(conv)
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── モデルセレクター ──
            modelSelectorSection
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // ── 新規チャットボタン ──
            Button {
                chatVM.newConversation(modelId: modelManager.selectedModel?.id)
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color(.systemBackground).opacity(0.01))

            Divider()

            // ── 会話リスト ──
            List(chatVM.conversations, selection: selectionBinding) { conv in
                ConversationRowView(conversation: conv)
                    .tag(conv.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation { chatVM.deleteConversation(conv) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .listStyle(.sidebar)

            Divider()

            // ── 設定 ──
            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Kernel")
        .navigationBarTitleDisplayMode(.large)
    }

    // ── モデルセレクター ──────────────────────────

    @ViewBuilder
    private var modelSelectorSection: some View {
        if modelManager.models.isEmpty {
            Button {
                showSettings = true
            } label: {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundStyle(.secondary)
                    Text("モデルを追加")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.body)
            }
            .buttonStyle(.plain)
        } else {
            Menu {
                ForEach(modelManager.models) { model in
                    Button {
                        withAnimation { modelManager.selectedModel = model }
                    } label: {
                        Label(
                            model.displayName,
                            systemImage: modelManager.selectedModel?.id == model.id
                                ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
                Divider()
                Button("Manage Models…") { showSettings = true }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cpu.fill")
                        .foregroundStyle(.blue)
                        .font(.body.weight(.semibold))
                    Text(modelManager.selectedModel?.displayName ?? "Select Model")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// ── 会話行 ────────────────────────────────────────

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(conversation.title)
                .font(.body)
                .lineLimit(1)
            Text(conversation.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

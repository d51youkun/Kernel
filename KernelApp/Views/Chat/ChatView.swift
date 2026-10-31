// ChatView.swift
// チャット本体画面

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var modelManager: ModelManager
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let conv = chatVM.currentConversation {
                MessageListView(messages: conv.messages)
            } else {
                emptyState
            }
            InputBarView()
        }
        .background(Color(uiColor: .systemBackground))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .principal) {
                modelMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    chatVM.newConversation(modelId: modelManager.selectedModel?.id)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .alert("エラー", isPresented: Binding(
            get: { chatVM.errorMessage != nil },
            set: { if !$0 { chatVM.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(chatVM.errorMessage ?? "")
        }
    }

    /// モデル選択メニュー
    private var modelMenu: Menu<some View, some View> {
        Menu {
            ForEach(modelManager.models) { model in
                Button {
                    modelManager.selectedModel = model
                } label: {
                    Label(model.displayName,
                          systemImage: modelManager.selectedModel?.id == model.id ? "checkmark" : "circle")
                }
            }
            if modelManager.models.isEmpty {
                Text("設定からGGUFモデルを追加してください")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                Text(modelManager.selectedModel?.displayName ?? "モデル未選択")
                    .lineLimit(1)
            }
            .font(.headline)
        }
    }

    /// 会話がないときの空状態
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Kernel へようこそ")
                .font(.title2.bold())
            Text("ローカルAIとプライベートに会話できます。\n下の入力欄からメッセージを送ってください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if modelManager.models.isEmpty {
                Label("まず設定からモデルを追加しよう", systemImage: "arrow.down.circle")
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// メッセージリスト (自動スクロール付き)
struct MessageListView: View {
    let messages: [Message]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: messages.last?.content.count) { _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

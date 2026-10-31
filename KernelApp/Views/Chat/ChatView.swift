// ChatView.swift
// メインチャット画面: メッセージリスト + 入力バー

import SwiftUI

struct ChatView: View {
    let model: ModelEntry
    @EnvironmentObject var chatVM: ChatViewModel
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // ── メッセージスクロールビュー ──
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let conv = chatVM.currentConversation, !conv.messages.isEmpty {
                            ForEach(conv.messages) { msg in
                                MessageBubbleView(
                                    message: msg,
                                    isLastAndGenerating: isLastGenerating(msg)
                                )
                                .id(msg.id)
                            }
                        } else {
                            WelcomeView(modelName: model.displayName)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 80)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: chatVM.currentConversation?.messages.count) { _ in
                    scrollToBottom()
                }
                .onChange(of: chatVM.currentConversation?.messages.last?.content) { _ in
                    scrollToBottom()
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom()
                }
            }

            // ── エラーバナー ──
            if let err = chatVM.errorMessage {
                errorBanner(err)
            }

            // ── モデルロード中インジケータ ──
            if let name = chatVM.loadingModelName {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading \(name)…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGroupedBackground))
            }

            Divider()

            // ── 入力バー ──
            InputBarView(
                text: $inputText,
                isGenerating: chatVM.isGenerating
            ) {
                Task {
                    let text = inputText
                    inputText = ""
                    await chatVM.sendMessage(text, with: model)
                }
            } onStop: {
                chatVM.stopGeneration()
            }
        }
        .navigationTitle(model.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    chatVM.newConversation(modelId: model.id)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }

    // ── ヘルパー ───────────────────────────────

    private func isLastGenerating(_ msg: Message) -> Bool {
        guard chatVM.isGenerating else { return false }
        return chatVM.currentConversation?.messages.last?.id == msg.id
    }

    private func scrollToBottom() {
        guard let last = chatVM.currentConversation?.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy?.scrollTo(last.id, anchor: .bottom)
        }
    }

    @ViewBuilder
    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(text)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
            Spacer()
            Button { chatVM.errorMessage = nil } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
    }
}

// ChatViewModel.swift
// 会話ロジック・LlamaService 呼び出し・永続化

import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    // ── 状態 ──────────────────────────────────
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isGenerating = false
    @Published var loadingModelName: String?
    @Published var errorMessage: String?

    private let llama = LlamaService.shared

    // 永続化先
    private let storageURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("conversations.json")
    }()

    init() {
        loadFromDisk()
    }

    // ── 会話管理 ──────────────────────────────

    func newConversation(modelId: UUID?) {
        let conv = Conversation(modelId: modelId)
        conversations.insert(conv, at: 0)
        currentConversation = conv
        saveToDisk()
    }

    func selectConversation(_ conv: Conversation) {
        currentConversation = conv
    }

    func deleteConversation(_ conv: Conversation) {
        conversations.removeAll { $0.id == conv.id }
        if currentConversation?.id == conv.id {
            currentConversation = conversations.first
        }
        saveToDisk()
    }

    func clearAllConversations() {
        conversations.removeAll()
        currentConversation = nil
        saveToDisk()
    }

    // ── 送信 ──────────────────────────────────

    func sendMessage(_ text: String, with model: ModelEntry) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }

        errorMessage = nil

        // 会話を確保
        if currentConversation == nil {
            newConversation(modelId: model.id)
        }
        guard var conv = currentConversation else { return }

        // ユーザーメッセージを追加
        let userMsg = Message(role: .user, content: trimmed)
        conv.messages.append(userMsg)
        conv.updatedAt = Date()
        if conv.messages.filter({ $0.role == .user }).count == 1 { conv.autoTitle() }

        // アシスタントメッセージのプレースホルダー
        let assistantPlaceholder = Message(role: .assistant, content: "")
        conv.messages.append(assistantPlaceholder)
        updateCurrent(conv)
        isGenerating = true

        // ── モデルロード ──
        do {
            loadingModelName = model.displayName
            try await llama.loadModel(model)
            loadingModelName = nil
        } catch {
            loadingModelName = nil
            isGenerating = false
            errorMessage = "モデルのロードに失敗しました: \(error.localizedDescription)"
            // プレースホルダーを除去
            if var c = currentConversation {
                c.messages.removeLast()
                updateCurrent(c)
            }
            return
        }

        // ── 生成 ──
        // アシスタントメッセージ以外をすべて渡す
        let msgParams: [[String: String]] = conv.messages.dropLast().map {
            ["role": $0.role.rawValue, "content": $0.content]
        }

        do {
            let stream = llama.generate(messages: msgParams)
            var fullContent = ""
            for try await piece in stream {
                fullContent += piece
                if var c = currentConversation,
                   let lastIdx = c.messages.indices.last {
                    c.messages[lastIdx].content = fullContent
                    updateCurrent(c)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
        saveToDisk()
    }

    func stopGeneration() {
        llama.cancel()
    }

    // ── ヘルパー ────────────────────────────

    private func updateCurrent(_ conv: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[idx] = conv
        }
        currentConversation = conv
    }

    // ── 永続化 ────────────────────────────────

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Conversation].self, from: data) else { return }
        conversations = decoded.sorted { $0.updatedAt > $1.updatedAt }
        currentConversation = conversations.first
    }

    func saveToDisk() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

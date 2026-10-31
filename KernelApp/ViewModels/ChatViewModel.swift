// ChatViewModel.swift
// 会話の管理と AI 生成の制御

import Foundation
import SwiftUI
import AVFoundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isGenerating = false
    @Published var isLoadingModel = false
    @Published var errorMessage: String?
    @Published var searchQuery: String = ""

    private let llama = LlamaService.shared
    private var generationTask: Task<Void, Never>?
    private let synthesizer = AVSpeechSynthesizer()

    private let storageURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("conversations.json")
    }()

    init() { loadFromDisk() }

    // ── 会話管理 ───────────────────────────────

    func newConversation(modelId: UUID?) {
        let conv = Conversation(modelId: modelId)
        conversations.insert(conv, at: 0)
        currentConversation = conv
        saveToDisk()
    }

    func selectConversation(_ conv: Conversation) {
        if currentConversation?.id != conv.id { stopGeneration() }
        currentConversation = conv
    }

    func deleteConversation(_ conv: Conversation) {
        if currentConversation?.id == conv.id { stopGeneration() }
        conversations.removeAll { $0.id == conv.id }
        if currentConversation?.id == conv.id {
            currentConversation = conversations.first
        }
        saveToDisk()
    }

    func renameConversation(_ conv: Conversation, to title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty,
              let idx = conversations.firstIndex(where: { $0.id == conv.id }) else { return }
        conversations[idx].title = t
        if currentConversation?.id == conv.id { currentConversation = conversations[idx] }
        saveToDisk()
    }

    func togglePin(_ conv: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conv.id }) else { return }
        conversations[idx].isPinned.toggle()
        sortConversations()
        if currentConversation?.id == conv.id { currentConversation = conversations[idx] }
        saveToDisk()
    }

    func clearAllConversations() {
        stopGeneration()
        conversations.removeAll()
        currentConversation = nil
        saveToDisk()
    }

    // ── アーカイブ ─────────────────────────────

    func archiveConversation(_ conv: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conv.id }) else { return }
        conversations[idx].isArchived = true
        if currentConversation?.id == conv.id {
            currentConversation = conversations.first(where: { !$0.isArchived })
        }
        saveToDisk()
    }

    func unarchiveConversation(_ conv: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conv.id }) else { return }
        conversations[idx].isArchived = false
        sortConversations()
        saveToDisk()
    }

    /// サイドバーに表示する会話 (検索フィルタ適用・アーカイブ除外)
    var visibleConversations: [Conversation] {
        let base = conversations.filter { !$0.isArchived }
        guard !searchQuery.isEmpty else { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.messages.contains { $0.content.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    var archivedConversations: [Conversation] {
        conversations.filter { $0.isArchived }
    }

    // ── フィードバック ─────────────────────────

    func setFeedback(for messageId: UUID, feedback: Message.Feedback) {
        guard var conv = currentConversation,
              let idx = conv.messages.firstIndex(where: { $0.id == messageId }) else { return }
        // 同じ評価をタップしたら解除 (トグル)
        conv.messages[idx].feedback = conv.messages[idx].feedback == feedback ? .none : feedback
        replaceCurrent(conv)
        saveToDisk()
    }

    // ── トークン統計 ───────────────────────────

    var lastResponseStats: (tokens: Int, seconds: Double, tokensPerSecond: Double)? {
        guard let conv = currentConversation,
              let last = conv.messages.last(where: { $0.role == .assistant }),
              last.tokenCount > 0 else { return nil }
        let tps = last.generationSeconds > 0 ? Double(last.tokenCount) / last.generationSeconds : 0
        return (last.tokenCount, last.generationSeconds, tps)
    }

    // ── 生成 ───────────────────────────────────

    /// メッセージを送信して AI の回答を生成する
    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }

        if currentConversation == nil {
            newConversation(modelId: ModelManager.shared.selectedModel?.id)
        }
        guard var conv = currentConversation else { return }

        guard ModelManager.shared.selectedModel != nil else {
            errorMessage = "モデルが選択されていません。\n設定 → モデル からGGUFファイルをインポートしてください。"
            return
        }

        let userMessage = Message(role: .user, content: trimmed)
        let assistantMessage = Message(role: .assistant, content: "")
        conv.messages.append(userMessage)
        conv.messages.append(assistantMessage)
        if conv.title == "新しいチャット" {
            conv.title = String(trimmed.prefix(30))
        }
        conv.updatedAt = Date()
        currentConversation = conv
        upsert(conv)

        isGenerating = true
        errorMessage = nil

        let assistantId = assistantMessage.id
        // コンテキストを溢れさせないため直近16メッセージだけ送る
        let history = conv.messages.filter { $0.id != assistantId }.suffix(16)
        var tokenCount = 0
        let startedAt = Date()

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                // 1. モデルをロード
                let model = ModelManager.shared.selectedModel!
                self.isLoadingModel = true
                try await self.llama.loadModel(model)
                self.isLoadingModel = false

                // 2. システムプロンプト (日本語強制)
                var messages: [[String: String]] = []
                if AppSettings.shared.forceJapanese {
                    messages.append(["role": "system",
                                     "content": "あなたは親切な日本語アシスタントです。どんな質問にも必ず日本語だけで答えてください。"])
                }
                for m in history where m.role != .system {
                    messages.append(["role": m.role.rawValue, "content": m.content])
                }

                // 3. ストリーミング生成
                let s = AppSettings.shared
                let params = InferenceParams(temperature: Float(s.temperature),
                                             topK: Int32(s.topK),
                                             topP: Float(s.topP),
                                             maxNewTokens: Int32(s.maxNewTokens))
                let stream = self.llama.generate(messages: messages, params: params)
                for try await piece in stream {
                    tokenCount += 1
                    self.appendToMessage(id: assistantId, piece)
                }

                // 4. 統計を記録
                let elapsed = Date().timeIntervalSince(startedAt)
                self.finalizeMessage(id: assistantId, tokenCount: tokenCount, seconds: elapsed)
                if AppSettings.shared.speakResponses {
                    self.speakMessage(id: assistantId)
                }
            } catch is CancellationError {
                // 停止ボタンによる中断: ここまでの内容を確定する
                let elapsed = Date().timeIntervalSince(startedAt)
                self.finalizeMessage(id: assistantId, tokenCount: tokenCount, seconds: elapsed)
            } catch {
                self.errorMessage = error.localizedDescription
                self.removeMessage(id: assistantId)
            }
            self.isLoadingModel = false
            self.isGenerating = false
        }
    }

    /// 生成を停止する
    func stopGeneration() {
        generationTask?.cancel()
        llama.cancel()
    }

    // ── 読み上げ (TTS) ─────────────────────────

    func speakMessage(id: UUID) {
        guard let conv = currentConversation,
              let msg = conv.messages.first(where: { $0.id == id }),
              !msg.content.isEmpty else { return }
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: msg.content)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking { synthesizer.stop(at: .immediate) }
    }

    // ── 内部: メッセージ更新 ───────────────────

    private func appendToMessage(id: UUID, _ piece: String) {
        guard var conv = currentConversation,
              let idx = conv.messages.firstIndex(where: { $0.id == id }) else { return }
        conv.messages[idx].content += piece
        conv.updatedAt = Date()
        replaceCurrent(conv)
    }

    private func finalizeMessage(id: UUID, tokenCount: Int, seconds: Double) {
        guard var conv = currentConversation,
              let idx = conv.messages.firstIndex(where: { $0.id == id }) else { return }
        conv.messages[idx].tokenCount = tokenCount
        conv.messages[idx].generationSeconds = seconds
        replaceCurrent(conv)
        saveToDisk()
    }

    private func removeMessage(id: UUID) {
        guard var conv = currentConversation else { return }
        conv.messages.removeAll { $0.id == id }
        replaceCurrent(conv)
        saveToDisk()
    }

    private func replaceCurrent(_ conv: Conversation) {
        currentConversation = conv
        if let idx = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[idx] = conv
        }
    }

    private func upsert(_ conv: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[idx] = conv
        } else {
            conversations.insert(conv, at: 0)
        }
        sortConversations()
        saveToDisk()
    }

    private func sortConversations() {
        conversations.sort { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }

    // ── 永続化 ─────────────────────────────────

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Conversation].self, from: data) else {
            return
        }
        conversations = decoded
        currentConversation = conversations.first(where: { !$0.isArchived })
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

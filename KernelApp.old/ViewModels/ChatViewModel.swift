// ChatViewModel.swift

import Foundation
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isGenerating = false
    @Published var loadingModelName: String?
    @Published var errorMessage: String?
    @Published var searchQuery: String = ""
    /// 生成後の外国語検出警告（nil なら問題なし）
    @Published var foreignLanguageWarning: String?

    private let llama = LlamaService.shared
    private var settingsRef: AppSettings { AppSettings.shared }
    private var tts = AVSpeechSynthesizer()
    // 生成タスク参照（キャンセル用）
    private var generationTask: Task<Void, Never>?

    private let storageURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("conversations.json")
    }()

    private var attachmentsDir: URL {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Attachments")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    init() { loadFromDisk() }

    // ── 会話管理 ────────────────────────────────────

    func newConversation(modelId: UUID?) {
        let conv = Conversation(modelId: modelId)
        conversations.insert(conv, at: 0)
        currentConversation = conv
        saveToDisk()
    }

    func selectConversation(_ conv: Conversation) {
        // 別会話への切り替え時は生成を停止
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
        guard !t.isEmpty, let idx = conversations.firstIndex(where: { $0.id == conv.id }) else { return }
        conversations[idx].title = t
        if currentConversation?.id == conv.id { currentConversation = conversations[idx] }
        saveToDisk()
    }

    func togglePin(_ conv: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conv.id }) else { return }
        conversations[idx].isPinned.toggle()
        if currentConversation?.id == conv.id { currentConversation = conversations[idx] }
        sortConversations()
        saveToDisk()
    }

    func clearAllConversations() {
        stopGeneration()
        conversations.removeAll()
        currentConversation = nil
        saveToDisk()
    }

    // ── アーカイブ ──────────────────────────────────

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

    // ── メッセージフィードバック ────────────────────

    func setFeedback(for messageId: UUID, feedback: Message.Feedback) {
        guard var conv = currentConversation,
              let idx = conv.messages.firstIndex(where: { $0.id == messageId }) else { return }
        // トグル: 同じフィードバックなら解除
        conv.messages[idx].feedback = conv.messages[idx].feedback == feedback ? .none : feedback
        updateCurrent(conv)
        saveToDisk()
    }

    // ── トークン統計 ────────────────────────────────

    /// 最後のアシスタントメッセージの統計情報
    var lastResponseStats: (tokens: Int, duration: Double, tokensPerSec: Double)? {
        guard let conv = currentConversation,
              let last = conv.messages.last(where: { $0.role == .assistant }),
              let duration = last.generationDuration,
              let tokens = last.estimatedTokens, tokens > 0, duration > 0 else { return nil }
        return (tokens, duration, Double(tokens) / duration)
    }

    // ── 検索 ────────────────────────────────────────

    var filteredConversations: [Conversation] {
        let nonArchived = conversations.filter { !$0.isArchived }
        if searchQuery.isEmpty { return nonArchived }
        let q = searchQuery.lowercased()
        return nonArchived.filter {
            $0.title.lowercased().contains(q) ||
            $0.messages.contains { $0.content.lowercased().contains(q) }
        }
    }

    var archivedConversations: [Conversation] {
        let archived = conversations.filter { $0.isArchived }
        if searchQuery.isEmpty { return archived }
        let q = searchQuery.lowercased()
        return archived.filter {
            $0.title.lowercased().contains(q) ||
            $0.messages.contains { $0.content.lowercased().contains(q) }
        }
    }

    /// 会話を日付グループで分類（サイドバー用）
    var conversationsByDate: [(String, [Conversation])] {
        let nonArchived = filteredConversations
        let calendar = Calendar.current
        let now = Date()

        var groups: [(String, [Conversation])] = []
        var pinned: [Conversation] = []
        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var lastWeek: [Conversation] = []
        var lastMonth: [Conversation] = []
        var older: [Conversation] = []

        for conv in nonArchived {
            if conv.isPinned {
                pinned.append(conv)
                continue
            }
            let daysAgo = calendar.dateComponents([.day], from: conv.updatedAt, to: now).day ?? 0
            if daysAgo == 0 { today.append(conv) }
            else if daysAgo == 1 { yesterday.append(conv) }
            else if daysAgo < 7 { lastWeek.append(conv) }
            else if daysAgo < 30 { lastMonth.append(conv) }
            else { older.append(conv) }
        }

        if !pinned.isEmpty { groups.append(("ピン留め", pinned)) }
        if !today.isEmpty { groups.append(("今日", today)) }
        if !yesterday.isEmpty { groups.append(("昨日", yesterday)) }
        if !lastWeek.isEmpty { groups.append(("過去7日間", lastWeek)) }
        if !lastMonth.isEmpty { groups.append(("過去30日間", lastMonth)) }
        if !older.isEmpty { groups.append(("それ以前", older)) }

        return groups
    }

    // ── 添付ファイル ────────────────────────────────

    func importAttachment(from url: URL) throws -> AttachedFile {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let mimeType = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"

        let uniqueName = "\(UUID().uuidString)_\(fileName)"
        let destURL = attachmentsDir.appendingPathComponent(uniqueName)
        try data.write(to: destURL)

        return AttachedFile(
            fileName: fileName,
            mimeType: mimeType,
            size: Int64(data.count),
            relativePath: uniqueName
        )
    }

    // ── メッセージ操作 ──────────────────────────────

    func editAndResend(messageId: UUID, newContent: String, with model: ModelEntry) async {
        guard var conv = currentConversation,
              let idx = conv.messages.firstIndex(where: { $0.id == messageId }) else { return }
        conv.messages.removeSubrange(idx...)
        updateCurrent(conv)
        await sendMessage(newContent, attachments: [], with: model)
    }

    func regenerateLastResponse(with model: ModelEntry) async {
        guard var conv = currentConversation,
              let lastAssistant = conv.messages.last(where: { $0.role == .assistant }),
              let idx = conv.messages.firstIndex(where: { $0.id == lastAssistant.id }) else { return }
        conv.messages.removeSubrange(idx...)
        updateCurrent(conv)
        if let lastUser = conv.messages.last(where: { $0.role == .user }) {
            await sendMessage(lastUser.content, attachments: lastUser.attachments, with: model)
        }
    }

    func speak(_ text: String) {
        tts.stopSpeaking(at: .immediate)
        let utter = AVSpeechUtterance(string: text)
        utter.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utter.rate = 0.52
        tts.speak(utter)
    }

    func stopSpeaking() { tts.stopSpeaking(at: .immediate) }

    // ── 送信 ────────────────────────────────────────

    func sendMessage(_ text: String, attachments: [AttachedFile] = [], with model: ModelEntry) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 添付なし & 空テキストはスキップ
        guard !trimmed.isEmpty || !attachments.isEmpty else { return }
        guard !isGenerating else { return }

        errorMessage = nil
        foreignLanguageWarning = nil

        if currentConversation == nil { newConversation(modelId: model.id) }
        guard var conv = currentConversation else { return }

        // ユーザーメッセージ
        var userMsg = Message(role: .user, content: trimmed)
        userMsg.attachments = attachments
        conv.messages.append(userMsg)
        conv.updatedAt = Date()
        if conv.messages.filter({ $0.role == .user }).count == 1 { conv.autoTitle() }

        // アシスタントプレースホルダー
        conv.messages.append(Message(role: .assistant, content: ""))
        updateCurrent(conv)
        isGenerating = true

        // モデルロード
        do {
            loadingModelName = model.displayName
            try await llama.loadModel(model)
            loadingModelName = nil
        } catch {
            loadingModelName = nil
            isGenerating = false
            errorMessage = "モデルロード失敗: \(error.localizedDescription)"
            if var c = currentConversation { c.messages.removeLast(); updateCurrent(c) }
            return
        }

        // システムプロンプト構築
        // 多層日本語強制：
        //  1. system ロール（ChatML対応モデル用）
        //  2. 最初の user メッセージに埋め込み（system無視モデル用）
        //  3. 各 user メッセージ末尾にリマインダー付加（最強）
        var msgParams: [[String: String]] = []

        let jpInstruction = """
        【最重要ルール — 必ず守ること】
        あなたは必ず日本語で回答するAIアシスタントです。

        絶対に守るべきルール:
        1. 回答はすべて日本語で書くこと。英語・中国語・韓国語などの外国語で回答しないこと。
        2. もし外国語で書き始めてしまったら、すぐに止めて日本語で書き直すこと。
        3. YouTube, Swift, iPhone, GitHub, JavaScript, Python などの固有名詞・技術用語は英語のままで良い。
        4. コードブロック内の変数名・関数名・コメントは英語のままで良い。
        5. コードブロックの外（説明文）は必ず日本語で書くこと。
        6. ユーザーが英語で質問しても、日本語で回答すること。
        7. 「I will...」「Here is...」「The answer is...」などの英語の書き出しは禁止。必ず「以下のように...」「答えは...」など日本語で始めること。

        これらのルールに違反した場合は、回答全体を日本語で書き直してください。
        """

        let userSP = settingsRef.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        if settingsRef.forceJapanese {
            // system ロール（ChatML, Llama-3, Mistral 等に対応）
            let sysBody = [jpInstruction, userSP].filter { !$0.isEmpty }.joined(separator: "\n\n")
            msgParams.append(["role": "system", "content": sysBody])
        } else if !userSP.isEmpty {
            msgParams.append(["role": "system", "content": userSP])
        }

        // メッセージ履歴（添付テキストを末尾に付加）
        let history = (currentConversation?.messages ?? []).dropLast().filter { $0.role != .system }
        var historyParams: [[String: String]] = history.map { msg -> [String: String] in
            var content = msg.content
            for att in msg.attachments {
                if att.mimeType.hasPrefix("text/") || att.isHTML {
                    if let text = try? String(contentsOf: att.fileURL, encoding: .utf8) {
                        content += "\n\n[添付ファイル: \(att.fileName)]\n\(text)"
                    }
                } else {
                    content += "\n[添付ファイル: \(att.fileName) (\(att.humanSize))]"
                }
            }
            return ["role": msg.role.rawValue, "content": content]
        }

        if settingsRef.forceJapanese {
            // user メッセージ全件に日本語リマインダーを付加
            // 最初のメッセージ：指示を先頭に埋め込み（system無視モデル対策）
            // 以降のメッセージ：末尾に短いリマインダー
            let reminder = "\n\n※必ず日本語で回答してください。英語での回答は禁止です。"
            let firstInject = "\(jpInstruction)\n\n"

            for (i, param) in historyParams.enumerated() {
                guard param["role"] == "user" else { continue }
                var content = param["content"] ?? ""
                if i == historyParams.firstIndex(where: { $0["role"] == "user" }) {
                    // 最初の user: 指示を先頭に
                    content = firstInject + content + reminder
                } else {
                    // それ以降の user: 末尾にリマインダー
                    content = content + reminder
                }
                historyParams[i]["content"] = content
            }
        }

        msgParams += historyParams

        // 生成（タスクで管理してキャンセル可能に）
        let convId = conv.id
        generationTask = Task { [weak self] in
            guard let self else { return }
            let genStartTime = Date()
            do {
                let stream = llama.generate(messages: msgParams)
                var fullContent = ""
                for try await piece in stream {
                    if Task.isCancelled { break }
                    fullContent += piece
                    // 現在の会話IDが変わっていたら書き込みしない（別タスク混入防止）
                    guard var c = currentConversation,
                          c.id == convId,
                          let lastIdx = c.messages.indices.last else { continue }
                    c.messages[lastIdx].content = fullContent
                    updateCurrent(c)
                }
                // ── 生成統計を記録 ──
                let genDuration = Date().timeIntervalSince(genStartTime)
                // トークン数の概算: 日本語は約1.5文字/トークン、英語は約4文字/トークン
                let estTokens = Int(Double(fullContent.count) / 2.0)
                if var c = currentConversation, c.id == convId,
                   let lastIdx = c.messages.indices.last,
                   c.messages[lastIdx].role == .assistant {
                    c.messages[lastIdx].generationDuration = genDuration
                    c.messages[lastIdx].estimatedTokens = estTokens
                    updateCurrent(c)
                }
                // ── 生成後の外国語検出 ──
                if settingsRef.forceJapanese, !Task.isCancelled, !fullContent.isEmpty {
                    detectForeignLanguage(in: fullContent)
                }
                if settingsRef.ttsEnabled, let last = currentConversation?.messages.last {
                    speak(last.content)
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = "生成エラー: \(error.localizedDescription)"
                }
            }
            isGenerating = false
            saveToDisk()
        }
        await generationTask?.value
    }

    func stopGeneration() {
        generationTask?.cancel()
        generationTask = nil
        llama.cancel()
        isGenerating = false
    }

    // ── 外国語検出 ────────────────────────────────────

    /// 生成されたテキストが主に外国語（日本語以外）で書かれているか検出する
    private func detectForeignLanguage(in content: String) {
        // コードブロックを除去（コード内は英語で正常）
        let stripped = content.replacingOccurrences(
            of: #"```[\s\S]*?```"#,
            with: " ",
            options: .regularExpression
        ).replacingOccurrences(
            of: #"`[^`]+`"#,
            with: " ",
            options: .regularExpression
        )

        // 各文字種をカウント
        var japaneseCount = 0
        var latinCount = 0
        var totalLetters = 0

        for scalar in stripped.unicodeScalars {
            let v = scalar.value
            // ひらがな U+3040-U+309F
            if v >= 0x3040 && v <= 0x309F { japaneseCount += 1; totalLetters += 1 }
            // カタカナ U+30A0-U+30FF
            else if v >= 0x30A0 && v <= 0x30FF { japaneseCount += 1; totalLetters += 1 }
            // 漢字 U+4E00-U+9FFF, U+3400-U+4DBF
            else if (v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3400 && v <= 0x4DBF) { japaneseCount += 1; totalLetters += 1 }
            // ラテン文字 a-zA-Z
            else if (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) { latinCount += 1; totalLetters += 1 }
        }

        // 文字が少なすぎる場合はスキップ
        guard totalLetters > 20 else { return }

        let jpRatio = Double(japaneseCount) / Double(totalLetters)
        let latinRatio = Double(latinCount) / Double(totalLetters)

        // 日本語が30%未満でラテン文字が50%超 → 外国語の可能性が高い
        if jpRatio < 0.30 && latinRatio > 0.50 {
            foreignLanguageWarning = """
            回答が主に外国語（英語等）で書かれています。
            「再生成」をタップすると日本語で再回答させられます。
            """
        } else {
            foreignLanguageWarning = nil
        }
    }

    /// 最後のアシスタント回答を削除して、より強い日本語強制で再生成する
    func regenerateInJapanese(with model: ModelEntry) async {
        guard var conv = currentConversation,
              let lastAssistant = conv.messages.last(where: { $0.role == .assistant }),
              let idx = conv.messages.firstIndex(where: { $0.id == lastAssistant.id }) else { return }
        conv.messages.removeSubrange(idx...)
        updateCurrent(conv)
        foreignLanguageWarning = nil
        if let lastUser = conv.messages.last(where: { $0.role == .user }) {
            await sendMessage(lastUser.content, attachments: lastUser.attachments, with: model)
        }
    }

    // ── HTML検出・保存 ──────────────────────────────

    /// アシスタントの返答からHTMLを抽出して保存、URLを返す
    func extractAndSaveHTML(from content: String) -> URL? {
        // ```html ... ``` を検出
        guard let re = try? NSRegularExpression(pattern: "```(?:html)?\\s*\\n([\\s\\S]*?)```",
                                                 options: .caseInsensitive),
              let match = re.firstMatch(in: content,
                                        range: NSRange(content.startIndex..., in: content)),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: content) else { return nil }

        let html = String(content[r])
        let fileName = "generated_\(Int(Date().timeIntervalSince1970)).html"
        let url = attachmentsDir.appendingPathComponent(fileName)
        try? html.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // ── ソート ──────────────────────────────────────

    private func sortConversations() {
        conversations.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    func updateCurrent(_ conv: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[idx] = conv
        }
        currentConversation = conv
    }

    // ── 永続化 ──────────────────────────────────────

    func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Conversation].self, from: data) else { return }
        conversations = decoded.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
        currentConversation = conversations.first
    }

    func saveToDisk() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

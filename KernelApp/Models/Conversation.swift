// Conversation.swift
// チャット会話（複数メッセージのコンテナ）

import Foundation

struct Conversation: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String = "New Chat"
    var messages: [Message] = []
    /// 使用したモデルの ID（ModelEntry.id）
    var modelId: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// ピン留め
    var isPinned: Bool = false
    /// アーカイブ済み
    var isArchived: Bool = false

    /// 会話の最初のユーザーメッセージから自動タイトルを生成
    mutating func autoTitle() {
        if let first = messages.first(where: { $0.role == .user }) {
            let raw = first.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first ?? ""
            title = String(raw.prefix(50))
        }
    }

    /// プレーンテキスト形式でエクスポート
    func exportText() -> String {
        messages.filter { $0.role != .system }
            .map { msg in
                let role = msg.role == .user ? "You" : "Kernel"
                let time = msg.timestamp.formatted(date: .abbreviated, time: .shortened)
                return "[\(time)] \(role):\n\(msg.content)"
            }
            .joined(separator: "\n\n---\n\n")
    }
}

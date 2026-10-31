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
}

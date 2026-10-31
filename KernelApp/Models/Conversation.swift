// Conversation.swift

import Foundation

struct Conversation: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = "新しいチャット"
    /// 使用したモデル (ModelEntry.id)
    var modelId: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var messages: [Message] = []
    var isPinned: Bool = false
    var isArchived: Bool = false
}

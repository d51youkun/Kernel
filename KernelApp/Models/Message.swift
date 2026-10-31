// Message.swift
// チャットの1メッセージを表すデータモデル

import Foundation

struct Message: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var role: Role
    var content: String
    var timestamp: Date = Date()

    enum Role: String, Codable, Equatable, CaseIterable {
        case user
        case assistant
        case system
    }
}

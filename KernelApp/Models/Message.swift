// Message.swift

import Foundation

struct Message: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user, assistant, system
    }

    enum Feedback: String, Codable {
        case none, like, dislike
    }

    var id: UUID = UUID()
    var role: Role
    var content: String
    var createdAt: Date = Date()
    var feedback: Feedback = .none
    /// 生成トークン数
    var tokenCount: Int = 0
    /// 生成にかかった秒数
    var generationSeconds: Double = 0
}

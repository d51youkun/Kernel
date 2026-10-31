// Message.swift

import Foundation

// 添付ファイル
struct AttachedFile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var fileName: String
    var mimeType: String
    var size: Int64
    /// Documents/Attachments/ 以下の相対パス
    var relativePath: String

    var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Attachments")
            .appendingPathComponent(relativePath)
    }

    var isHTML: Bool { fileName.lowercased().hasSuffix(".html") || mimeType == "text/html" }
    var isImage: Bool { mimeType.hasPrefix("image/") }

    var displayIcon: String {
        if isHTML  { return "globe" }
        if isImage { return "photo" }
        if mimeType.contains("pdf")   { return "doc.richtext" }
        if mimeType.contains("text")  { return "doc.text" }
        if mimeType.contains("audio") { return "waveform" }
        if mimeType.contains("video") { return "video" }
        return "doc.fill"
    }

    var humanSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct Message: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var role: Role
    var content: String
    var timestamp: Date = Date()
    var isEdited: Bool = false
    var attachments: [AttachedFile] = []
    /// ユーザーのフィードバック（👍👎）
    var feedback: Feedback = .none
    /// 生成にかかった時間（秒）
    var generationDuration: Double?
    /// 生成されたトークン数の概算（文字数ベース）
    var estimatedTokens: Int?

    enum Role: String, Codable, Equatable, CaseIterable {
        case user
        case assistant
        case system
    }

    enum Feedback: String, Codable, Equatable {
        case none
        case thumbsUp
        case thumbsDown
    }
}

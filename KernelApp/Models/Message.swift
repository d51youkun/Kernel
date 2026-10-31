import Foundation

// MARK: - AttachedFile

struct AttachedFile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var fileName: String
    var mimeType: String
    var size: Int64
    var relativePath: String

    var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Attachments")
            .appendingPathComponent(relativePath)
    }

    var isHTML: Bool {
        fileName.lowercased().hasSuffix(".html") || mimeType == "text/html"
    }

    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }

    var displayIcon: String {
        if isHTML { return "globe" }
        if isImage { return "photo" }
        if mimeType.contains("pdf") { return "doc.richtext" }
        if mimeType.contains("text") { return "doc.text" }
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

// MARK: - Message

struct Message: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var role: Role
    var content: String
    var timestamp: Date = Date()
    var isEdited: Bool = false
    var attachments: [AttachedFile] = []
    var feedback: Feedback = .none
    var generationDuration: Double?
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

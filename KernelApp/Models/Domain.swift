import Foundation

struct ModelEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var displayName: String
    var fileName: String
    var fileURL: URL { Storage.models.appendingPathComponent(fileName) }
    var size: Int64 { (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0 }
}

struct Message: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case system, user, assistant }
    var id = UUID()
    var role: Role
    var content: String
    var createdAt = Date()
    var attachments: [Attachment] = []
    var feedback: String? = nil
    var duration: Double? = nil
    var interrupted = false

    // Old messages are migrated without discarding the conversation.
    enum CodingKeys: String, CodingKey { case id, role, content, createdAt, attachments, feedback, duration, interrupted }
    init(role: Role, content: String, attachments: [Attachment] = []) {
        self.role = role; self.content = content; self.attachments = attachments
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        role = try c.decode(Role.self, forKey: .role)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        attachments = try c.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        feedback = try c.decodeIfPresent(String.self, forKey: .feedback)
        duration = try c.decodeIfPresent(Double.self, forKey: .duration)
        interrupted = try c.decodeIfPresent(Bool.self, forKey: .interrupted) ?? false
    }
}

struct Attachment: Identifiable, Codable, Equatable {
    var id = UUID()
    var fileName: String
    var relativePath: String
    var text: String? = nil
    var fileURL: URL { Storage.attachments.appendingPathComponent(relativePath) }
}

struct Conversation: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = "新しいチャット"
    var messages: [Message] = []
    var modelId: UUID? = nil
    var createdAt = Date()
    var updatedAt = Date()
    var isPinned = false
    var isArchived = false
    var project: String? = nil

    enum CodingKeys: String, CodingKey { case id, title, messages, modelId, createdAt, updatedAt, isPinned, isArchived, project }
    init(modelId: UUID? = nil) { self.modelId = modelId }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "新しいチャット"
        messages = try c.decodeIfPresent([Message].self, forKey: .messages) ?? []
        modelId = try c.decodeIfPresent(UUID.self, forKey: .modelId)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        project = try c.decodeIfPresent(String.self, forKey: .project)
    }
}

struct Settings: Codable, Equatable {
    var appearance = "system"
    var systemPrompt = ""
    var temperature = 0.65
    var contextLength = 4096
    var maxTokens = 1024
    var nThreads = min(10, ProcessInfo.processInfo.activeProcessorCount)
    var showMemoryWarning = true  // 大きいモデル読み込み時に警告を表示
    var useMetal = true
    var readAloud = false
    var memory = ""
}

enum Storage {
    static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let models = documents.appendingPathComponent("Models", isDirectory: true)
    static let attachments = documents.appendingPathComponent("Attachments", isDirectory: true)
    static func prepare() throws {
        for url in [models, attachments] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    }
    static func read<T: Decodable>(_ type: T.Type, name: String) throws -> T? {
        let url = documents.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do { return try JSONDecoder().decode(type, from: Data(contentsOf: url)) }
        catch {
            // Keep an untouched recovery copy; never overwrite the only copy after decode failure.
            let backup = documents.appendingPathComponent("\(name).recovery-\(Int(Date().timeIntervalSince1970))")
            try FileManager.default.copyItem(at: url, to: backup)
            throw error
        }
    }
    static func write<T: Encodable>(_ value: T, name: String) throws {
        try JSONEncoder().encode(value).write(to: documents.appendingPathComponent(name), options: .atomic)
    }
}

enum KernelError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

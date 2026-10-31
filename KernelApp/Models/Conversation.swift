import Foundation

struct Conversation: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String = "New Chat"
    var messages: [Message] = []
    var modelId: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPinned: Bool = false
    var isArchived: Bool = false

    mutating func autoTitle() {
        if let first = messages.first(where: { $0.role == .user }) {
            let raw = first.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first ?? ""
            title = String(raw.prefix(50))
        }
    }

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

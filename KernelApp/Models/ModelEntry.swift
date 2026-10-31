// ModelEntry.swift

import Foundation

struct ModelEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    /// 表示名
    var displayName: String
    /// Documents/Models/ 内のファイル名
    var fileName: String
    var addedAt: Date = Date()

    /// GGUF ファイルの実体
    var fileURL: URL {
        ModelManager.shared.modelsDirectory.appendingPathComponent(fileName)
    }
}

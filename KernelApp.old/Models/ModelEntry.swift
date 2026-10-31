// ModelEntry.swift
// Documents/Models/ 以下の GGUF ファイルのメタデータ

import Foundation

struct ModelEntry: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    /// ユーザーが設定した表示名
    var displayName: String
    /// GGUF ファイル名（例: "llama-3.2-3b-q4_k_m.gguf"）
    var fileName: String
    var createdAt: Date = Date()

    /// GGUF ファイルの絶対パス
    var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models")
            .appendingPathComponent(fileName)
    }

    /// ファイルサイズ（バイト）
    var fileSizeBytes: Int64? {
        guard let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attr[.size] as? Int64 else { return nil }
        return size
    }

    /// 人間が読みやすいファイルサイズ
    var fileSizeString: String {
        guard let bytes = fileSizeBytes else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

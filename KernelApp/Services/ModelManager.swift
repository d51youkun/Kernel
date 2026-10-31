// ModelManager.swift
// GGUF ファイルの管理（スキャン・インポート・名前変更・削除）
// Documents/Models/ を管理対象ディレクトリとする

import Foundation
import UniformTypeIdentifiers

@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published var models: [ModelEntry] = []
    @Published var selectedModel: ModelEntry?

    // メタデータ保存先
    private let metaURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("models.json")
    }()

    var modelsDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models")
    }

    private init() {
        try? FileManager.default.createDirectory(at: modelsDirectory,
                                                 withIntermediateDirectories: true)
        loadMetadata()
        scanAndReconcile()
    }

    // ── CRUD ──────────────────────────────────

    /// Files.app から GGUF ファイルをインポートする
    func importModel(from sourceURL: URL) throws {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let destURL = modelsDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        // 既存ファイルは上書きしない
        if FileManager.default.fileExists(atPath: destURL.path) {
            throw CocoaError(.fileWriteFileExists)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let entry = ModelEntry(
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            fileName:    sourceURL.lastPathComponent
        )
        models.append(entry)
        if selectedModel == nil { selectedModel = entry }
        saveMetadata()
    }

    /// 表示名を変更する
    func rename(_ entry: ModelEntry, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = models.firstIndex(where: { $0.id == entry.id }) {
            models[idx].displayName = trimmed
            if selectedModel?.id == entry.id { selectedModel = models[idx] }
            saveMetadata()
        }
    }

    /// モデルとファイルを削除する
    func delete(_ entry: ModelEntry) {
        models.removeAll { $0.id == entry.id }
        try? FileManager.default.removeItem(at: entry.fileURL)
        if selectedModel?.id == entry.id {
            selectedModel = models.first
        }
        saveMetadata()
    }

    // ── スキャン ──────────────────────────────

    /// Documents/Models/ 内の .gguf を走査してメタデータと突き合わせる
    func scanAndReconcile() {
        let contents = (try? FileManager.default
            .contentsOfDirectory(at: modelsDirectory,
                                  includingPropertiesForKeys: nil)) ?? []
        let ggufFiles = contents.filter { $0.pathExtension.lowercased() == "gguf" }

        // 新規発見ファイルを追加
        for file in ggufFiles {
            let fileName = file.lastPathComponent
            if !models.contains(where: { $0.fileName == fileName }) {
                let entry = ModelEntry(
                    displayName: file.deletingPathExtension().lastPathComponent,
                    fileName: fileName
                )
                models.append(entry)
            }
        }

        // ファイルが消えたエントリを除去
        models.removeAll { entry in
            !FileManager.default.fileExists(atPath: entry.fileURL.path)
        }

        if selectedModel == nil || !models.contains(where: { $0.id == selectedModel?.id }) {
            selectedModel = models.first
        }

        saveMetadata()
    }

    // ── 永続化 ────────────────────────────────

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metaURL),
              let decoded = try? JSONDecoder().decode([ModelEntry].self, from: data) else {
            return
        }
        models = decoded
        selectedModel = models.first
    }

    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(models) else { return }
        try? data.write(to: metaURL, options: .atomic)
    }
}

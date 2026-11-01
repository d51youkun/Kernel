import Foundation
import NaturalLanguage

// The bridge serializes all native model/context access and cancellation is atomic.
extension LlamaBridge: @unchecked Sendable {}

@MainActor
final class InferenceEngine {
    private let bridge = LlamaBridge()
    private let loader = DispatchQueue(label: "app.kernel.model-loader", qos: .userInitiated)
    private var loadedID: UUID?
    private var configuration: Settings?

    func load(_ model: ModelEntry, settings: Settings) async throws {
        if loadedID == model.id, configuration?.contextLength == settings.contextLength,
           configuration?.useMetal == settings.useMetal { configure(settings); return }
        let bytes = model.size
        let available = Int64(os_proc_available_memory())
        // ソフト警告: モデルが空きメモリを超える場合でも allowLarge フラグがあれば続行
        // ハードブロック: モデルが空きの2倍以上は物理的に不可能
        if bytes > 0, bytes > available * 2 {
            throw KernelError.message("このモデルは大きすぎます（\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory))）。利用可能メモリ（\(ByteCountFormatter.string(fromByteCount: available, countStyle: .memory))）の2倍を超えています。")
        }
        // 空きメモリを超える場合は警告をステータスに表示して続行（iOSがページング確保する場合がある）
        configure(settings)
        loadedID = nil
        let engine = bridge
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            loader.async {
                do { try engine.loadModel(fromPath: model.fileURL.path); c.resume() }
                catch { c.resume(throwing: error) }
            }
        }
        loadedID = model.id; configuration = settings
    }

    private func configure(_ settings: Settings) {
        bridge.contextLength = Int32(settings.contextLength)
        bridge.maxNewTokens  = Int32(settings.maxTokens)
        bridge.temperature   = Float(settings.temperature)
        bridge.topP          = 0.95
        bridge.topK          = 40
        bridge.nGpuLayers    = settings.useMetal ? 99 : 0
        bridge.nThreads      = Int32(settings.nThreads)   // 最大6コア
    }

    func stream(_ messages: [[String: String]]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            bridge.generate(fromMessages: messages) { piece, done, error in
                if let error { continuation.finish(throwing: error) }
                else if done { continuation.finish() }
                else if let piece { continuation.yield(piece) }
            }
            continuation.onTermination = { [bridge] reason in
                if case .cancelled = reason { bridge.cancelGeneration() }
            }
        }
    }
    func complete(_ messages: [[String: String]]) async throws -> String {
        var result = ""
        for try await piece in stream(messages) { try Task.checkCancellation(); result += piece }
        try Task.checkCancellation()
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func cancel() { bridge.cancelGeneration() }
    func unload() async {
        cancel()
        let engine = bridge
        await withCheckedContinuation { c in loader.async { engine.unloadModel(); c.resume() } }
        loadedID = nil
    }

    static func foreignProse(_ text: String) -> Bool {
        let prose = text.replacingOccurrences(of: #"```[\s\S]*?```|`[^`]*`|https?://\S+"#, with: " ", options: .regularExpression)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(prose)
        let letters = prose.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard letters > 3 else { return false }
        return recognizer.dominantLanguage != .japanese
    }

    func japanese(_ text: String, chunkSize: Int) async throws -> String {
        guard Self.foreignProse(text) else { return text }
        // Keep fenced code byte-for-byte and translate prose in bounded chunks.
        let parts = text.components(separatedBy: "```")
        var translated: [String] = []
        for (index, part) in parts.enumerated() {
            try Task.checkCancellation()
            if index % 2 == 1 { translated.append(part); continue }
            var output: [String] = []
            for chunk in Self.chunks(part, limit: chunkSize) {
                if !Self.foreignProse(chunk) { output.append(chunk); continue }
                var result = ""
                for _ in 0..<2 {
                    result = try await complete([
                        ["role": "system", "content": "あなたは翻訳者です。入力を意味を変えず自然な日本語に翻訳してください。要約や解説を追加しないでください。Markdown、数値、URL、固有名詞は保持してください。訳文のみを返してください。"],
                        ["role": "user", "content": chunk]
                    ])
                    if !Self.foreignProse(result), !result.isEmpty { break }
                }
                guard !result.isEmpty, !Self.foreignProse(result) else {
                    throw KernelError.message("選択中のモデルでは日本語翻訳を完了できませんでした。日本語対応のInstructモデルで再生成してください。")
                }
                output.append(result)
            }
            translated.append(output.joined(separator: "\n\n"))
        }
        return translated.joined(separator: "```")
    }

    static func chunks(_ text: String, limit: Int) -> [String] {
        guard !text.isEmpty else { return [] }
        var remaining = text[...]
        var result: [String] = []
        while !remaining.isEmpty {
            let end = remaining.index(remaining.startIndex, offsetBy: min(limit, remaining.count))
            var split = end
            if end != remaining.endIndex {
                let window = remaining[..<end]
                if let line = window.lastIndex(of: "\n"), window.distance(from: window.startIndex, to: line) > limit / 2 {
                    split = remaining.index(after: line)
                }
            }
            result.append(String(remaining[..<split])); remaining = remaining[split...]
        }
        return result
    }
}

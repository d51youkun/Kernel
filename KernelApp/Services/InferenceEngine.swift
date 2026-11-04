import Foundation
import NaturalLanguage

extension LlamaBridge: @unchecked Sendable {}

@MainActor
final class InferenceEngine {
    private let bridge = LlamaBridge()
    private let loader = DispatchQueue(label: "app.kernel.model-loader", qos: .userInitiated)
    private var loadedID: UUID?
    private var configuration: Settings?
    var reachedTokenLimit: Bool { bridge.reachedTokenLimit }

    func load(_ model: ModelEntry, settings: Settings) async throws {
        if loadedID == model.id, configuration?.contextLength == settings.contextLength,
           configuration?.useMetal == settings.useMetal, configuration?.nThreads == settings.nThreads {
            configure(settings); return
        }
        let available = Int64(os_proc_available_memory())
        guard model.size < available * 9 / 10 else {
            throw KernelError.message("モデルのサイズが利用可能メモリに近すぎます。小さいGGUFを選択するか、他のアプリを閉じてください。")
        }
        configure(settings); loadedID = nil
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
        bridge.maxNewTokens = Int32(settings.maxTokens)
        bridge.temperature = Float(settings.temperature)
        bridge.topP = 0.95; bridge.topK = 40
        bridge.nGpuLayers = settings.useMetal ? 99 : 0
        bridge.nThreads = Int32(min(max(1, settings.nThreads), ProcessInfo.processInfo.activeProcessorCount))
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
        return result
    }
    func cancel() { bridge.cancelGeneration() }
    func waitUntilIdle() async {
        await withCheckedContinuation { c in bridge.wait(untilIdle: { c.resume() }) }
    }
    func unload() async {
        cancel(); let engine = bridge
        await withCheckedContinuation { c in loader.async { engine.unloadModel(); c.resume() } }
        loadedID = nil
    }
    static func foreignProse(_ text: String) -> Bool {
        let prose = text.replacingOccurrences(of: "`[^`]*`|https?://\\S+", with: " ", options: .regularExpression)
        let recognizer = NLLanguageRecognizer(); recognizer.processString(prose)
        return prose.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count > 20 && recognizer.dominantLanguage == .english
    }
    /// Generation must finish before translation starts on the same native context.
    /// Failure retains the original answer; source is never routed through translation.
    func japanese(_ text: String, chunkSize: Int) async throws -> String {
        var result = ""
        for segment in CodeDocument.segments(text) {
            try Task.checkCancellation()
            switch segment {
            case .code(let code): result += code.fencedText
            case .prose(let prose):
                for chunk in Self.chunks(prose, limit: chunkSize) {
                    if Self.foreignProse(chunk) {
                        let translated = try await complete([
                            ["role": "system", "content": JapanesePolicy.instruction + "\n翻訳文のみを返してください。要約しないでください。"],
                            ["role": "user", "content": chunk]
                        ])
                        guard !translated.isEmpty, !Self.foreignProse(translated) else {
                            throw KernelError.message("日本語翻訳を完了できなかったため、原文を保持しました。")
                        }
                        result += translated
                    } else { result += chunk }
                }
            }
        }
        return result
    }
    static func chunks(_ text: String, limit: Int) -> [String] {
        var rest = text[...], result: [String] = []
        while !rest.isEmpty {
            let end = rest.index(rest.startIndex, offsetBy: min(max(1, limit), rest.count))
            var split = end
            if end != rest.endIndex, let line = rest[..<end].lastIndex(of: "\n"), rest.distance(from: rest.startIndex, to: line) > limit / 2 {
                split = rest.index(after: line)
            }
            result.append(String(rest[..<split])); rest = rest[split...]
        }
        return result
    }
}

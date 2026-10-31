import Foundation

@MainActor
final class LlamaService: ObservableObject {
    static let shared = LlamaService()

    @Published var isLoaded = false
    @Published var isGenerating = false
    @Published var loadedModelId: UUID?

    private let bridge = LlamaBridge()

    private init() {}

    func loadModel(_ entry: ModelEntry) async throws {
        if loadedModelId == entry.id && bridge.isModelLoaded { return }

        isLoaded = false
        loadedModelId = nil

        let path = entry.fileURL.path
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.bridge.loadModel(fromPath: path)
                    Task { @MainActor in
                        self.isLoaded = true
                        self.loadedModelId = entry.id
                        cont.resume()
                    }
                } catch {
                    Task { @MainActor in
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }

    func unload() {
        bridge.unloadModel()
        isLoaded = false
        loadedModelId = nil
    }

    func generate(messages: [[String: String]]) -> AsyncThrowingStream<String, Error> {
        isGenerating = true
        return AsyncThrowingStream { continuation in
            bridge.generate(fromMessages: messages) { piece, isDone, error in
                if let error {
                    continuation.finish(throwing: error)
                    Task { @MainActor in self.isGenerating = false }
                    return
                }
                if isDone {
                    continuation.finish()
                    Task { @MainActor in self.isGenerating = false }
                } else if let piece {
                    continuation.yield(piece)
                }
            }
        }
    }

    func cancel() {
        bridge.cancelGeneration()
    }

    func configure(temperature: Float, topK: Int32, topP: Float,
                   maxNewTokens: Int32, contextLength: Int32, nGpuLayers: Int32) {
        bridge.temperature = temperature
        bridge.topK = topK
        bridge.topP = topP
        bridge.maxNewTokens = maxNewTokens
        bridge.contextLength = contextLength
        bridge.nGpuLayers = nGpuLayers
    }

    var modelDescription: String? {
        bridge.modelDescription
    }
}

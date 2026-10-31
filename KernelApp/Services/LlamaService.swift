// LlamaService.swift
// LlamaBridge を Swift から安全に使うためのサービス層
// ロードはバックグラウンドキュー、生成は AsyncThrowingStream でトークンを配信する

import Foundation

/// 推論パラメータのまとまり
struct InferenceParams {
    var temperature: Float = 0.8
    var topK: Int32 = 40
    var topP: Float = 0.95
    var maxNewTokens: Int32 = 1024
}

/// llama.cpp 推論サービス (シングルトン)
@MainActor
final class LlamaService: ObservableObject {
    static let shared = LlamaService()

    @Published var isLoaded = false
    @Published var isGenerating = false
    @Published var loadedModelId: UUID?

    private let bridge = LlamaBridge()
    /// モデルロードなど重い処理を流す専用キュー
    private let loadQueue = DispatchQueue(label: "com.kernel.llama.load", qos: .userInitiated)

    private init() {
        LlamaBridge.initializeBackend()
    }

    // ── モデル管理 ───────────────────────────

    /// 指定モデルをロードする (既にロード済みなら何もしない)
    func loadModel(_ entry: ModelEntry) async throws {
        if isLoaded && loadedModelId == entry.id && bridge.isModelLoaded { return }

        isLoaded = false
        loadedModelId = nil

        let path = entry.fileURL.path
        let contextLength = Int32(AppSettings.shared.contextLength)
        let bridge = self.bridge
        let loadQueue = self.loadQueue

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            loadQueue.async {
                do {
                    // GGUF を Metal GPU に全レイヤー積む (n_gpu_layers = 99)
                    try bridge.loadModel(fromPath: path,
                                         contextLength: contextLength,
                                         nGpuLayers: 99)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }

        isLoaded = true
        loadedModelId = entry.id
    }

    /// モデルをアンロードしてメモリを解放する
    func unload() {
        loadQueue.async { [bridge] in
            bridge.unloadModel()
        }
        isLoaded = false
        loadedModelId = nil
    }

    var modelDescription: String? {
        bridge.modelDescription
    }

    // ── 生成 ───────────────────────────────

    /// メッセージ配列からトークンをストリーミング生成する
    /// - Parameter messages: [["role": "user", "content": "…"]] 形式
    func generate(messages: [[String: String]],
                  params: InferenceParams) -> AsyncThrowingStream<String, Error> {
        isGenerating = true
        let bridge = self.bridge
        let service = self

        return AsyncThrowingStream { continuation in
            bridge.generate(fromMessages: messages,
                            maxNewTokens: params.maxNewTokens,
                            temperature: params.temperature,
                            topK: params.topK,
                            topP: params.topP) { piece, isDone, error in
                if let error {
                    continuation.finish(throwing: error)
                } else if isDone {
                    continuation.finish()
                } else if let piece {
                    continuation.yield(piece)
                }
                if isDone || error != nil {
                    Task { @MainActor [weak service] in
                        service?.isGenerating = false
                    }
                }
            }
        }
    }

    /// 生成を中断する
    func cancel() {
        bridge.cancelGeneration()
    }
}

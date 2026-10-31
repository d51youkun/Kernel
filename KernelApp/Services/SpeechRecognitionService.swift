// SpeechRecognitionService.swift
// 日本語音声認識による音声入力 (SFSpeechRecognizer / ja-JP)

import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognitionService: ObservableObject {
    static let shared = SpeechRecognitionService()

    @Published var isRecording = false
    @Published var transcript = ""
    @Published var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    private init() {}

    // ── 権限 ─────────────────────────────────

    /// マイクと音声認識の権限をリクエストする
    func requestAuthorization() async -> Bool {
        let micGranted = await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
        guard micGranted else {
            errorMessage = "マイクへのアクセスが許可されていません。設定アプリで許可してください。"
            return false
        }

        let speechGranted = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else {
            errorMessage = "音声認識へのアクセスが許可されていません。設定アプリで許可してください。"
            return false
        }
        return true
    }

    // ── 録音 ─────────────────────────────────

    /// 録音を開始する。部分認識のたびに onResult が呼ばれる
    func startRecording(onResult: @escaping @MainActor (String) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard await self.requestAuthorization() else { return }

            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
                try session.setActive(true, options: .notifyOthersOnDeactivation)

                let engine = AVAudioEngine()
                self.audioEngine = engine

                guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")),
                      recognizer.isAvailable else {
                    self.errorMessage = "日本語音声認識が利用できません"
                    return
                }
                self.recognizer = recognizer

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                self.request = request

                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    request.append(buffer)
                }

                try engine.start()
                self.isRecording = true
                self.transcript = ""
                self.errorMessage = nil

                self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    guard let self else { return }
                    if let result {
                        let text = result.bestTranscription.formattedString
                        Task { @MainActor in
                            self.transcript = text
                            onResult(text)
                        }
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        Task { @MainActor in
                            self.stopRecording()
                        }
                    }
                }
            } catch {
                self.errorMessage = "録音を開始できませんでした: \(error.localizedDescription)"
                self.stopRecording()
            }
        }
    }

    /// 録音を停止する
    nonisolated func stopRecording() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.request?.endAudio()
            self.task?.cancel()
            self.task = nil
            self.request = nil
            self.audioEngine?.inputNode.removeTap(onBus: 0)
            self.audioEngine?.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.audioEngine = nil
            self.isRecording = false
        }
    }
}

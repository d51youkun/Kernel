import AVFoundation
import Speech

@MainActor
final class VoiceInput: ObservableObject {
    @Published var recording = false
    @Published var transcript = ""
    @Published var error: String?
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timeout: Task<Void, Never>?
    private var requesting = false

    func toggle() async {
        if recording { stop(); return }
        guard !requesting else { return }
        requesting = true; defer { requesting = false }
        let speech = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard speech == .authorized, microphone else { error = "設定アプリでマイクと音声認識を許可してください。"; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else { error = "日本語のオンデバイス音声認識が利用できません。"; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
            let node = engine.inputNode; let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw KernelError.message("マイクを使用できません。") }
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            self.engine = engine; self.request = request
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if result?.isFinal == true || error != nil { self?.stop() }
                }
            }
            engine.prepare(); try engine.start(); recording = true; transcript = ""
            timeout = Task { try? await Task.sleep(for: .seconds(55)); if !Task.isCancelled { stop() } }
        } catch { self.error = error.localizedDescription; stop() }
    }
    func stop() {
        timeout?.cancel(); timeout = nil
        engine?.stop(); engine?.inputNode.removeTap(onBus: 0); engine = nil
        request?.endAudio(); request = nil; task?.cancel(); task = nil; recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

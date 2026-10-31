import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognitionService: NSObject, ObservableObject {
    static let shared = SpeechRecognitionService()

    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    private override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                self.authorizationStatus = status
            }
        }
    }

    func startListening() throws {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            Task { @MainActor in
                if let error = error {
                    self.stopListening()
                    return
                }

                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }

                if result?.isFinal == true {
                    self.stopListening()
                }
            }
        }

        isListening = true
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
    }

    enum SpeechError: LocalizedError {
        case recognizerUnavailable
        case requestCreationFailed
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "音声認識が利用できません"
            case .requestCreationFailed:
                return "認識リクエストの作成に失敗しました"
            case .notAuthorized:
                return "音声認識が許可されていません"
            }
        }
    }
}

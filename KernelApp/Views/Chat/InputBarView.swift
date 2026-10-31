// InputBarView.swift
// 下部の入力バー (テキスト入力 + 音声入力 + 送信/停止)

import SwiftUI

struct InputBarView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var settings: AppSettings
    @StateObject private var speech = SpeechRecognitionService.shared
    @State private var inputText = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // マイクボタン (録音中は赤)
            Button {
                toggleMic()
            } label: {
                Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 18))
                    .foregroundStyle(speech.isRecording ? .red : Color.accentColor)
                    .frame(width: 36, height: 36)
            }
            .disabled(chatVM.isGenerating)

            // テキスト入力
            TextField("メッセージを入力…", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
                .onSubmit { send() }

            // 送信 or 停止
            if chatVM.isGenerating {
                Button {
                    chatVM.stopGeneration()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.red, in: Circle())
                }
            } else {
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            canSend ? Color.accentColor : Color.gray.opacity(0.4),
                            in: Circle()
                        )
                }
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) {
            if speech.isRecording {
                Text("🎙️ 録音中… もう一度タップで停止")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .offset(y: -28)
            }
        }
        .onChange(of: speech.transcript) { newValue in
            if speech.isRecording { inputText = newValue }
        }
        .alert("音声入力", isPresented: Binding(
            get: { speech.errorMessage != nil },
            set: { if !$0 { speech.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(speech.errorMessage ?? "")
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        chatVM.send(inputText)
        inputText = ""
    }

    private func toggleMic() {
        if speech.isRecording {
            speech.stopRecording()
        } else {
            speech.startRecording { text in
                // 部分認識のたびに transcript が onChange で反映される
            }
        }
    }
}

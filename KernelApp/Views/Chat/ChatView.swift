import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var chatVM: ChatViewModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var modelManager: ModelManager

    @State private var selectedModel: ModelEntry?

    var body: some View {
        ZStack {
            ThemeEngine.backgroundColor(for: settings.theme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if let conv = chatVM.currentConversation {
                                ForEach(conv.messages) { message in
                                    MessageBubbleView(
                                        message: message,
                                        accentColor: settings.accentColor.color,
                                        theme: settings.theme,
                                        fontSize: settings.fontSize.bodySize,
                                        messageWidth: settings.messageWidth.fraction,
                                        renderMarkdown: settings.renderMarkdown,
                                        codeHighlight: settings.codeHighlight,
                                        showTimestamps: settings.showTimestamps,
                                        assistantName: settings.assistantName,
                                        assistantEmoji: settings.assistantEmoji,
                                        onFeedback: chatVM.setFeedback,
                                        onSpeak: { chatVM.speak(message.content) },
                                        onStopSpeaking: chatVM.stopSpeaking
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .onChange(of: chatVM.currentConversation?.messages.count) { _ in
                        if let lastId = chatVM.currentConversation?.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }

                if let warning = chatVM.foreignLanguageWarning {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.caption)
                        Button("再生成") {
                            if let model = selectedModel {
                                Task {
                                    await chatVM.regenerateInJapanese(with: model)
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        Button("✕") {
                            chatVM.foreignLanguageWarning = nil
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }

                InputBarView(
                    inputText: $inputText,
                    isGenerating: chatVM.isGenerating,
                    accentColor: settings.accentColor.color,
                    theme: settings.theme,
                    onSend: {
                        guard let model = selectedModel else { return }
                        Task {
                            await chatVM.sendMessage(inputText, with: model)
                            inputText = ""
                        }
                    },
                    onStop: chatVM.stopGeneration,
                    onVoiceInput: {
                        let speechService = SpeechRecognitionService.shared
                        if speechService.isListening {
                            speechService.stopListening()
                            inputText = speechService.recognizedText
                        } else {
                            try? speechService.startListening()
                        }
                    },
                    isListening: SpeechRecognitionService.shared.isListening
                )
            }
        }
        .navigationTitle(chatVM.currentConversation?.title ?? "New Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(modelManager.models) { model in
                        Button {
                            selectedModel = model
                        } label: {
                            HStack {
                                Text(model.displayName)
                                if selectedModel?.id == model.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "cpu")
                        Text(selectedModel?.displayName ?? "モデルを選択")
                    }
                }
            }
        }
        .onAppear {
            selectedModel = modelManager.models.first
        }
    }

    @State private var inputText = ""
}

// ChatView.swift

import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    let model: ModelEntry
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var settings: AppSettings
    @Environment(\.themeTokens) var tokens

    @State private var inputText = ""
    @State private var pendingAttachments: [AttachedFile] = []
    @State private var showFilePicker = false
    @State private var showExportSheet = false
    @State private var exportContent = ""
    @State private var editingMessageId: UUID? = nil
    @State private var editingText = ""
    @State private var htmlFileItem: HTMLFileItem? = nil
    @State private var showScrollButton = false
    @StateObject private var speechRecognizer = SpeechRecognitionService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            tokens.chatBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                messageList
                if let warn = chatVM.foreignLanguageWarning { foreignLanguageBanner(warn) }
                if let err = chatVM.errorMessage { errorBanner(err) }
                if let name = chatVM.loadingModelName { loadingBar(name) }
                inputArea
            }
        }
        .navigationTitle(chatVM.currentConversation?.title ?? model.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(text: exportContent)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showFilePicker) {
            FilePicker { urls in
                for url in urls {
                    if let att = try? chatVM.importAttachment(from: url) {
                        pendingAttachments.append(att)
                    }
                }
            }
        }
        .sheet(item: $htmlFileItem) { item in
            HTMLFileSheet(url: item.url)
        }
        .background(magicKeyboardShortcuts)
    }

    // ── メッセージリスト ─────────────────────────────

    private var messageList: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        let visibleMessages = (chatVM.currentConversation?.messages ?? [])
                            .filter { $0.role != .system }
                        if visibleMessages.isEmpty {
                            WelcomeView(
                                modelName: model.displayName,
                                onSuggestionTap: { suggestion in
                                    inputText = suggestion
                                }
                            )
                            .padding(.top, 80)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(visibleMessages) { msg in
                                if editingMessageId == msg.id {
                                    inlineEditView(msg).id(msg.id)
                                } else {
                                    MessageBubbleView(
                                        message: msg,
                                        isLastAndGenerating: isLastGenerating(msg),
                                        onCopy:       { UIPasteboard.general.string = msg.content },
                                        onEdit:       { editingText = msg.content; editingMessageId = msg.id },
                                        onRegenerate: { Task { await chatVM.regenerateLastResponse(with: model) } },
                                        onSpeak:      { chatVM.speak(msg.content) },
                                        onDownloadHTML: { url in
                                            htmlFileItem = HTMLFileItem(url: url)
                                        },
                                        onFeedback: { feedback in
                                            chatVM.setFeedback(for: msg.id, feedback: feedback)
                                        }
                                    )
                                    .id(msg.id)
                                }
                            }
                        }
                        // 下部検出用: ボトムに到達したか判定
                        Color.clear
                            .frame(height: 12)
                            .id("bottom")
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: BottomVisibleKey.self,
                                                     value: geo.frame(in: .named("scroll")).maxY < UIScreen.main.bounds.height + 100)
                                }
                            )
                    }
                    .padding(.top, 8)
                }
                .coordinateSpace(name: "scroll")
                .scrollDismissesKeyboard(.interactively)
                .onPreferenceChange(BottomVisibleKey.self) { visible in
                    showScrollButton = !visible
                }
                .onChange(of: chatVM.currentConversation?.messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom") }
                }
                .onChange(of: chatVM.currentConversation?.messages.last?.content) { _ in
                    proxy.scrollTo("bottom")
                }
                .onAppear { proxy.scrollTo("bottom") }

                // スクロールボトムボタン（ChatGPT風）
                if showScrollButton {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tokens.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(tokens.surface)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.bottom, 80)
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }

    private func isLastGenerating(_ msg: Message) -> Bool {
        chatVM.isGenerating && chatVM.currentConversation?.messages.last?.id == msg.id
    }

    // ── インライン編集 ──────────────────────────────

    private func inlineEditView(_ msg: Message) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextField("メッセージを編集", text: $editingText, axis: .vertical)
                .font(.system(size: settings.fontSize.bodySize))
                .padding(12)
                .background(tokens.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(settings.accentColor.color.opacity(0.6), lineWidth: 1.5)
                )
                .padding(.horizontal, 16)
            HStack(spacing: 12) {
                Button("キャンセル") { editingMessageId = nil }
                    .foregroundStyle(tokens.textSecondary)
                Button("送信") {
                    let t = editingText; editingMessageId = nil
                    Task { await chatVM.editAndResend(messageId: msg.id, newContent: t, with: model) }
                }
                .foregroundStyle(settings.accentColor.color)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
    }

    // ── 入力エリア ──────────────────────────────────

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider().background(tokens.separator)

            // 添付ファイルプレビュー
            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingAttachments) { att in
                            AttachmentChip(att: att, tokens: tokens) {
                                pendingAttachments.removeAll { $0.id == att.id }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(tokens.surface)
                Divider().background(tokens.separator)
            }
            
            // 音声認識ライブプレビュー
            if speechRecognizer.isRecording && !speechRecognizer.recognizedText.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(speechRecognizer.recognizedText)
                        .font(.callout)
                        .foregroundStyle(tokens.textPrimary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(settings.accentColor.color.opacity(0.08))
                Divider().background(tokens.separator)
            }

            HStack(alignment: .bottom, spacing: 10) {
                // 添付ボタン
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(settings.accentColor.color)
                }
                .buttonStyle(.plain)
                
                // 音声入力ボタン
                Button {
                    if speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                        if !speechRecognizer.recognizedText.isEmpty {
                            inputText += (inputText.isEmpty ? "" : " ") + speechRecognizer.recognizedText
                        }
                        speechRecognizer.reset()
                    } else {
                        if speechRecognizer.authorizationStatus == .notDetermined {
                            speechRecognizer.requestAuthorization()
                        } else if speechRecognizer.authorizationStatus == .authorized {
                            try? speechRecognizer.startRecording()
                        }
                    }
                } label: {
                    Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(speechRecognizer.isRecording ? .red : settings.accentColor.color)
                }
                .buttonStyle(.plain)

                // テキスト入力
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("メッセージ")
                            .font(.system(size: settings.fontSize.bodySize))
                            .foregroundStyle(tokens.textSecondary.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    TextField("", text: $inputText, axis: .vertical)
                        .font(.system(size: settings.fontSize.bodySize))
                        .foregroundStyle(tokens.textPrimary)
                        .tint(settings.accentColor.color)
                        .lineLimit(1...8)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        // IME変換確定のEnterで送信しないよう onSubmit は使わない
                        // 送信は Cmd+Return ショートカットのみ（sendStopButton / inputArea 下部で処理）
                        .submitLabel(.send)
                }
                .background(tokens.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tokens.inputBorder, lineWidth: 1)
                )

                // 送信/停止ボタン
                sendStopButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tokens.appBackground)
        }
    }

    @ViewBuilder
    private var sendStopButton: some View {
        if chatVM.isGenerating {
            Button { chatVM.stopGeneration() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color(.label))
                    .clipShape(Circle())
            }
        } else {
            Button { sendMessage() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(canSend ? settings.accentColor.color : tokens.textSecondary.opacity(0.3))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
        }
    }

    private var canSend: Bool {
        (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty)
            && !chatVM.isGenerating
    }

    private func sendMessage() {
        guard canSend else { return }
        let text = inputText
        let attachments = pendingAttachments
        inputText = ""
        pendingAttachments = []
        Task {
            await chatVM.sendMessage(text, attachments: attachments, with: model)
            // HTML自動検出
            if let lastMsg = chatVM.currentConversation?.messages.last,
               lastMsg.role == .assistant,
               let htmlURL = chatVM.extractAndSaveHTML(from: lastMsg.content) {
                htmlFileItem = HTMLFileItem(url: htmlURL)
            }
        }
    }

    // ── ツールバー ──────────────────────────────────

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 4) {
                Button {
                    if let conv = chatVM.currentConversation {
                        exportContent = conv.exportText()
                        showExportSheet = true
                    }
                } label: { Image(systemName: "square.and.arrow.up") }

                Button {
                    chatVM.newConversation(modelId: model.id)
                } label: { Image(systemName: "square.and.pencil") }
            }
        }
    }

    // ── Magic Keyboard ──────────────────────────────

    private var magicKeyboardShortcuts: some View {
        Group {
            // Cmd+Return: 送信（IME変換確定Enterと区別するため Cmd 修飾子が必要）
            Button("") { sendMessage() }
                .keyboardShortcut(.return, modifiers: .command).opacity(0)
            Button("") { chatVM.newConversation(modelId: model.id) }
                .keyboardShortcut("n", modifiers: .command).opacity(0)
            Button("") { chatVM.stopGeneration() }
                .keyboardShortcut(.escape, modifiers: []).opacity(0)
            Button("") {
                if let conv = chatVM.currentConversation {
                    exportContent = conv.exportText(); showExportSheet = true
                }
            }
            .keyboardShortcut("e", modifiers: .command).opacity(0)
        }
    }

    // ── バナー ──────────────────────────────────────

    @ViewBuilder
    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
            Text(text).font(.caption).foregroundStyle(.red).lineLimit(3)
            Spacer()
            Button { chatVM.errorMessage = nil } label: {
                Image(systemName: "xmark").font(.caption.bold()).foregroundStyle(tokens.textSecondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.red.opacity(0.08))
    }

    private func loadingBar(_ name: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.8)
            Text("\(name) を読み込み中…").font(.caption).foregroundStyle(tokens.textSecondary)
        }
        .padding(.vertical, 6).padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tokens.surface)
    }

    private func foreignLanguageBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.caption).foregroundStyle(.orange).lineLimit(4)
            Spacer()
            Button {
                Task { await chatVM.regenerateInJapanese(with: model) }
            } label: {
                Label("再生成", systemImage: "arrow.clockwise")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Button { chatVM.foreignLanguageWarning = nil } label: {
                Image(systemName: "xmark").font(.caption.bold()).foregroundStyle(tokens.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }
}

// HTMLシート表示用のIdentifiable
struct HTMLFileItem: Identifiable {
    let id = UUID()
    let url: URL
}

// ── ファイルピッカー ───────────────────────────────────

struct FilePicker: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

// ── 添付チップ ─────────────────────────────────────────

struct AttachmentChip: View {
    let att: AttachedFile
    let tokens: ThemeTokens
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: att.displayIcon)
                .font(.caption)
                .foregroundStyle(Color.blue)
            Text(att.fileName)
                .font(.caption)
                .foregroundStyle(tokens.textPrimary)
                .lineLimit(1)
            Text(att.humanSize)
                .font(.caption2)
                .foregroundStyle(tokens.textSecondary)
            Button { onRemove() } label: {
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .foregroundStyle(tokens.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tokens.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tokens.separator, lineWidth: 0.5))
    }
}

// ── HTMLファイルシート ─────────────────────────────────

struct HTMLFileSheet: View {
    let url: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("HTMLファイルが生成されました")
                    .font(.title3.bold())
                Text(url.lastPathComponent)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    // コピー
                    Button {
                        if let text = try? String(contentsOf: url, encoding: .utf8) {
                            UIPasteboard.general.string = text
                        }
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    // 共有（ダウンロード）
                    ShareLink(item: url) {
                        Label("保存/共有", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("HTML生成完了")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// ── エクスポートシート ────────────────────────────────

struct ExportSheet: View {
    let text: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeTokens) var tokens
    @EnvironmentObject var settings: AppSettings

    private func exportURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation_\(Int(Date().timeIntervalSince1970)).txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(tokens.textPrimary)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(tokens.appBackground)
            .navigationTitle("エクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            UIPasteboard.general.string = text
                        } label: { Image(systemName: "doc.on.doc") }

                        ShareLink(
                            item: exportURL(),
                            subject: Text("会話"),
                            message: Text("Kernelからエクスポート")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }
}

// ── PreferenceKey for Scroll Position ─────────────────

struct BottomVisibleKey: PreferenceKey {
    static var defaultValue: Bool = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @EnvironmentObject private var store: AppStore
    @State private var visibility = NavigationSplitViewVisibility.all
    @State private var rename: Conversation?
    @State private var name = ""
    @State private var newProject = false
    @State private var project = ""

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            VStack(spacing: 0) {
                HStack {
                    Label("Kernel", systemImage: "circle.hexagongrid.fill").font(.title3.bold())
                    Spacer()
                    Button { store.newChat() } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("新しいチャット").keyboardShortcut("n", modifiers: .command)
                }.padding(20)
                TextField("チャットを検索", text: $store.search)
                    .textFieldStyle(.roundedBorder).padding(.horizontal, 16).padding(.bottom, 14)
                List {
                    Section {
                        Button { store.projectFilter = nil; store.showArchived = false; store.newChat() } label: {
                            Label("新しいチャット", systemImage: "square.and.pencil")
                        }
                        Button { store.showArchived.toggle() } label: {
                            Label(store.showArchived ? "チャットに戻る" : "アーカイブ", systemImage: "archivebox")
                        }
                    }
                    Section("プロジェクト") {
                        Button { project = ""; newProject = true } label: { Label("プロジェクトを作成", systemImage: "folder.badge.plus") }
                        ForEach(store.projects, id: \.self) { project in
                            Button { store.projectFilter = project; store.showArchived = false } label: {
                                Label(project, systemImage: store.projectFilter == project ? "folder.fill" : "folder")
                            }
                        }
                        if store.projectFilter != nil { Button("すべてのチャットを表示") { store.projectFilter = nil } }
                    }
                    Section(store.showArchived ? "アーカイブ" : "チャット") {
                        ForEach(store.visible) { conversation in
                            Button { store.select(conversation) } label: {
                                HStack(spacing: 8) {
                                    if conversation.isPinned { Image(systemName: "pin.fill").font(.caption) }
                                    Text(conversation.title).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 5)
                                .foregroundStyle(.primary)
                            }
                            .listRowBackground(store.selectedID == conversation.id ? Color.primary.opacity(0.08) : Color.clear)
                            .contextMenu {
                                Button("名前を変更", systemImage: "pencil") { rename = conversation; name = conversation.title }
                                Button(conversation.isPinned ? "ピン留め解除" : "ピン留め", systemImage: "pin") { store.modify(conversation.id) { $0.isPinned.toggle() } }
                                Button(conversation.isArchived ? "復元" : "アーカイブ", systemImage: "archivebox") { store.modify(conversation.id) { $0.isArchived.toggle() } }
                                Menu("プロジェクトへ移動") {
                                    Button("なし") { store.modify(conversation.id) { $0.project = nil } }
                                    ForEach(store.projects, id: \.self) { project in Button(project) { store.modify(conversation.id) { $0.project = project } } }
                                }
                                Button("削除", systemImage: "trash", role: .destructive) { store.delete(conversation.id) }
                            }
                        }
                    }
                }.listStyle(.sidebar).scrollContentBackground(.hidden).disabled(store.busy)
                Button { store.showSettings = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill").font(.title)
                        VStack(alignment: .leading) {
                            Text("あなたのワークスペース").font(.subheadline.weight(.medium))
                            Text("設定・モデル管理").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "gearshape")
                    }.padding(18)
                }.buttonStyle(.plain)
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
            .toolbar(.hidden, for: .navigationBar)
        } detail: {
            ChatScreen()
        }
        .sheet(isPresented: $store.showSettings) { SettingsScreen().environmentObject(store) }
        .alert("Kernel", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("閉じる", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .alert("チャット名", isPresented: Binding(get: { rename != nil }, set: { if !$0 { rename = nil } })) {
            TextField("名前", text: $name)
            Button("保存") { if let rename { store.modify(rename.id) { $0.title = name } }; rename = nil }
            Button("キャンセル", role: .cancel) { rename = nil }
        }
        .alert("プロジェクトを作成", isPresented: $newProject) {
            TextField("プロジェクト名", text: $project)
            Button("作成") {
                let trimmed = project.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { store.projectFilter = trimmed; store.newChat() }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
}

private struct ChatScreen: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var voice = VoiceInput()
    @State private var draft = ""
    @State private var attachments: [Attachment] = []
    @State private var importing = false
    @State private var extracting = false
    @State private var editMessage: Message?
    @State private var editText = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let current = store.current, !current.messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 30) {
                            ForEach(current.messages) { message in
                                MessageCard(message: message, edit: {
                                    editMessage = message; editText = message.content
                                })
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }.frame(maxWidth: 800).frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, 24)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: current.messages.last?.content) { _, _ in
                        // A reader can scroll up during streaming without being pulled back on every token.
                        if focused { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: current.messages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
            } else {
                Spacer()
                VStack(spacing: 18) {
                    Image(systemName: "circle.hexagongrid.fill").font(.system(size: 44, weight: .light))
                    Text("今日は何をお手伝いしましょうか？").font(.system(size: 29, weight: .semibold)).multilineTextAlignment(.center)
                    Text(store.workspace.provider == "local" ? "GGUFモデルで、iPadの中にあなただけのAIを。" : "APIにつないで、アイデアを形に。")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if store.models.isEmpty && store.workspace.provider == "local" {
                        Button("モデル・APIを設定", systemImage: "plus") { store.showSettings = true }.buttonStyle(.borderedProminent)
                    } else {
                        ViewThatFits {
                            HStack { suggestions }
                            VStack { suggestions }
                        }.padding(.top, 12)
                    }
                }.padding(30)
                Spacer()
            }
            composer
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(store.models) { model in Button(model.displayName) { store.modelID = model.id; store.persist() } }
                    Divider()
                    Button("モデルを管理…", systemImage: "slider.horizontal.3") { store.showSettings = true }
                } label: {
                    HStack(spacing: 6) { Text(store.workspace.provider == "local" ? (store.selectedModel?.displayName ?? "Kernel") : store.workspace.apiModel).font(.headline); Image(systemName: "chevron.down").font(.caption) }
                }.disabled(store.busy)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.current != nil {
                    ShareLink(item: store.exportText()) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("会話を共有")
                }
                Button {
                    store.temporary.toggle(); store.newChat()
                } label: { Image(systemName: store.temporary ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right") }
                    .accessibilityLabel(store.temporary ? "一時チャットを終了" : "一時チャット").disabled(store.busy)
                Button { store.newChat() } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("新しいチャット").disabled(store.busy)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                extracting = true
                Task {
                    defer { extracting = false }
                    for url in urls {
                        do { attachments.append(try await store.attachment(url)) }
                        catch { store.error = error.localizedDescription }
                    }
                }
            case .failure(let error): store.error = error.localizedDescription
            }
        }
        .onChange(of: voice.transcript) { _, value in draft = value }
        .onChange(of: store.shortcutDraft) { _, value in draft = value; focused = true }
        .onChange(of: voice.error) { _, value in if let value { store.error = value } }
        .onDisappear { voice.stop() }
        .sheet(item: $editMessage) { message in
            NavigationStack {
                TextEditor(text: $editText).padding().navigationTitle("メッセージを編集")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { editMessage = nil } }
                        ToolbarItem(placement: .confirmationAction) { Button("送信") { store.edit(message, text: editText); editMessage = nil }.disabled(editText.isEmpty || store.busy) }
                    }
            }.presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var suggestions: some View {
        ForEach([("doc.text", "文章を要約", "次の資料を、結論・重要な事実・決定事項・未解決点に分けて要約してください。\n\n"),
                 ("chevron.left.forwardslash.chevron.right", "コードを相談", "次のコードについて、問題点と改善方法を教えてください。\n\n"),
                 ("lightbulb", "アイデアを整理", "アイデアを一緒に整理してください。まず目的を確認する質問をしてください。")], id: \.1) { item in
            Button { draft = item.2; focused = true } label: {
                Label(item.1, systemImage: item.0).font(.subheadline).padding(.horizontal, 16).padding(.vertical, 12)
                    .overlay(Capsule().stroke(.quaternary))
            }.buttonStyle(.plain)
        }
    }

    private var composer: some View {
        VStack(spacing: 9) {
            if let status = store.status { HStack(spacing: 8) { ProgressView().controlSize(.small); Text(status).font(.caption).foregroundStyle(.secondary) } }
            if store.temporary { Label("一時チャット · 履歴には保存されません", systemImage: "eye.slash").font(.caption).foregroundStyle(.secondary) }
            VStack(alignment: .leading, spacing: 10) {
                if !attachments.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(attachments) { item in
                                HStack { Image(systemName: "doc.text"); Text(item.fileName).lineLimit(1); Button { attachments.removeAll { $0.id == item.id } } label: { Image(systemName: "xmark.circle.fill") } }
                                    .font(.caption).padding(9).background(.background, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                TextField("メッセージを入力", text: $draft, axis: .vertical)
                    .lineLimit(1...8).focused($focused).padding(.horizontal, 4).padding(.top, 7)
                    .accessibilityIdentifier("chat.composer")
                    // onSubmit・keyboardShortcut は意図的に付けない
                    // Magic Keyboard + 日本語IMEでゃゅょ等の小文字変換がブロックされるため
                HStack {
                    Button { importing = true } label: { Image(systemName: "plus").font(.title3) }.accessibilityLabel("ファイルを添付").disabled(extracting || store.busy)
                    if extracting { ProgressView().controlSize(.small); Text("資料を読み取り中…").font(.caption) }
                    Spacer()
                    Button { Task { await voice.toggle() } } label: { Image(systemName: voice.recording ? "mic.fill" : "mic").foregroundStyle(voice.recording ? .red : .primary).font(.title3) }
                        .accessibilityLabel(voice.recording ? "音声入力を停止" : "音声入力").disabled(store.busy)
                    Button {
                        if store.busy { store.stop() }
                        else { voice.stop(); store.send(draft, attachments: attachments); if store.busy { draft = ""; attachments = [] } }
                    } label: {
                        Image(systemName: store.busy ? "stop.fill" : "arrow.up")
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(Color(uiColor: .systemBackground))
                            .frame(width: 34, height: 34).background(Color.primary, in: Circle())
                    }
                    .accessibilityLabel(store.busy ? "生成を停止" : "送信")
                    .disabled(!store.busy && ((draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty) || extracting || store.importing))
                    // Cmd+Return は IME確定と競合するため外す（ボタンタップで送信）
                }.buttonStyle(.plain)
            }
            .padding(14).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 27))
            Text("Kernelの回答は誤りを含むことがあります。重要な情報は確認してください。")
                .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: 800).padding(.horizontal, 24).padding(.bottom, 12).frame(maxWidth: .infinity)
    }
}

private struct MessageCard: View {
    @EnvironmentObject private var store: AppStore
    let message: Message
    let edit: () -> Void
    private var user: Bool { message.role == .user }
    var body: some View {
        VStack(alignment: user ? .trailing : .leading, spacing: 12) {
            if !message.attachments.isEmpty {
                ForEach(message.attachments) { item in Label(item.fileName, systemImage: "doc.text").font(.caption).padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 12)) }
            }
            if user {
                Text(message.content).textSelection(.enabled).padding(.horizontal, 20).padding(.vertical, 13)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                    .frame(maxWidth: 620, alignment: .trailing).frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                if message.content.isEmpty { ProgressView().padding(.vertical) }
                else { RichMessage(text: message.content) }
                if message.interrupted {
                    Label("生成が中断されました", systemImage: "pause.circle").font(.caption).foregroundStyle(.secondary)
                }
                if !store.busy, store.current?.messages.last?.id == message.id {
                    Button("続きを生成", systemImage: "arrow.right.circle") { store.continueResponse() }.font(.caption)
                }
            }
            if !message.content.isEmpty {
                HStack(spacing: 18) {
                    Button { UIPasteboard.general.string = message.content } label: { Image(systemName: "doc.on.doc") }.accessibilityLabel("コピー")
                    if user { Button(action: edit) { Image(systemName: "pencil") }.accessibilityLabel("編集して再送信").disabled(store.busy) }
                    else {
                        Button { store.feedback(message, value: "up") } label: { Image(systemName: message.feedback == "up" ? "hand.thumbsup.fill" : "hand.thumbsup") }.accessibilityLabel("良い回答")
                        Button { store.feedback(message, value: "down") } label: { Image(systemName: message.feedback == "down" ? "hand.thumbsdown.fill" : "hand.thumbsdown") }.accessibilityLabel("改善が必要")
                        Button { store.speak(message.content) } label: { Image(systemName: "speaker.wave.2") }.accessibilityLabel("読み上げ")
                        Button { store.regenerate() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("再生成").disabled(store.busy || store.current?.messages.last?.id != message.id)
                        Button { store.branch(at: message) } label: { Image(systemName: "arrow.triangle.branch") }.accessibilityLabel("ここから分岐").disabled(store.busy)
                        ShareLink(item: message.content) { Image(systemName: "square.and.arrow.up") }
                        if let duration = message.duration { Text(String(format: "%.1f秒", duration)).font(.caption2) }
                    }
                }.font(.system(size: 14)).foregroundStyle(.secondary).buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: user ? .trailing : .leading)
            }
        }.frame(maxWidth: .infinity, alignment: user ? .trailing : .leading)
    }
}

struct RichMessage: View {
    let text: String
    var body: some View {
        let parts = CodeDocument.segments(text)
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .code(let code): CodeArtifactView(code: code)
                case .prose(let part):
                    // Preserve paragraph/list layout and render inline Markdown within each line.
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(part.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                            if line.hasPrefix("#") {
                                Text(LocalizedStringKey(line.replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression))).font(.headline).padding(.top, 5)
                            } else { Text(LocalizedStringKey(line.isEmpty ? " " : line)).lineSpacing(5) }
                        }
                    }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

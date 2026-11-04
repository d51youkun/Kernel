import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var importing = false
    @State private var rename: ModelEntry?
    @State private var modelName = ""
    @State private var deletion: ModelEntry?
    @State private var clearHistory = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ワークスペース") {
                    NavigationLink { ConnectionsScreen() } label: { Label("アカウント・API接続", systemImage: "person.crop.circle.badge.checkmark") }
                    Toggle("英語の説明を日本語に自動翻訳", isOn: $store.workspace.autoTranslate)
                    Toggle("API出力上限で自動継続（最大3回）", isOn: $store.workspace.autoContinue)
                    Text("コード・固有名詞・技術用語の原表記を保持します。翻訳は回答生成の完了後に行います。自動継続には追加のAPI利用料が発生します。").font(.caption).foregroundStyle(.secondary)
                }.disabled(store.busy)
                Section("モデル") {
                    if store.models.isEmpty { Text("GGUF形式のInstructモデルを追加してください。日本語対応・1〜3Bの量子化モデルから試すことをおすすめします。").foregroundStyle(.secondary) }
                    ForEach(store.models) { model in
                        HStack {
                            Button { store.modelID = model.id; store.persist() } label: {
                                HStack {
                                    Image(systemName: store.modelID == model.id ? "checkmark.circle.fill" : "circle")
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(model.displayName).foregroundStyle(.primary)
                                        Text(ByteCountFormatter.string(fromByteCount: model.size, countStyle: .file)).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }.buttonStyle(.plain)
                            Spacer()
                            Menu {
                                Button("名前を変更", systemImage: "pencil") { rename = model; modelName = model.displayName }
                                Button("モデルを削除", systemImage: "trash", role: .destructive) { deletion = model }
                            } label: { Image(systemName: "ellipsis.circle").padding(8) }
                        }
                    }
                    Button { importing = true } label: { Label(store.importing ? "モデルをコピー中…" : "GGUFモデルを追加", systemImage: "plus.circle") }
                        .disabled(store.importing || store.busy)
                    Button("モデルをメモリから解放", systemImage: "memorychip") { store.unloadModel() }.disabled(store.busy)
                    Text("モデル本体以外にコンテキスト・GPUバッファのメモリも必要です。利用可能メモリの90%以上のモデルは安全のため読み込みません。モデルごとの実機速度・最大サイズは未計測です。").font(.caption).foregroundStyle(.secondary)
                }.disabled(store.busy)

                Section("推論") {
                    Toggle("Metal GPUを使用", isOn: $store.settings.useMetal)
                    Toggle("大きいモデルのメモリ警告を表示", isOn: $store.settings.showMemoryWarning)
                    Picker("CPUスレッド数", selection: $store.settings.nThreads) {
                        ForEach([1, 2, 4, 6, 8, 10], id: \.self) { Text("\($0) コア").tag($0) }
                    }
                    Picker("コンテキスト長", selection: $store.settings.contextLength) {
                        ForEach([2048, 4096, 8192, 16384], id: \.self) { Text("\($0) トークン").tag($0) }
                    }
                    Picker("最大出力", selection: $store.settings.maxTokens) {
                        ForEach([256, 512, 1024, 2048], id: \.self) { Text("\($0) トークン").tag($0) }
                    }
                    VStack(alignment: .leading) {
                        Text(String(format: "創造性（Temperature） %.2f", store.settings.temperature))
                        Slider(value: $store.settings.temperature, in: 0...1.5, step: 0.05)
                    }
                    Text("この端末の利用可能CPU: \(ProcessInfo.processInfo.activeProcessorCount)コア。指定数は実際のコア数以内に制限します。M4 iPad Proは構成により9/10コアです。10スレッドが常に最速とは限らないため比較してください。MetalはGPU推論に使用し、Neural EngineやJITによる推論高速化は行いません。").font(.caption).foregroundStyle(.secondary)
                }.disabled(store.busy)

                Section {
                    Label("外国語の説明は生成後に日本語へ自動翻訳", systemImage: "character.bubble")
                    Text("コード・URLは保持します。翻訳品質はモデルの日本語能力に依存します。長文資料は分割要約し、数値・結論・決定事項を優先します。").font(.caption).foregroundStyle(.secondary)
                } header: { Text("日本語と要約") }

                Section("カスタム指示") {
                    TextEditor(text: $store.settings.systemPrompt).frame(minHeight: 100)
                        .accessibilityLabel("カスタム指示")
                }
                Section("メモリ（自分で登録した情報）") {
                    TextEditor(text: $store.settings.memory).frame(minHeight: 80).accessibilityLabel("メモリ")
                    Text("すべての会話の参考情報になります。不要な内容はここで編集・削除できます。").font(.caption).foregroundStyle(.secondary)
                }
                appearanceSection
                Section("JIT・デバッガ") { NavigationLink { DebuggerScreen() } label: { Label("内蔵デバッガを設定", systemImage: "ant") } }
                Section("データ") {
                    ShareLink(item: backup, preview: SharePreview("Kernelチャットバックアップ")) { Label("履歴をJSONで書き出す", systemImage: "square.and.arrow.up") }
                    Button("すべてのチャットを削除", role: .destructive) { clearHistory = true }.disabled(store.busy)
                    Text("会話・モデル・メモリはこのiPadに保存されます。一時チャットは履歴に保存しません。API利用時は入力と指示・メモリ・添付抽出テキストが設定先へ送信されます。").font(.caption).foregroundStyle(.secondary)
                }
                Section("Kernel 10 · Rebuild") {
                    Link("GitHub・ソースコード", destination: URL(string: "https://github.com/d51youkun/Kernel")!)
                    Link("IPAリリース", destination: URL(string: "https://github.com/d51youkun/Kernel/releases")!)
                    Text("実装: ローカル/APIチャット、カスタム指示、手動メモリ、履歴検索、プロジェクト、編集、再生成、分岐、ファイル保存、HTML/JSプレビュー・Console、APIトークン連携、GitHubコミット、Cloudflare Worker公開、ショートカット起動、ウィジェット。未実装: ChatGPT独自のGPTs・Deep Research・画像/動画生成・リアルタイム音声会話・自動メモリ・Google OAuthログイン画面。PDFはテキスト抽出、画像はOCRです。APIトークン連携はOAuthログインではありません。").font(.caption).foregroundStyle(.secondary)
                    Text("App ID: com.kernel.app.K5PVDY39NR").font(.caption.monospaced())
                }
            }
            .navigationTitle("設定")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { store.persist(); store.showSettings = false } } }
            .onDisappear { store.persist() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                switch result { case .success(let urls): store.importModels(urls); case .failure(let error): store.error = error.localizedDescription }
            }
            .alert("モデル名を変更", isPresented: Binding(get: { rename != nil }, set: { if !$0 { rename = nil } })) {
                TextField("表示名", text: $modelName)
                Button("保存") { if let rename { store.renameModel(rename, name: modelName) }; rename = nil }
                Button("キャンセル", role: .cancel) { rename = nil }
            }
            .confirmationDialog("モデルファイルを削除しますか？", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) {
                Button("削除", role: .destructive) { if let deletion { Task { await store.deleteModel(deletion) } }; deletion = nil }
                Button("キャンセル", role: .cancel) { deletion = nil }
            }
            .confirmationDialog("すべてのチャットを削除しますか？", isPresented: $clearHistory, titleVisibility: .visible) {
                Button("すべて削除", role: .destructive) { store.conversations = []; store.selectedID = nil; store.persist() }
            }
        }
    }
    private var appearanceSection: some View {
        Section("表示・音声") {
            Picker("外観", selection: $store.settings.appearance) {
                Text("システム").tag("system")
                Text("ライト").tag("light")
                Text("ダーク").tag("dark")
            }
            Toggle("回答を読み上げ", isOn: $store.settings.readAloud)
            Text("音声入力は日本語オンデバイス認識対応時に利用できます。").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var backup: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(store.conversations)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}

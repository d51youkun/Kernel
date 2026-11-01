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
                }.disabled(store.busy)

                Section("推論") {
                    Toggle("Metal GPUを使用", isOn: $store.settings.useMetal)
                    Picker("CPUスレッド数", selection: $store.settings.nThreads) {
                        ForEach([1, 2, 4, 6], id: \.self) { Text("\($0) コア").tag($0) }
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
                    Text("CPUスレッドはMetal OFF時またはCPUオフロード層で使用されます。最大6コアを推奨。設定変更は次の生成から反映されます。").font(.caption).foregroundStyle(.secondary)
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
                    Text("会話・モデル・メモリはこのiPadに保存されます。一時チャットは履歴に保存しません。").font(.caption).foregroundStyle(.secondary)
                }
                Section("Kernel 2.0") {
                    Link("GitHub・ソースコード", destination: URL(string: "https://github.com/d51youkun/Kernel")!)
                    Link("IPAリリース", destination: URL(string: "https://github.com/d51youkun/Kernel/releases")!)
                    Text("ローカル対応: チャット・履歴検索・プロジェクト・編集・再生成・分岐・共有・読み上げ・PDF/テキスト要約・画像OCR。クラウド検索、画像/動画生成、視覚モデル、コード実行、OpenAIのGPTs/連携サービスは搭載していません。").font(.caption).foregroundStyle(.secondary)
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
        }.frame(minWidth: 500, minHeight: 600)
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

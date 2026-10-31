// SettingsView.swift
// 設定画面 (モデル管理 / 生成パラメータ / 日本語設定 / JIT)

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var chatVM: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var renamingModel: ModelEntry?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Form {
                modelSection
                parametersSection
                languageSection
                jitSection
                infoSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                do {
                    try modelManager.importModel(from: url)
                } catch {
                    modelManager.scanAndReconcile()
                }
            }
        }
        .alert("モデル名を変更", isPresented: Binding(
            get: { renamingModel != nil },
            set: { if !$0 { renamingModel = nil } })) {
            TextField("名前", text: $renameText)
            Button("保存") {
                if let model = renamingModel {
                    modelManager.rename(model, to: renameText)
                }
                renamingModel = nil
            }
            Button("キャンセル", role: .cancel) { renamingModel = nil }
        }
    }

    // ── モデル ─────────────────────────────────

    private var modelSection: some View {
        Section {
            ForEach(modelManager.models) { model in
                HStack {
                    Image(systemName: modelManager.selectedModel?.id == model.id
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading) {
                        Text(model.displayName)
                        Text(model.fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        Button {
                            modelManager.selectedModel = model
                        } label: { Label("選択", systemImage: "checkmark") }
                        Button {
                            renamingModel = model
                            renameText = model.displayName
                        } label: { Label("名前変更", systemImage: "pencil") }
                        Button(role: .destructive) {
                            modelManager.delete(model)
                        } label: { Label("削除", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }

            Button {
                showImporter = true
            } label: {
                Label("GGUFモデルを追加", systemImage: "plus.circle")
            }

            Text("Documents/Models/ に置いたGGUFファイルは自動で認識されます (ファイルアプリからも追加可能)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("モデル")
        }
    }

    // ── 生成パラメータ ─────────────────────────

    private var parametersSection: some View {
        Section {
            HStack {
                Text("温度")
                Spacer()
                Text(String(format: "%.2f", settings.temperature))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settings.temperature, in: 0...2, step: 0.05)

            HStack {
                Text("Top-P")
                Spacer()
                Text(String(format: "%.2f", settings.topP))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settings.topP, in: 0.05...1, step: 0.05)

            Stepper("Top-K: \(settings.topK)", value: $settings.topK, in: 1...200, step: 5)
            Stepper("最大出力トークン: \(settings.maxNewTokens)",
                    value: $settings.maxNewTokens, in: 128...4096, step: 128)
            Stepper("コンテキスト長: \(settings.contextLength)",
                    value: $settings.contextLength, in: 1024...32768, step: 1024)
        } header: {
            Text("生成パラメータ")
        } footer: {
            Text("コンテキスト長を変更した場合は次の生成時にモデルが再ロードされます")
        }
    }

    // ── 言語 ───────────────────────────────────

    private var languageSection: some View {
        Section("言語") {
            Toggle("日本語で回答させる", isOn: $settings.forceJapanese)
            Toggle("回答を読み上げる", isOn: $settings.speakResponses)
        }
    }

    // ── JIT ────────────────────────────────────

    private var jitSection: some View {
        Section {
            NavigationLink {
                JITSettingsView()
            } label: {
                Label("JIT設定", systemImage: "bolt.badge.timemachine")
            }
        } header: {
            Text("パフォーマンス")
        } footer: {
            Text("JITを有効にするとGPU推論(Metal)が速くなります")
        }
    }

    // ── 情報 ───────────────────────────────────

    private var infoSection: some View {
        Section("情報") {
            LabeledContent("バージョン",
                           value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")
            if let desc = LlamaService.shared.modelDescription {
                LabeledContent("読み込み済みモデル", value: desc)
            }
            Button(role: .destructive) {
                chatVM.clearAllConversations()
            } label: {
                Text("すべての会話を削除")
            }
        }
    }
}

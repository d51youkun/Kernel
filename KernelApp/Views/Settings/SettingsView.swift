import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                themeSection
                appearanceSection
                behaviorSection
                systemPromptSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var themeSection: some View {
        Section("テーマ") {
            Picker("テーマ", selection: $settings.theme) {
                ForEach(UITheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            Picker("アクセントカラー", selection: $settings.accentColor) {
                ForEach(AccentColorOption.allCases) { color in
                    HStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 20, height: 20)
                        Text(color.rawValue)
                    }
                    .tag(color)
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section("外観") {
            Picker("フォントサイズ", selection: $settings.fontSize) {
                ForEach(FontSizeOption.allCases) { size in
                    Text(size.rawValue).tag(size)
                }
            }

            Picker("メッセージ幅", selection: $settings.messageWidth) {
                ForEach(MessageWidthOption.allCases) { width in
                    Text(width.rawValue).tag(width)
                }
            }

            Toggle("コードハイライト", isOn: $settings.codeHighlight)
            Toggle("Markdownレンダリング", isOn: $settings.renderMarkdown)
            Toggle("タイムスタンプ表示", isOn: $settings.showTimestamps)
        }
    }

    private var behaviorSection: some View {
        Section("動作") {
            Toggle("TTS（読み上げ）", isOn: $settings.ttsEnabled)
            Toggle("ストリーミングアニメーション", isOn: $settings.streamingAnimation)
            Toggle("サイドバー自動折り畳み", isOn: $settings.autoCollapseSidebar)
            Toggle("日本語強制", isOn: $settings.forceJapanese)

            HStack {
                Text("アシスタント名")
                TextField("名前", text: $settings.assistantName)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("アバター絵文字")
                TextField("絵文字", text: $settings.assistantEmoji)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var systemPromptSection: some View {
        Section("システムプロンプト") {
            TextEditor(text: $settings.systemPrompt)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
        }
    }
}

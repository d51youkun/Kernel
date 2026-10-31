// SettingsView.swift
// 全設定画面（テーマ・パーソナライズ・モデル管理・JIT）

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var jit      = JITService.shared
    @Environment(\.themeTokens) var tokens

    @State private var showImporter      = false
    @State private var showRenameAlert   = false
    @State private var renamingModel: ModelEntry?
    @State private var renameText        = ""
    @State private var importError: String?
    @State private var selectedTab: SettingsTab = .appearance

    private let ggufType = UTType(filenameExtension: "gguf") ?? .data

    enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case personalize = "Personalize"
        case models     = "Models"
        case chat       = "Chat"
        case jit        = "JIT"
        case about      = "About"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .appearance:  return "paintbrush.fill"
            case .personalize: return "person.crop.circle.fill"
            case .models:      return "cpu.fill"
            case .chat:        return "bubble.left.and.bubble.right.fill"
            case .jit:         return "bolt.fill"
            case .about:       return "info.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // ── タブサイドバー ──
                settingsTabBar

                Divider()

                // ── コンテンツ ──
                ScrollView {
                    LazyVStack(spacing: 0) {
                        switch selectedTab {
                        case .appearance:  appearanceSection
                        case .personalize: personalizeSection
                        case .models:      modelsSection
                        case .chat:        chatSection
                        case .jit:         jitSection
                        case .about:       aboutSection
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                .background(tokens.appBackground)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { settings.save(); dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [ggufType],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    try modelManager.importModel(from: url)
                    importError = nil
                } catch CocoaError.fileWriteFileExists {
                    importError = "同名のモデルが既に存在します。"
                } catch {
                    importError = error.localizedDescription
                }
            case .failure(let err):
                if (err as NSError).code != NSUserCancelledError {
                    importError = err.localizedDescription
                }
            }
        }
        .alert("Rename Model", isPresented: $showRenameAlert) {
            TextField("Display Name", text: $renameText).autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let m = renamingModel, !renameText.isEmpty {
                    modelManager.rename(m, to: renameText)
                }
            }
        } message: { Text("新しい表示名を入力") }
    }

    // ── タブバー ──────────────────────────────────────

    private var settingsTabBar: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                            .frame(width: 20)
                        Text(tab.rawValue)
                            .font(.subheadline)
                        Spacer()
                    }
                    .foregroundStyle(selectedTab == tab ? settings.accentColor.color : tokens.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        selectedTab == tab
                            ? settings.accentColor.color.opacity(0.12)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            Spacer()
        }
        .frame(width: 180)
        .padding(.top, 8)
        .background(tokens.sidebarBackground)
    }

    // ── Appearance ────────────────────────────────────

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("テーマ")

            // プレビューカード
            HStack(spacing: 16) {
                ForEach(UITheme.allCases) { theme in
                    ThemePreviewCard(
                        theme: theme,
                        isSelected: settings.theme == theme,
                        accent: settings.accentColor.color
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) { settings.theme = theme }
                    }
                }
            }

            Divider()

            sectionHeader("アクセントカラー")
            HStack(spacing: 12) {
                ForEach(AccentColorOption.allCases) { opt in
                    Circle()
                        .fill(opt.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: settings.accentColor == opt ? 2.5 : 0)
                        )
                        .scaleEffect(settings.accentColor == opt ? 1.15 : 1.0)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25)) { settings.accentColor = opt }
                        }
                }
            }

            Divider()

            sectionHeader("フォントサイズ")
            Picker("Font Size", selection: $settings.fontSize) {
                ForEach(FontSizeOption.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.segmented)

            Divider()

            sectionHeader("メッセージ幅")
            Picker("Width", selection: $settings.messageWidth) {
                ForEach(MessageWidthOption.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // ── Personalize ───────────────────────────────────

    private var personalizeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("チャットアイコン")
            Text("チャット画面のアシスタントアバターに使う絵文字を選べます。")
                .font(.caption)
                .foregroundStyle(tokens.textSecondary)

            HStack(spacing: 12) {
                // 現在のアイコンプレビュー
                ZStack {
                    Circle()
                        .fill(tokens.surface)
                        .frame(width: 60, height: 60)
                    if let emoji = settings.chatIconEmoji {
                        Text(emoji).font(.system(size: 34))
                    } else {
                        Image(systemName: "brain.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(settings.accentColor.color)
                    }
                }
                .overlay(Circle().stroke(tokens.separator, lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text("絵文字アイコン")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(tokens.textPrimary)
                    Text("タップして選択、クリアでデフォルトアイコンに戻ります")
                        .font(.caption)
                        .foregroundStyle(tokens.textSecondary)
                }
            }

            // 絵文字グリッド
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 8),
                spacing: 10
            ) {
                ForEach(iconEmojiOptions, id: \.self) { emoji in
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            settings.chatIconEmoji = emoji
                        }
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(width: 44, height: 44)
                            .background(
                                settings.chatIconEmoji == emoji
                                    ? settings.accentColor.color.opacity(0.15)
                                    : tokens.surface
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        settings.chatIconEmoji == emoji
                                            ? settings.accentColor.color
                                            : tokens.separator,
                                        lineWidth: settings.chatIconEmoji == emoji ? 1.5 : 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if settings.chatIconEmoji != nil {
                Button {
                    withAnimation { settings.chatIconEmoji = nil }
                } label: {
                    Label("デフォルトに戻す", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundStyle(tokens.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            sectionHeader("システムプロンプト")
            Text("AIの振る舞いを追加定義します。日本語強制は自動で適用されます。")
                .font(.caption)
                .foregroundStyle(tokens.textSecondary)

            ZStack(alignment: .topLeading) {
                if settings.systemPrompt.isEmpty {
                    Text("例: 簡潔に答えてください。箇条書きを活用してください。")
                        .font(.callout)
                        .foregroundStyle(tokens.textSecondary.opacity(0.5))
                        .padding(12)
                }
                TextEditor(text: $settings.systemPrompt)
                    .font(.callout)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
            .background(tokens.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tokens.inputBorder, lineWidth: 1)
            )
        }
    }

    private let iconEmojiOptions = [
        "🤖","🧠","💡","🦊","⚡","🌟","🎯","🔮",
        "🤯","🦋","🐬","🦅","🌊","🔥","❄️","🌙",
        "🎪","🎨","🎭","🚀","🛸","🌈","🍀","💎"
    ]

    // ── Models ────────────────────────────────────────

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionHeader("Installed Models")
                Spacer()
                Button {
                    showImporter = true
                } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                        .font(.callout)
                        .foregroundStyle(settings.accentColor.color)
                }
                .buttonStyle(.plain)
            }

            if modelManager.models.isEmpty {
                Button { showImporter = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(settings.accentColor.color)
                        Text("GGUFモデルを追加")
                            .foregroundStyle(settings.accentColor.color)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(tokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    ForEach(modelManager.models) { model in
                        ModelRowCard(
                            model: model,
                            isSelected: modelManager.selectedModel?.id == model.id,
                            tokens: tokens,
                            accentColor: settings.accentColor.color,
                            onSelect: { modelManager.selectedModel = model },
                            onRename: {
                                renamingModel = model
                                renameText    = model.displayName
                                showRenameAlert = true
                            },
                            onDelete: {
                                withAnimation { modelManager.delete(model) }
                            }
                        )
                    }
                }
            }

            if let err = importError {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                .padding(10)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("GGUFファイルは「追加」ボタンかFiles.app経由でDocuments/Modelsに配置してください。")
                .font(.caption)
                .foregroundStyle(tokens.textSecondary)
        }
    }

    // ── Chat ─────────────────────────────────────────

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("言語")
            toggleRow("日本語で回答する（推奨）", icon: "globe", value: $settings.forceJapanese)
            Text("固有名詞（YouTube、Swiftなど）はそのまま表示されます。")
                .font(.caption)
                .foregroundStyle(tokens.textSecondary)
                .padding(.horizontal, 4)

            Divider()

            sectionHeader("表示")
            toggleRow("Markdownレンダリング", icon: "text.badge.star", value: $settings.renderMarkdown)
            toggleRow("コードハイライト",     icon: "chevron.left.forwardslash.chevron.right", value: $settings.codeHighlight)
            toggleRow("タイムスタンプ表示",   icon: "clock", value: $settings.showTimestamps)

            Divider()

            sectionHeader("音声")
            toggleRow("テキスト読み上げ (TTS)", icon: "speaker.wave.2.fill", value: $settings.ttsEnabled)

            Divider()

            sectionHeader("キーボードショートカット")
            Group {
                shortcutRow("送信",         "Return")
                shortcutRow("新規チャット",  "⌘N")
                shortcutRow("停止",         "Esc")
                shortcutRow("検索",         "⌘F")
                shortcutRow("エクスポート",  "⌘E")
                shortcutRow("設定",         "⌘,")
            }
            .padding(.horizontal, 4)
        }
    }

    // ── JIT ──────────────────────────────────────────

    private var jitSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            selfJITCard
        }
    }

    private var selfJITCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: jit.status == .enabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title2)
                    .foregroundStyle(jit.status == .enabled ? .green : settings.accentColor.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("JIT 有効化")
                        .font(.headline)
                        .foregroundStyle(tokens.textPrimary)
                    Text(jitStatusDescription)
                        .font(.caption)
                        .foregroundStyle(tokens.textSecondary)
                }
                Spacer()
                if jit.status == .enabling { ProgressView().scaleEffect(0.9) }
            }

            if jit.status != .enabled {
                Button {
                    jit.enableJIT()
                } label: {
                    Label("JITを有効にする", systemImage: "bolt.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.accentColor.color)
                .disabled(jit.status == .enabling)

                // ペアリングファイル有無
                if jit.hasPairingFile {
                    Label("ペアリングファイル: \(jit.pairingFileName ?? "読み込み済み")",
                          systemImage: "doc.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } else {
                Label("JIT有効 — 推論が最速モードで動作中", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
            }

            // ペアリングファイルインポート
            PairingFileImportButton(jit: jit, tokens: tokens, accentColor: settings.accentColor.color)
        }
        .padding(16)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(jit.status == .enabled ? Color.green.opacity(0.4) : tokens.separator, lineWidth: 1)
        )
    }

    private var jitStatusDescription: String {
        switch jit.status {
        case .enabled:       return "JITが有効です。llama.cppが最高速で動作します。"
        case .enabling:      return "有効化中…"
        case .failed(let m): return m
        case .notEnabled:    return "セルフJIT → StikJIT → StikDebug → SideStore の順に試します。"
        case .unknown:       return "JITの状態を確認中…"
        }
    }

    // ── About ────────────────────────────────────────

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.1, green: 0.1, blue: 0.4),
                                    Color(red: 0.2, green: 0.1, blue: 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    Text("K")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kernel")
                        .font(.title2.bold())
                        .foregroundStyle(tokens.textPrimary)
                    Text("Local AI for iPad")
                        .font(.callout)
                        .foregroundStyle(tokens.textSecondary)
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundStyle(tokens.textSecondary)
                }
            }
            .padding()
            .background(tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 8) {
                infoRow("Backend", value: "llama.cpp (Metal)")
                infoRow("JIT Status", value: jitStatusText)
                infoRow("Theme", value: settings.theme.rawValue)
            }
            .padding()
            .background(tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var jitStatusText: String {
        switch jit.status {
        case .enabled:  return "Enabled ✓"
        case .enabling: return "Enabling…"
        case .failed:   return "Failed"
        default:        return "Disabled"
        }
    }

    // ── ヘルパービュー ────────────────────────────────

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(tokens.textPrimary)
    }

    private func toggleRow(_ label: String, icon: String, value: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(settings.accentColor.color)
                .frame(width: 24)
            Text(label)
                .font(.body)
                .foregroundStyle(tokens.textPrimary)
            Spacer()
            Toggle("", isOn: value)
                .labelsHidden()
                .tint(settings.accentColor.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func shortcutRow(_ label: String, _ shortcut: String) -> some View {
        HStack {
            Text(label).font(.body).foregroundStyle(tokens.textPrimary)
            Spacer()
            Text(shortcut)
                .font(.caption.weight(.medium))
                .foregroundStyle(tokens.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.vertical, 6)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.callout).foregroundStyle(tokens.textSecondary)
            Spacer()
            Text(value).font(.callout).foregroundStyle(tokens.textPrimary)
        }
    }
}

// ── ペアリングファイルインポートボタン ──────────────────

struct PairingFileImportButton: View {
    @ObservedObject var jit: JITService
    let tokens: ThemeTokens
    let accentColor: Color

    @State private var showFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ペアリングファイル (任意)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tokens.textSecondary)
            Text("iDevice Pair で生成した .mobiledevicepairing をインポートするとVPN不要でJITが使えます。")
                .font(.caption2)
                .foregroundStyle(tokens.textSecondary)

            Button {
                showFilePicker = true
            } label: {
                Label(
                    jit.hasPairingFile ? "ペアリングファイルを更新" : "ペアリングファイルをインポート",
                    systemImage: "doc.badge.plus"
                )
                .font(.caption)
                .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                jit.importPairingFile(from: url)
            }
        }
    }
}

private struct ThemePreviewCard: View {
    let theme: UITheme
    let isSelected: Bool
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme == .chatGPT ? Color(.systemBackground) : Color(red: 0.11, green: 0.11, blue: 0.13))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? accent : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )

                // ミニプレビュー
                VStack(spacing: 4) {
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(accent)
                            .frame(width: 50, height: 10)
                    }
                    HStack {
                        Capsule()
                            .fill(theme == .chatGPT ? Color(.systemGray5) : Color(red: 0.22, green: 0.22, blue: 0.26))
                            .frame(width: 60, height: 10)
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)

                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(accent)
                                .font(.caption)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }

            Text(theme.rawValue)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? accent : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// ── モデル行カード ────────────────────────────────────

private struct ModelRowCard: View {
    let model: ModelEntry
    let isSelected: Bool
    let tokens: ThemeTokens
    let accentColor: Color
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? accentColor : tokens.textSecondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "cpu.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(tokens.textPrimary)
                    .lineLimit(1)
                Text("\(model.fileName) · \(model.fileSizeString)")
                    .font(.caption2)
                    .foregroundStyle(tokens.textSecondary)
            }

            Spacer()

            Button(action: onRename) {
                Image(systemName: "pencil")
                    .foregroundStyle(tokens.textSecondary)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            isSelected
                ? accentColor.opacity(0.08)
                : tokens.surface
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? accentColor.opacity(0.3) : tokens.separator, lineWidth: 1)
        )
    }
}

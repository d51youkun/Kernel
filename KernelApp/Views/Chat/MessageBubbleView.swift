// MessageBubbleView.swift
// テーマ対応メッセージバブル（ChatGPT / ClaudeCode スタイル）

import SwiftUI

// ── メッセージの「種類」を判定するヘルパー ───────────────

private func detectContentType(_ text: String) -> MessageContentType {
    let lines = text.components(separatedBy: "\n")
    let codeFences = lines.filter { $0.hasPrefix("```") }.count
    let bulletLines = lines.filter {
        let t = $0.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("• ") ||
               t.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
    }.count
    // 日本語は単語分割でカウントできないので文字数で判定
    let charCount = text.count

    if codeFences >= 2 { return .code }
    if bulletLines >= 3 { return .list }
    if charCount > 600 { return .long }
    return .normal
}

enum MessageContentType {
    case normal  // 短い通常テキスト
    case long    // 長文 → 要約カード付き
    case code    // コードブロックあり
    case list    // 箇条書き多め
}

// ── マークダウン記号を除去 ──────────────────────────────

private func stripMarkdown(_ s: String) -> String {
    var result = s
    // コードブロックは完全に除去
    result = result.replacingOccurrences(
        of: #"```[^\n]*\n[\s\S]*?```"#,
        with: " [コード] ",
        options: .regularExpression
    )
    // インラインコード
    result = result.replacingOccurrences(
        of: #"`([^`]+)`"#,
        with: "$1",
        options: .regularExpression
    )
    // 太字・斜体
    result = result.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
    result = result.replacingOccurrences(of: #"__(.+?)__"#,   with: "$1", options: .regularExpression)
    result = result.replacingOccurrences(of: #"\*(.+?)\*"#,   with: "$1", options: .regularExpression)
    result = result.replacingOccurrences(of: #"_([^_\n]+)_"#, with: "$1", options: .regularExpression)
    // 見出し記号
    result = result.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
    // リンク
    result = result.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
    // リストマーカー
    result = result.replacingOccurrences(of: #"^[\-\*\+]\s+"#, with: "", options: .regularExpression)
    result = result.replacingOccurrences(of: #"^\d+\.\s+"#, with: "", options: .regularExpression)
    // 引用記号
    result = result.replacingOccurrences(of: #"^>\s+"#, with: "", options: .regularExpression)
    // 水平線
    result = result.replacingOccurrences(of: #"^---+$"#, with: "", options: .regularExpression)
    // 取り消し線
    result = result.replacingOccurrences(of: #"~~(.+?)~~"#, with: "$1", options: .regularExpression)
    // 余分な空白
    result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

// ── 要約生成 ────────────────────────────────────────────

private func makeSummary(from text: String) -> String {
    let stripped = stripMarkdown(text)

    // 文単位で分割（。！？.!? で区切る）
    let sentences = stripped
        .components(separatedBy: "\n")
        .flatMap { line -> [String] in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return [] }
            // 文末記号で分割
            var parts: [String] = []
            var current = ""
            for ch in trimmed {
                current.append(ch)
                if ch == "。" || ch == "！" || ch == "？" || ch == "." || ch == "!" || ch == "?" {
                    parts.append(current)
                    current = ""
                }
            }
            if !current.isEmpty { parts.append(current) }
            return parts
        }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    // 最初の2〜3文を結合（最大200文字）
    var summary = ""
    var count = 0
    for sentence in sentences {
        if count >= 3 { break }
        if summary.count + sentence.count > 200 && !summary.isEmpty { break }
        summary += (summary.isEmpty ? "" : "") + sentence
        count += 1
    }

    // 200文字超で切り詰め
    if summary.count > 200 {
        summary = String(summary.prefix(200))
        // 途中で切れた場合は省略記号
        if summary.last != "。" && summary.last != "！" && summary.last != "？" {
            summary += "…"
        }
    }

    return summary.isEmpty ? String(stripped.prefix(200)) + "…" : summary
}

// ── MessageBubbleView ─────────────────────────────────

struct MessageBubbleView: View {
    let message: Message
    let isLastAndGenerating: Bool

    @Environment(\.themeTokens) var tokens
    @EnvironmentObject var settings: AppSettings

    var onCopy: () -> Void              = {}
    var onEdit: () -> Void              = {}
    var onRegenerate: () -> Void        = {}
    var onSpeak: () -> Void             = {}
    var onDownloadHTML: (URL) -> Void   = { _ in }
    var onFeedback: (Message.Feedback) -> Void = { _ in }

    @State private var showActions  = false
    @State private var showCopied   = false
    @State private var expanded     = false   // 長文の展開状態

    private var isUser: Bool { message.role == .user }
    private var fontSize: CGFloat { settings.fontSize.bodySize }
    private var contentType: MessageContentType {
        isLastAndGenerating ? .normal : detectContentType(message.content)
    }

    var body: some View {
        Group {
            switch settings.theme {
            case .chatGPT:    chatGPTLayout
            case .claudeCode: claudeCodeLayout
            }
        }
        .contextMenu { contextMenuItems }
    }

    // ── ChatGPT スタイル (iPad) ───────────────────────

    @ViewBuilder
    private var chatGPTLayout: some View {
        if isUser {
            // ユーザー: 右寄せバブル（ChatGPT風: グレー背景）
            HStack(alignment: .top) {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 6) {
                    if message.isEdited {
                        Text("編集済み")
                            .font(.caption2)
                            .foregroundStyle(tokens.textSecondary)
                    }
                    userBubble
                    if showActions { userActionBar }
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { showActions.toggle() } }
        } else {
            // アシスタント: 全幅（カード背景なし、ChatGPT iPad風）
            VStack(alignment: .leading, spacing: 0) {
                assistantCard
                if showActions { assistantActionBar.padding(.horizontal, 16).padding(.bottom, 8) }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { showActions.toggle() } }
        }
    }

    // ── Claude Code スタイル ──────────────────────────

    @ViewBuilder
    private var claudeCodeLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isUser {
                HStack(alignment: .top) {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            if message.isEdited {
                                Text("編集済み")
                                    .font(.caption2)
                                    .foregroundStyle(tokens.textSecondary)
                            }
                            Text("You")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tokens.textSecondary)
                        }
                        userBubble
                        if showActions { userActionBar }
                    }
                    .padding(.trailing, 16)
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    avatarView.padding(.leading, 16)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Kernel")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tokens.avatarFill)
                        }
                        assistantContentBlock
                        if showActions { assistantActionBar }
                    }
                    Spacer(minLength: 16)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { showActions.toggle() } }
    }

    // ── ユーザーバブル ───────────────────────────────

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if !message.attachments.isEmpty { userAttachmentsView }
            if !message.content.isEmpty {
                Group {
                    if message.content.isEmpty {
                        Text("　")
                    } else {
                        Text(message.content)
                            .textSelection(.enabled)
                            .font(.system(size: fontSize))
                    }
                }
                .foregroundStyle(tokens.textOnUser)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(tokens.bubbleUser)
                .clipShape(RoundedRectangle(cornerRadius: tokens.bubbleCorner, style: .continuous))
            }
        }
    }

    // ── アシスタントカード（ChatGPT iPad風 全幅・背景なし） ───

    @ViewBuilder
    private var assistantCard: some View {
        if message.content.isEmpty && isLastAndGenerating {
            // タイピング中
            HStack(spacing: 10) {
                avatarView
                TypingIndicatorView(tokens: tokens)
                    .padding(.vertical, 8)
                Spacer()
            }
            .padding(.horizontal, 16)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // ヘッダー行（アバター + 名前）
                HStack(spacing: 10) {
                    avatarView
                    Text(settings.assistantName.isEmpty ? "Kernel" : settings.assistantName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tokens.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)

                // コンテンツ
                assistantContentBlock
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                // トークン統計（最後のアシスタントメッセージのみ）
                if let tokens = message.estimatedTokens, let dur = message.generationDuration,
                   !isLastAndGenerating, tokens > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt")
                            .font(.caption2)
                        Text("約\(tokens)トークン · \(String(format: "%.1f", dur))秒 · \(String(format: "%.1f", Double(tokens) / max(dur, 0.1))) tok/s")
                            .font(.caption2)
                    }
                    .foregroundStyle(tokens.textSecondary.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // ダウンロード可能なファイルがあれば表示
                if !message.content.isEmpty {
                    downloadActionsRow
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            // ChatGPT iPad風: カード背景なし、シンプルな全幅レイアウト
        }
    }

    // ── アシスタントコンテンツブロック（要約対応） ──────────

    @ViewBuilder
    private var assistantContentBlock: some View {
        switch contentType {
        case .long where !expanded:
            // 要約 + 展開ボタン
            VStack(alignment: .leading, spacing: 10) {
                // 要約テキスト
                summaryCard

                // 展開ボタン
                Button {
                    withAnimation(.spring(response: 0.35)) { expanded = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.below.photo.fill")
                            .font(.caption)
                        Text("全文を表示")
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(settings.accentColor.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(settings.accentColor.color.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

        default:
            // 通常表示（全文 or 展開後）
            VStack(alignment: .leading, spacing: 8) {
                if expanded {
                    // 折りたたみボタン
                    Button {
                        withAnimation(.spring(response: 0.35)) { expanded = false }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                            Text("要約に戻る")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(tokens.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tokens.surface)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if settings.renderMarkdown {
                    MarkdownView(
                        text: message.content,
                        fontSize: fontSize,
                        tokens: tokens,
                        renderMarkdown: true
                    )
                } else {
                    Text(message.content)
                        .font(.system(size: fontSize,
                                      design: settings.theme == .claudeCode ? .monospaced : .default))
                        .textSelection(.enabled)
                        .foregroundStyle(tokens.textPrimary)
                }
            }
        }
    }

    // ── 要約カード ─────────────────────────────────────

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 種類バッジ
            HStack(spacing: 6) {
                Image(systemName: contentTypeBadgeIcon)
                    .font(.caption.weight(.semibold))
                Text(contentTypeBadgeLabel)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(settings.accentColor.color)

            // 要約テキスト
            Text(makeSummary(from: message.content))
                .font(.system(size: fontSize))
                .foregroundStyle(tokens.textPrimary)
                .textSelection(.enabled)

            // コードプレビュー（コードブロックがあれば）
            if contentType == .code {
                codePreviewStrip
            }
        }
    }

    private var contentTypeBadgeIcon: String {
        switch contentType {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .list: return "list.bullet"
        default:    return "doc.text.fill"
        }
    }

    private var contentTypeBadgeLabel: String {
        switch contentType {
        case .code: return "コードを含む回答"
        case .list: return "リスト形式の回答"
        default:    return "長い回答"
        }
    }

    // コードブロックの先頭をプレビュー表示
    private var codePreviewStrip: some View {
        let lines = message.content.components(separatedBy: "\n")
        let start = lines.firstIndex(where: { $0.hasPrefix("```") }) ?? 0
        let preview = lines.dropFirst(start + 1).prefix(3).joined(separator: "\n")
        return Text(preview.isEmpty ? "// コードブロック" : preview)
            .font(.system(size: fontSize - 2, design: .monospaced))
            .foregroundStyle(tokens.textSecondary)
            .lineLimit(3)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tokens.codeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // ── ダウンロードアクション ────────────────────────

    @ViewBuilder
    private var downloadActionsRow: some View {
        let hasHTML = message.content.contains("```html") || message.content.contains("```HTML")
        let hasCodeBlock = message.content.contains("```")

        if hasHTML || hasCodeBlock {
            HStack(spacing: 8) {
                if hasHTML {
                    Button {
                        // HTML抽出してシート表示
                        if let re = try? NSRegularExpression(pattern: "```(?:html)?\\s*\\n([\\s\\S]*?)```",
                                                              options: .caseInsensitive),
                           let m = re.firstMatch(in: message.content,
                                                   range: NSRange(message.content.startIndex..., in: message.content)),
                           m.numberOfRanges > 1,
                           let r = Range(m.range(at: 1), in: message.content) {
                            let html = String(message.content[r])
                            let url = FileManager.default.temporaryDirectory
                                .appendingPathComponent("preview_\(message.id.uuidString).html")
                            try? html.write(to: url, atomically: true, encoding: .utf8)
                            onDownloadHTML(url)
                        }
                    } label: {
                        Label("HTMLをダウンロード", systemImage: "arrow.down.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // コードをテキストファイルとして保存
                if hasCodeBlock {
                    let txtURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("code_\(message.id.uuidString).txt")
                    let _ = (try? message.content.write(to: txtURL, atomically: true, encoding: .utf8))

                    ShareLink(item: txtURL,
                              subject: Text("コード"),
                              message: Text("Kernelで生成したコード")) {
                        Label("ファイルとして保存", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(tokens.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(tokens.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(tokens.separator, lineWidth: 0.5))
                    }
                }
            }
        }
    }

    // ── 添付ファイル表示（ユーザーメッセージ） ───────────

    @ViewBuilder
    private var userAttachmentsView: some View {
        if !message.attachments.isEmpty {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(message.attachments) { att in
                    HStack(spacing: 6) {
                        Image(systemName: att.displayIcon)
                            .font(.caption)
                            .foregroundStyle(tokens.textOnUser.opacity(0.8))
                        Text(att.fileName)
                            .font(.caption)
                            .foregroundStyle(tokens.textOnUser)
                            .lineLimit(1)
                        Text(att.humanSize)
                            .font(.caption2)
                            .foregroundStyle(tokens.textOnUser.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // ── アバター ──────────────────────────────────────

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(tokens.avatarFill)
                .frame(width: 28, height: 28)
            // カスタム絵文字アイコン（あれば）
            if let iconEmoji = settings.chatIconEmoji {
                Text(iconEmoji)
                    .font(.system(size: 15))
            } else {
                Image(systemName: "brain.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // ── アクションバー ────────────────────────────────

    private var userActionBar: some View {
        HStack(spacing: 6) {
            actionIcon(showCopied ? "checkmark" : "doc.on.doc",
                       tint: showCopied ? .green : nil) {
                UIPasteboard.general.string = message.content
                withAnimation { showCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showCopied = false }
                }
            }
            actionIcon("pencil") { onEdit() }
        }
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var assistantActionBar: some View {
        HStack(spacing: 6) {
            // コピー
            actionIcon(showCopied ? "checkmark" : "doc.on.doc",
                       tint: showCopied ? .green : nil) {
                UIPasteboard.general.string = message.content
                withAnimation { showCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showCopied = false }
                }
            }
            // 読み上げ
            if settings.ttsEnabled {
                actionIcon("speaker.wave.2") { onSpeak() }
            }
            // 再生成
            actionIcon("arrow.counterclockwise") { onRegenerate() }
            // フィードバック: 👍
            actionIcon(message.feedback == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup",
                       tint: message.feedback == .thumbsUp ? settings.accentColor.color : nil) {
                onFeedback(.thumbsUp)
            }
            // フィードバック: 👎
            actionIcon(message.feedback == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                       tint: message.feedback == .thumbsDown ? .orange : nil) {
                onFeedback(.thumbsDown)
            }
        }
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // ChatGPT風アイコンボタン（ラベルなし、シンプル）
    private func actionIcon(_ icon: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(tint ?? tokens.textSecondary)
                .frame(width: 30, height: 30)
                .background(tokens.surface.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // テキスト付きチップ（旧スタイル、Claude Code用）
    private func actionChip(icon: String, label: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption)
            }
            .foregroundStyle(tint ?? tokens.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tokens.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tokens.separator, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // ── コンテキストメニュー ──────────────────────────

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            UIPasteboard.general.string = message.content
        } label: {
            Label("コピー", systemImage: "doc.on.doc")
        }
        if isUser {
            Button { onEdit() } label: {
                Label("編集して再送信", systemImage: "pencil")
            }
        } else {
            Button { onRegenerate() } label: {
                Label("再生成", systemImage: "arrow.counterclockwise")
            }
            if contentType == .long {
                Button {
                    withAnimation { expanded.toggle() }
                } label: {
                    Label(expanded ? "要約を表示" : "全文を表示",
                          systemImage: expanded ? "doc.text" : "text.below.photo.fill")
                }
            }
            if settings.ttsEnabled {
                Button { onSpeak() } label: {
                    Label("読み上げ", systemImage: "speaker.wave.2")
                }
            }
            Divider()
            // フィードバック
            Button { onFeedback(.thumbsUp) } label: {
                Label("良い回答 👍", systemImage: message.feedback == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            Button { onFeedback(.thumbsDown) } label: {
                Label("改善の余地あり 👎", systemImage: message.feedback == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }
        }
    }
}

// ── タイピングインジケータ ────────────────────────────

struct TypingIndicatorView: View {
    let tokens: ThemeTokens
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(tokens.textSecondary.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// ── ウェルカムビュー ─────────────────────────────────

struct WelcomeView: View {
    let modelName: String
    var onSuggestionTap: ((String) -> Void)? = nil
    @Environment(\.themeTokens) var tokens
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tokens.avatarFill.opacity(0.15))
                        .frame(width: 72, height: 72)
                    if let emoji = settings.chatIconEmoji {
                        Text(emoji).font(.system(size: 38))
                    } else {
                        Image(systemName: "brain.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(tokens.avatarFill)
                    }
                }
                VStack(spacing: 4) {
                    Text("何でも聞いてください")
                        .font(.title2.bold())
                        .foregroundStyle(tokens.textPrimary)
                    Text(modelName)
                        .font(.subheadline)
                        .foregroundStyle(tokens.textSecondary)
                        .lineLimit(1)
                }
            }

            if settings.theme == .chatGPT {
                quickPromptGrid
            }
        }
        .padding(32)
        .frame(maxWidth: 600)
    }

    private var quickPromptGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(quickPrompts.enumerated()), id: \.offset) { _, p in
                Button {
                    onSuggestionTap?(p.text)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: p.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(settings.accentColor.color)
                        Text(p.text)
                            .font(.callout)
                            .foregroundStyle(tokens.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tokens.separator, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private let quickPrompts: [(icon: String, text: String)] = [
        ("square.code", "Swiftのコードを書いて"),
        ("list.bullet.rectangle", "タスクを整理して"),
        ("lightbulb", "アイデアを出して"),
        ("character.bubble", "文章を添削して"),
        ("globe", "翻訳して"),
        ("graduationcap", "概念を説明して"),
    ]
}

// ── モデルなしビュー ─────────────────────────────────

struct NoModelView: View {
    @Binding var showSettings: Bool
    @Environment(\.themeTokens) var tokens

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 48))
                .foregroundStyle(tokens.textSecondary)
            Text("モデルがありません")
                .font(.title2.bold())
                .foregroundStyle(tokens.textPrimary)
            Text("設定からGGUFファイルを追加してください。")
                .font(.body)
                .foregroundStyle(tokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("設定を開く") { showSettings = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}

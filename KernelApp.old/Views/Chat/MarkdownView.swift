// MarkdownView.swift
// シンプルなMarkdownレンダラー（コードブロック・インラインコード・太字・箇条書き対応）

import SwiftUI

struct MarkdownView: View {
    let text: String
    let fontSize: CGFloat
    let tokens: ThemeTokens
    let renderMarkdown: Bool

    var body: some View {
        if renderMarkdown {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(parse(text), id: \.id) { block in
                    blockView(block)
                }
            }
        } else {
            Text(text)
                .font(.system(size: fontSize))
                .textSelection(.enabled)
                .foregroundStyle(tokens.textPrimary)
        }
    }

    @ViewBuilder
    private func blockView(_ block: MDBlock) -> some View {
        switch block.kind {
        case .codeBlock(let lang, let code):
            CodeBlockView(language: lang, code: code, tokens: tokens, fontSize: fontSize)
        case .heading(let level, let content):
            headingView(level: level, content: content)
        case .bulletItem(let content):
            HStack(alignment: .top, spacing: 8) {
                Text("•").font(.system(size: fontSize)).foregroundStyle(tokens.textSecondary)
                inlineText(content)
            }
        case .numberedItem(let n, let content):
            HStack(alignment: .top, spacing: 8) {
                Text("\(n).").font(.system(size: fontSize)).foregroundStyle(tokens.textSecondary)
                    .frame(minWidth: 22, alignment: .trailing)
                inlineText(content)
            }
        case .blockquote(let content):
            HStack(spacing: 10) {
                Rectangle()
                    .fill(tokens.separator)
                    .frame(width: 3)
                    .cornerRadius(1.5)
                inlineText(content)
                    .foregroundStyle(tokens.textSecondary)
            }
        case .horizontalRule:
            Divider().background(tokens.separator)
        case .paragraph(let content):
            inlineText(content)
        }
    }

    @ViewBuilder
    private func headingView(level: Int, content: String) -> some View {
        let size: CGFloat = level == 1 ? fontSize + 8 : level == 2 ? fontSize + 5 : fontSize + 2
        let weight: Font.Weight = level <= 2 ? .bold : .semibold
        Text(content)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(tokens.textPrimary)
            .padding(.top, level == 1 ? 8 : 4)
    }

    private func inlineText(_ content: String) -> some View {
        buildInlineText(content)
            .font(.system(size: fontSize))
            .textSelection(.enabled)
    }

    /// インライン装飾（太字・斜体・コード・リンク・取り消し線）をパースして Text を構築
    private func buildInlineText(_ s: String) -> Text {
        guard !s.isEmpty else { return Text("") }

        // 特殊文字の位置を見つけて、次のマーカーまでをプレーンテキストとして出力
        // マーカーが見つからない場合は残り全てを出力して終了
        let specialChars: Set<Character> = ["`", "*", "_", "~", "["]

        var result = Text("")
        var pos = s.startIndex

        while pos < s.endIndex {
            let char = s[pos]

            // インラインコード `code`
            if char == "`" {
                if let endIdx = s.index(pos, offsetBy: 1, limitedBy: s.endIndex),
                   let close = s.range(of: "`", range: endIdx..<s.endIndex) {
                    let code = String(s[endIdx..<close.lowerBound])
                    result = result + Text(code)
                        .font(.system(size: fontSize - 1, design: .monospaced))
                        .foregroundColor(tokens.textCode)
                    pos = close.upperBound
                    continue
                }
            }

            // リンク [text](url)
            if char == "[" {
                if let textClose = s.range(of: "]", range: pos..<s.endIndex),
                   textClose.upperBound < s.endIndex,
                   s[textClose.upperBound] == "(",
                   let urlClose = s.range(of: ")", range: textClose.upperBound..<s.endIndex) {
                    let linkText = String(s[s.index(after: pos)..<textClose.lowerBound])
                    let urlStr = String(s[s.index(after: textClose.upperBound)..<urlClose.lowerBound])
                    result = result + Text(linkText)
                        .foregroundColor(tokens.textCode)
                        .underline()
                    pos = urlClose.upperBound
                    continue
                }
            }

            // 太字 **text** or __text__
            if (char == "*" || char == "_") && s.index(after: pos) < s.endIndex && s[s.index(after: pos)] == char {
                let marker = String(s[pos]) + String(s[pos])
                let afterMarker = s.index(pos, offsetBy: 2, limitedBy: s.endIndex) ?? s.endIndex
                if let close = s.range(of: marker, range: afterMarker..<s.endIndex) {
                    let boldText = String(s[afterMarker..<close.lowerBound])
                    result = result + Text(boldText).bold().foregroundColor(tokens.textPrimary)
                    pos = close.upperBound
                    continue
                }
            }

            // 斜体 *text* or _text_
            if (char == "*" || char == "_") {
                let afterMarker = s.index(after: pos)
                if let close = s.range(of: String(char), range: afterMarker..<s.endIndex) {
                    // 前後が英数字でない場合のみ斜体として扱う（アスタリスク暴発防止）
                    let prevChar = pos > s.startIndex ? s[s.index(before: pos)] : " "
                    let italicText = String(s[afterMarker..<close.lowerBound])
                    if !italicText.isEmpty && !italicText.contains(char) {
                        let _ = prevChar // 参照を保持
                        result = result + Text(italicText).italic().foregroundColor(tokens.textPrimary)
                        pos = close.upperBound
                        continue
                    }
                }
            }

            // 取り消し線 ~~text~~
            if char == "~" && s.index(after: pos) < s.endIndex && s[s.index(after: pos)] == "~" {
                let afterMarker = s.index(pos, offsetBy: 2, limitedBy: s.endIndex) ?? s.endIndex
                if let close = s.range(of: "~~", range: afterMarker..<s.endIndex) {
                    let strikeText = String(s[afterMarker..<close.lowerBound])
                    result = result + Text(strikeText).strikethrough().foregroundColor(tokens.textSecondary)
                    pos = close.upperBound
                    continue
                }
            }

            // マーカー以外の文字: 次のマーカーまでを一括出力
            if !specialChars.contains(char) {
                // 次の特殊文字を探す
                var nextSpecial = s.index(after: pos)
                while nextSpecial < s.endIndex && !specialChars.contains(s[nextSpecial]) {
                    nextSpecial = s.index(after: nextSpecial)
                }
                let plain = String(s[pos..<nextSpecial])
                result = result + Text(plain).foregroundColor(tokens.textPrimary)
                pos = nextSpecial
                continue
            }

            // マーカー文字だがマッチしなかった: 1文字出力
            result = result + Text(String(char)).foregroundColor(tokens.textPrimary)
            pos = s.index(after: pos)
        }

        return result
    }
}

// ── コードブロック ────────────────────────────────────

struct CodeBlockView: View {
    let language: String
    let code: String
    let tokens: ThemeTokens
    let fontSize: CGFloat
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー
            HStack {
                if !language.isEmpty {
                    Text(language)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(tokens.textSecondary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(copied ? .green : tokens.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(tokens.surfaceElevated)

            Divider().background(tokens.separator)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .foregroundStyle(tokens.textPrimary)
                    .textSelection(.enabled)
                    .padding(14)
            }
        }
        .background(tokens.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tokens.separator, lineWidth: 1)
        )
    }
}

// ── Markdown パーサー ─────────────────────────────────

private struct MDBlock: Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind {
        case paragraph(String)
        case heading(Int, String)
        case codeBlock(String, String)
        case bulletItem(String)
        case numberedItem(Int, String)
        case blockquote(String)
        case horizontalRule
    }
}

private func parse(_ text: String) -> [MDBlock] {
    var blocks: [MDBlock] = []
    var lines = text.components(separatedBy: "\n")
    var i = 0

    while i < lines.count {
        let line = lines[i]

        // コードブロック
        if line.hasPrefix("```") {
            let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            i += 1
            var codeLines: [String] = []
            while i < lines.count && !lines[i].hasPrefix("```") {
                codeLines.append(lines[i])
                i += 1
            }
            blocks.append(MDBlock(kind: .codeBlock(lang, codeLines.joined(separator: "\n"))))
            i += 1
            continue
        }

        // 水平線
        if line.matches("^(---+|===+|___+)$") {
            blocks.append(MDBlock(kind: .horizontalRule))
            i += 1
            continue
        }

        // 見出し
        if let hm = line.firstMatch("^(#{1,6})\\s+(.+)$") {
            let level = hm.0.count
            blocks.append(MDBlock(kind: .heading(level, hm.1)))
            i += 1
            continue
        }

        // 箇条書き
        if let bm = line.firstMatch("^[\\-\\*\\+]\\s+(.+)$") {
            blocks.append(MDBlock(kind: .bulletItem(bm.0)))
            i += 1
            continue
        }

        // 番号付きリスト
        if let nm = line.firstMatch("^(\\d+)\\.\\s+(.+)$"),
           let n = Int(nm.0) {
            blocks.append(MDBlock(kind: .numberedItem(n, nm.1)))
            i += 1
            continue
        }

        // 引用
        if line.hasPrefix("> ") {
            let content = String(line.dropFirst(2))
            blocks.append(MDBlock(kind: .blockquote(content)))
            i += 1
            continue
        }

        // 空行スキップ
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            i += 1
            continue
        }

        // 段落（連続行を結合）
        var paraLines = [line]
        i += 1
        while i < lines.count {
            let next = lines[i]
            if next.trimmingCharacters(in: .whitespaces).isEmpty { break }
            if next.hasPrefix("```") || next.hasPrefix("#") ||
               next.hasPrefix("- ") || next.hasPrefix("* ") ||
               next.hasPrefix("> ") { break }
            paraLines.append(next)
            i += 1
        }
        blocks.append(MDBlock(kind: .paragraph(paraLines.joined(separator: " "))))
    }

    return blocks
}

// ── String helper ────────────────────────────────────

private extension String {
    func matches(_ pattern: String) -> Bool {
        (try? NSRegularExpression(pattern: pattern))
            .map { $0.firstMatch(in: self, range: NSRange(startIndex..., in: self)) != nil }
            ?? false
    }

    /// パターンにマッチし、(capture1, capture2) を返す
    func firstMatch(_ pattern: String) -> (String, String)? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m  = re.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              m.numberOfRanges >= 2 else { return nil }
        let g1 = m.numberOfRanges > 2
            ? (Range(m.range(at: 2), in: self).map { String(self[$0]) } ?? "")
            : (Range(m.range(at: 1), in: self).map { String(self[$0]) } ?? "")
        let g0 = Range(m.range(at: 1), in: self).map { String(self[$0]) } ?? ""
        return (g0, g1)
    }
}

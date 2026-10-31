// MarkdownView.swift
// AI の回答を簡易 Markdown で表示する

import SwiftUI

struct MarkdownView: View {
    let content: String

    private var attributed: AttributedString {
        if content.isEmpty {
            return AttributedString("…")
        }
        // インライン記法だけ解釈し、改行はそのまま保持
        return (try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(content)
    }

    var body: some View {
        Text(attributed)
            .font(.body)
            .lineSpacing(4)
    }
}

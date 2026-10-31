import SwiftUI

struct MarkdownView: View {
    let content: String
    let accentColor: Color
    let fontSize: CGFloat
    let codeHighlight: Bool

    var body: some View {
        Text(AttributedString(fromMarkdown: content, accentColor: accentColor, fontSize: fontSize, codeHighlight: codeHighlight))
            .font(.system(size: fontSize))
            .textSelection(.enabled)
    }
}

extension AttributedString {
    init(fromMarkdown markdown: String, accentColor: Color, fontSize: CGFloat, codeHighlight: Bool) {
        var attributedString = AttributedString(markdown)

        if codeHighlight {
            let codePattern = #"```[\s\S]*?```"#
            if let regex = try? NSRegularExpression(pattern: codePattern, options: []) {
                let range = NSRange(attributedString.startIndex..<attributedString.endIndex, in: String(attributedString.characters))
                let matches = regex.matches(in: String(attributedString.characters), options: [], range: range)

                for match in matches.reversed() {
                    if let range = Range(match.range, in: attributedString) {
                        attributedString[range].backgroundColor = Color(red: 0.15, green: 0.15, blue: 0.15)
                        attributedString[range].font = .monospaced(size: fontSize - 1)
                    }
                }
            }

            let inlineCodePattern = #"`[^`]+`"#
            if let regex = try? NSRegularExpression(pattern: inlineCodePattern, options: []) {
                let range = NSRange(attributedString.startIndex..<attributedString.endIndex, in: String(attributedString.characters))
                let matches = regex.matches(in: String(attributedString.characters), options: [], range: range)

                for match in matches.reversed() {
                    if let range = Range(match.range, in: attributedString) {
                        attributedString[range].backgroundColor = Color(red: 0.15, green: 0.15, blue: 0.15)
                        attributedString[range].font = .monospaced(size: fontSize - 1)
                    }
                }
            }
        }

        self = attributedString
    }
}

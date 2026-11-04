import Foundation

/// Source ranges are never normalized: downloads retain every byte inside fences.
struct CodeDocument: Identifiable, Equatable {
    let id: Int
    let language: String
    let source: String
    var fencedText = ""
    var fileName: String {
        let extensions = ["javascript": "js", "typescript": "ts", "python": "py", "swift": "swift", "html": "html", "css": "css", "json": "json", "bash": "sh", "shell": "sh", "jsx": "jsx", "tsx": "tsx", "markdown": "md", "yaml": "yaml", "sql": "sql"]
        let name = language.lowercased().split(separator: " ").first.map(String.init) ?? "txt"
        let ext = extensions[name] ?? (["js", "ts", "py", "md", "xml", "txt", "csv"].contains(name) ? name : "txt")
        return "kernel-\(id + 1).\(ext)"
    }
    static func parse(_ text: String) -> [CodeDocument] {
        segments(text).compactMap { if case .code(let code) = $0 { return code }; return nil }
    }
    enum Segment: Equatable { case prose(String), code(CodeDocument) }
    static func segments(_ text: String) -> [Segment] {
        var output: [Segment] = []
        var prose = "", code = "", language: String?, marker = "", count = 0, fenced = ""
        // Keep original line terminators (including CRLF).
        let lines = text.components(separatedBy: "\n")
        for (index, raw) in lines.enumerated() {
            let line = String(raw)
            let full = line + (index < lines.count - 1 ? "\n" : "")
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if let active = language {
                fenced += full
                if trimmed.hasPrefix(marker), trimmed.allSatisfy({ $0 == marker.first }) {
                    output.append(.code(CodeDocument(id: count, language: active, source: code, fencedText: fenced)))
                    count += 1; language = nil; code = ""
                } else { code += full }
            } else if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if !prose.isEmpty { output.append(.prose(prose)); prose = "" }
                let character = trimmed.first!
                marker = String(trimmed.prefix(while: { $0 == character }))
                language = String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                fenced = full
            } else { prose += full }
        }
        if let language { output.append(.code(CodeDocument(id: count, language: language, source: code, fencedText: fenced))) }
        if !prose.isEmpty { output.append(.prose(prose)) }
        return output
    }
}

enum JapanesePolicy {
    static let instruction = """
    回答の説明文は自然な日本語にしてください。英語の説明は意味を変えず日本語に翻訳してください。
    固有名詞（例: Apple Inc）、製品名、API、技術用語など英語の方が明確な表記は保持してください。
    fenced code、inline code、URL、ファイル名、コマンド、コード内のコメント・文字列を翻訳・改変しないでください。
    不明な事実や未実行の操作を成功したと主張しないでください。
    """
}

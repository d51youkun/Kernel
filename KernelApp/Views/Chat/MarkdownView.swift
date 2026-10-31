import SwiftUI

struct MarkdownView: View {
    let content: String
    let accentColor: Color
    let fontSize: CGFloat
    let codeHighlight: Bool

    var body: some View {
        Text(content)
            .font(.system(size: fontSize))
            .textSelection(.enabled)
    }
}

import SwiftUI

struct InputBarView: View {
    @Binding var inputText: String
    let isGenerating: Bool
    let accentColor: Color
    let theme: UITheme
    let onSend: () -> Void
    let onStop: () -> Void
    let onVoiceInput: () -> Void
    let isListening: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Button(action: onVoiceInput) {
                ZStack {
                    Circle()
                        .fill(isListening ? Color.red : accentColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .foregroundColor(isListening ? .white : accentColor)
                }
            }

            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("メッセージを入力...")
                        .foregroundColor(ThemeEngine.secondaryTextColor(for: theme))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $inputText)
                    .font(.system(size: 16))
                    .foregroundColor(ThemeEngine.textColor(for: theme))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 40, maxHeight: 150)
                    .padding(4)
                    .focused($isFocused)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(ThemeEngine.messageUserBackgroundColor(for: theme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )

            Button(action: isGenerating ? onStop : onSend) {
                ZStack {
                    Circle()
                        .fill(isGenerating ? Color.red : accentColor)
                        .frame(width: 40, height: 40)

                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .padding(16)
        .background(ThemeEngine.backgroundColor(for: theme))
    }
}

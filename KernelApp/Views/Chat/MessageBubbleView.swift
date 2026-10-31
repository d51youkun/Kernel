import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let accentColor: Color
    let theme: UITheme
    let fontSize: CGFloat
    let messageWidth: CGFloat
    let renderMarkdown: Bool
    let codeHighlight: Bool
    let showTimestamps: Bool
    let assistantName: String
    let assistantEmoji: String
    let onFeedback: (UUID, Message.Feedback) -> Void
    let onSpeak: () -> Void
    let onStopSpeaking: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                avatarView
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if showTimestamps {
                    Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(ThemeEngine.secondaryTextColor(for: theme))
                }

                contentBubble
                    .frame(maxWidth: messageWidth * UIScreen.main.bounds.width)

                if message.role == .assistant {
                    feedbackRow
                }
            }

            if message.role == .user {
                avatarView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.2))
                .frame(width: 36, height: 36)

            Text(message.role == .user ? "👤" : assistantEmoji)
                .font(.system(size: 20))
        }
    }

    private var contentBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.role == .assistant {
                Text(assistantName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
            }

            if renderMarkdown {
                MarkdownView(
                    content: message.content,
                    accentColor: accentColor,
                    fontSize: fontSize,
                    codeHighlight: codeHighlight
                )
            } else {
                Text(message.content)
                    .font(.system(size: fontSize))
                    .textSelection(.enabled)
            }

            if !message.attachments.isEmpty {
                ForEach(message.attachments) { attachment in
                    AttachmentRow(attachment: attachment)
                }
            }

            if let stats = message.generationDuration, let tokens = message.estimatedTokens {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                    Text("\(String(format: "%.1f", Double(tokens) / stats)) t/s")
                        .font(.caption)
                    Text("•")
                        .font(.caption)
                    Text("\(tokens) tokens")
                        .font(.caption)
                }
                .foregroundColor(ThemeEngine.secondaryTextColor(for: theme))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(message.role == .user
                      ? ThemeEngine.messageUserBackgroundColor(for: theme)
                      : ThemeEngine.messageAssistantBackgroundColor(for: theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var feedbackRow: some View {
        HStack(spacing: 12) {
            Button(action: { onFeedback(message.id, .thumbsUp) }) {
                Image(systemName: message.feedback == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundColor(message.feedback == .thumbsUp ? accentColor : ThemeEngine.secondaryTextColor(for: theme))
            }

            Button(action: { onFeedback(message.id, .thumbsDown) }) {
                Image(systemName: message.feedback == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundColor(message.feedback == .thumbsDown ? accentColor : ThemeEngine.secondaryTextColor(for: theme))
            }

            Spacer()

            Button(action: onSpeak) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(ThemeEngine.secondaryTextColor(for: theme))
            }

            Button(action: onStopSpeaking) {
                Image(systemName: "speaker.slash.fill")
                    .foregroundColor(ThemeEngine.secondaryTextColor(for: theme))
            }
        }
        .font(.caption)
    }
}

struct AttachmentRow: View {
    let attachment: AttachedFile

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.displayIcon)
                .foregroundColor(.blue)
            Text(attachment.fileName)
                .font(.caption)
                .lineLimit(1)
            Text(attachment.humanSize)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

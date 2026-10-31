// MessageBubbleView.swift
// 1件のメッセージ表示 (ユーザー/AI で見た目を変える)

import SwiftUI

struct MessageBubbleView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @Environment(\.colorScheme) private var colorScheme
    let message: Message

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user { Spacer(minLength: 48) }
            bubble
            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private var bubble: some View {
        if message.role == .user {
            // ── ユーザー: 右寄せの強調バブル ──
            Text(message.content)
                .foregroundStyle(ThemeEngine.userBubbleText)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ThemeEngine.userBubble, in: RoundedRectangle(cornerRadius: 18))
        } else {
            // ── AI: 左寄せのフラット表示 ──
            VStack(alignment: .leading, spacing: 6) {
                MarkdownView(content: message.content)
                    .textSelection(.enabled)

                if message.tokenCount > 0 {
                    statsRow
                }
                footer
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(ThemeEngine.assistantBubble(colorScheme))
            )
        }
    }

    /// 生成速度とトークン数
    private var statsRow: some View {
        HStack(spacing: 12) {
            Label("\(message.tokenCount) トークン", systemImage: "number")
            Label(String(format: "%.1f tok/s",
                         message.generationSeconds > 0
                         ? Double(message.tokenCount) / message.generationSeconds : 0),
                  systemImage: "speedometer")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    /// 👍👎 と読み上げ
    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                chatVM.setFeedback(for: message.id, feedback: .like)
            } label: {
                Image(systemName: message.feedback == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundStyle(message.feedback == .like ? Color.accentColor : .secondary)
            }
            Button {
                chatVM.setFeedback(for: message.id, feedback: .dislike)
            } label: {
                Image(systemName: message.feedback == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundStyle(message.feedback == .dislike ? .red : .secondary)
            }
            Button {
                chatVM.speakMessage(id: message.id)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.footnote)
        .buttonStyle(.plain)
    }
}

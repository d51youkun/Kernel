// MessageBubbleView.swift
// ユーザー/アシスタントのメッセージバブル（ChatGPT for iPad 風）

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isLastAndGenerating: Bool

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser {
                Spacer(minLength: 72)
                userBubble
                    .padding(.trailing, 16)
                    .padding(.vertical, 4)
            } else {
                assistantAvatar
                    .padding(.leading, 16)
                    .padding(.top, 4)
                assistantBubble
                    .padding(.vertical, 4)
                Spacer(minLength: 40)
            }
        }
        .padding(.vertical, 2)
    }

    // ── ユーザーバブル ──────────────────────────

    private var userBubble: some View {
        Text(message.content)
            .textSelection(.enabled)
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue)
            .clipShape(ChatBubbleShape(isUser: true))
    }

    // ── アシスタントバブル ───────────────────────

    @ViewBuilder
    private var assistantBubble: some View {
        Group {
            if message.content.isEmpty && isLastAndGenerating {
                TypingIndicatorView()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            } else {
                Text(message.content)
                    .textSelection(.enabled)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(ChatBubbleShape(isUser: false))
    }

    // ── アシスタントアバター ─────────────────────

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 30, height: 30)
            Image(systemName: "brain.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white)
        }
    }
}

// ── チャットバブル形状 ─────────────────────────────

struct ChatBubbleShape: Shape {
    let isUser: Bool
    private let r: CGFloat = 18
    private let tail: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if isUser {
            // 右下のみ小さい丸み（尻尾風）
            p.move(to: .init(x: rect.minX + r, y: rect.minY))
            p.addLine(to: .init(x: rect.maxX - r, y: rect.minY))
            p.addArc(center: .init(x: rect.maxX - r, y: rect.minY + r),
                     radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: .init(x: rect.maxX, y: rect.maxY - tail))
            p.addArc(center: .init(x: rect.maxX - tail, y: rect.maxY - tail),
                     radius: tail, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: .init(x: rect.minX + r, y: rect.maxY))
            p.addArc(center: .init(x: rect.minX + r, y: rect.maxY - r),
                     radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: .init(x: rect.minX, y: rect.minY + r))
            p.addArc(center: .init(x: rect.minX + r, y: rect.minY + r),
                     radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            // 左下のみ小さい丸み
            p.move(to: .init(x: rect.minX + r, y: rect.minY))
            p.addLine(to: .init(x: rect.maxX - r, y: rect.minY))
            p.addArc(center: .init(x: rect.maxX - r, y: rect.minY + r),
                     radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: .init(x: rect.maxX, y: rect.maxY - r))
            p.addArc(center: .init(x: rect.maxX - r, y: rect.maxY - r),
                     radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: .init(x: rect.minX + tail, y: rect.maxY))
            p.addArc(center: .init(x: rect.minX + tail, y: rect.maxY - tail),
                     radius: tail, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: .init(x: rect.minX, y: rect.minY + r))
            p.addArc(center: .init(x: rect.minX + r, y: rect.minY + r),
                     radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        p.closeSubpath()
        return p
    }
}

// ── タイピングインジケータ ────────────────────────

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.45)
                        .repeatForever()
                        .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// ── ウェルカムビュー ─────────────────────────────

struct WelcomeView: View {
    let modelName: String

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "brain.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }
            VStack(spacing: 6) {
                Text("Kernel")
                    .font(.largeTitle.bold())
                Text(modelName)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("何でも聞いてください。")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

// ── モデルなし ───────────────────────────────────

struct NoModelView: View {
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("モデルがありません")
                .font(.title2.bold())
            Text("設定から GGUF ファイルを追加してください。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("設定を開く") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}

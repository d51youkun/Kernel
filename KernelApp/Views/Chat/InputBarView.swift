// InputBarView.swift
// チャット入力バー（マルチライン TextField + 送信/停止ボタン）

import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // ── テキストフィールド ──
            TextField("Message…", text: $text, axis: .vertical)
                .lineLimit(1...8)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .focused($isFocused)
                .onSubmit {
                    // ハードキーボードの Return: 送信（Shift+Return で改行）
                }

            // ── 送信 / 停止ボタン ──
            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isGenerating {
            // 停止ボタン
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color(.label))
                    .clipShape(Circle())
            }
            .transition(.scale.combined(with: .opacity))
        } else {
            // 送信ボタン
            Button {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onSend()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(canSend ? Color.blue : Color.secondary.opacity(0.4))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

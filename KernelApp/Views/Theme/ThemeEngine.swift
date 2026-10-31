// ThemeEngine.swift
// アプリ全体で使う色の定義

import SwiftUI

enum ThemeEngine {
    /// 背景 (ダーク/ライト自動対応)
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(uiColor: .systemBackground) : .white
    }

    /// ユーザーの吹き出し
    static var userBubble: Color { Color.accentColor }

    /// ユーザーの吹き出し内テキスト
    static var userBubbleText: Color { .white }

    /// AI の吹き出し
    static func assistantBubble(_ scheme: ColorScheme) -> Color {
        Color(uiColor: scheme == .dark ? .secondarySystemBackground : .systemGray6)
    }

    /// サイドバーの選択色
    static var selectedRow: Color { Color.accentColor.opacity(0.15) }
}

// ThemeEngine.swift
// UITheme別のデザイントークン

import SwiftUI

// ── デザイントークン ─────────────────────────────────

struct ThemeTokens {
    // 背景
    var appBackground: Color
    var sidebarBackground: Color
    var chatBackground: Color
    var inputBackground: Color
    var bubbleUser: Color
    var bubbleAssistant: Color
    // テキスト
    var textPrimary: Color
    var textSecondary: Color
    var textOnUser: Color
    var textCode: Color
    // 枠線・区切り
    var separator: Color
    var inputBorder: Color
    // サーフェス
    var surface: Color
    var surfaceElevated: Color
    // コードブロック
    var codeBackground: Color
    // コーナー半径
    var bubbleCorner: CGFloat
    var inputCorner: CGFloat
    // フォント
    var fontFamily: Font.Design
    // アシスタントアバタースタイル
    var avatarFill: Color
    var avatarIcon: Color
}

extension ThemeTokens {
    static func tokens(for theme: UITheme, accent: Color, fontSize: FontSizeOption) -> ThemeTokens {
        switch theme {
        case .chatGPT:
            return ThemeTokens(
                appBackground:      Color(.systemBackground),
                sidebarBackground:  Color(.secondarySystemBackground),   // 白系グレーに変更
                chatBackground:     Color(.systemBackground),
                inputBackground:    Color(.systemGray6),
                bubbleUser:         accent,
                bubbleAssistant:    Color(.secondarySystemBackground),   // アシスタントにもう少し背景を付ける
                textPrimary:        Color(.label),
                textSecondary:      Color(.secondaryLabel),
                textOnUser:         .white,
                textCode:           Color(red: 0.8, green: 0.2, blue: 0.15),
                separator:          Color(.separator),
                inputBorder:        Color(.systemGray4),
                surface:            Color(.tertiarySystemBackground),
                surfaceElevated:    Color(.quaternarySystemFill),
                codeBackground:     Color(red: 0.95, green: 0.95, blue: 0.97), // ライトモード対応
                bubbleCorner:       18,
                inputCorner:        24,
                fontFamily:         .default,
                avatarFill:         Color(red: 0.06, green: 0.60, blue: 0.45), // ChatGPT緑系
                avatarIcon:         .white
            )
        case .claudeCode:
            return ThemeTokens(
                appBackground:      Color(red: 0.11, green: 0.11, blue: 0.13),
                sidebarBackground:  Color(red: 0.07, green: 0.07, blue: 0.09),
                chatBackground:     Color(red: 0.11, green: 0.11, blue: 0.13),
                inputBackground:    Color(red: 0.17, green: 0.17, blue: 0.20),
                bubbleUser:         Color(red: 0.17, green: 0.17, blue: 0.20),
                bubbleAssistant:    Color(red: 0.14, green: 0.14, blue: 0.17),
                textPrimary:        Color(red: 0.92, green: 0.92, blue: 0.90),
                textSecondary:      Color(red: 0.55, green: 0.55, blue: 0.60),
                textOnUser:         Color(red: 0.92, green: 0.92, blue: 0.90),
                textCode:           Color(red: 0.65, green: 0.85, blue: 0.45),
                separator:          Color(red: 0.20, green: 0.20, blue: 0.24),
                inputBorder:        Color(red: 0.28, green: 0.28, blue: 0.34),
                surface:            Color(red: 0.14, green: 0.14, blue: 0.17),
                surfaceElevated:    Color(red: 0.18, green: 0.18, blue: 0.22),
                codeBackground:     Color(red: 0.08, green: 0.08, blue: 0.10),
                bubbleCorner:       8,
                inputCorner:        10,
                fontFamily:         .monospaced,
                avatarFill:         Color(red: 0.85, green: 0.62, blue: 0.40),
                avatarIcon:         .white
            )
        }
    }
}

// ── Environment Key ──────────────────────────────────

private struct ThemeTokensKey: EnvironmentKey {
    static let defaultValue = ThemeTokens.tokens(for: .chatGPT, accent: Color.blue, fontSize: .medium)
}

extension EnvironmentValues {
    var themeTokens: ThemeTokens {
        get { self[ThemeTokensKey.self] }
        set { self[ThemeTokensKey.self] = newValue }
    }
}

// ── ThemeWrapper ─────────────────────────────────────

struct ThemeWrapper<Content: View>: View {
    @ObservedObject var settings: AppSettings
    let content: Content

    init(settings: AppSettings, @ViewBuilder content: () -> Content) {
        self.settings = settings
        self.content = content()
    }

    var body: some View {
        let tokens = ThemeTokens.tokens(
            for: settings.theme,
            accent: settings.accentColor.color,
            fontSize: settings.fontSize
        )
        content
            .environment(\.themeTokens, tokens)
            .tint(settings.accentColor.color)
            .preferredColorScheme(settings.theme == .claudeCode ? .dark : nil)
    }
}

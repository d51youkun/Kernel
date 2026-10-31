// AppSettings.swift
// アプリ全体のテーマ・パーソナライズ設定

import SwiftUI
import Combine

// ── テーマ ───────────────────────────────────────────

enum UITheme: String, CaseIterable, Identifiable, Codable {
    case chatGPT    = "ChatGPT"
    case claudeCode = "Claude Code"
    var id: String { rawValue }
}

// ── アクセントカラー ──────────────────────────────────

enum AccentColorOption: String, CaseIterable, Identifiable, Codable {
    case blue   = "Blue"
    case purple = "Purple"
    case green  = "Green"
    case orange = "Orange"
    case pink   = "Pink"
    case teal   = "Teal"
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue:   return Color(red: 0.0,  green: 0.48, blue: 1.0)
        case .purple: return Color(red: 0.55, green: 0.35, blue: 0.95)
        case .green:  return Color(red: 0.18, green: 0.80, blue: 0.44)
        case .orange: return Color(red: 1.0,  green: 0.58, blue: 0.0)
        case .pink:   return Color(red: 1.0,  green: 0.22, blue: 0.55)
        case .teal:   return Color(red: 0.19, green: 0.73, blue: 0.73)
        }
    }
}

// ── フォントサイズ ──────────────────────────────────

enum FontSizeOption: String, CaseIterable, Identifiable, Codable {
    case small  = "Small"
    case medium = "Medium"
    case large  = "Large"
    var id: String { rawValue }

    var bodySize: CGFloat {
        switch self {
        case .small:  return 14
        case .medium: return 16
        case .large:  return 18
        }
    }
    var codeSize: CGFloat { bodySize - 1 }
}

// ── メッセージ幅 ────────────────────────────────────

enum MessageWidthOption: String, CaseIterable, Identifiable, Codable {
    case narrow  = "Narrow"
    case medium  = "Medium"
    case wide    = "Wide"
    case full    = "Full"
    var id: String { rawValue }

    var fraction: CGFloat {
        switch self {
        case .narrow:  return 0.55
        case .medium:  return 0.70
        case .wide:    return 0.85
        case .full:    return 1.0
        }
    }
}

// ── AppSettings ──────────────────────────────────────

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // テーマ
    @Published var theme: UITheme = .chatGPT
    // カラー
    @Published var accentColor: AccentColorOption = .blue
    // フォント
    @Published var fontSize: FontSizeOption = .medium
    // メッセージ幅
    @Published var messageWidth: MessageWidthOption = .medium
    // アシスタント名
    @Published var assistantName: String = "Kernel"
    // アバター絵文字
    @Published var assistantEmoji: String = "🤖"
    // システムプロンプト
    @Published var systemPrompt: String = ""
    // コードハイライト
    @Published var codeHighlight: Bool = true
    // Markdownレンダリング
    @Published var renderMarkdown: Bool = true
    // TTS（読み上げ）
    @Published var ttsEnabled: Bool = false
    // タイピング効果アニメーション
    @Published var streamingAnimation: Bool = true
    // メッセージにタイムスタンプ表示
    @Published var showTimestamps: Bool = false
    // サイドバー自動折り畳み（Magic Keyboard使用時）
    @Published var autoCollapseSidebar: Bool = false
    // チャットアバターアイコン絵文字（nilならデフォルトのbrain.fill）
    @Published var chatIconEmoji: String? = nil {
        didSet { save() }
    }
    // 日本語強制（デフォルトON）
    @Published var forceJapanese: Bool = true {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let key = "AppSettings.v1"

    private init() { load() }

    func save() {
        let dto = DTO(
            theme: theme, accentColor: accentColor,
            fontSize: fontSize, messageWidth: messageWidth,
            assistantName: assistantName, assistantEmoji: assistantEmoji,
            systemPrompt: systemPrompt, codeHighlight: codeHighlight,
            renderMarkdown: renderMarkdown, ttsEnabled: ttsEnabled,
            streamingAnimation: streamingAnimation, showTimestamps: showTimestamps,
            autoCollapseSidebar: autoCollapseSidebar,
            chatIconEmoji: chatIconEmoji, forceJapanese: forceJapanese
        )
        if let data = try? JSONEncoder().encode(dto) {
            defaults.set(data, forKey: key)
        }
    }

    func load() {
        guard let data = defaults.data(forKey: key),
              let dto  = try? JSONDecoder().decode(DTO.self, from: data) else { return }
        theme                = dto.theme
        accentColor          = dto.accentColor
        fontSize             = dto.fontSize
        messageWidth         = dto.messageWidth
        assistantName        = dto.assistantName
        assistantEmoji       = dto.assistantEmoji
        systemPrompt         = dto.systemPrompt
        codeHighlight        = dto.codeHighlight
        renderMarkdown       = dto.renderMarkdown
        ttsEnabled           = dto.ttsEnabled
        streamingAnimation   = dto.streamingAnimation
        showTimestamps       = dto.showTimestamps
        autoCollapseSidebar  = dto.autoCollapseSidebar
        chatIconEmoji        = dto.chatIconEmoji
        forceJapanese        = dto.forceJapanese ?? true
    }

    // Codable DTO
    private struct DTO: Codable {
        var theme: UITheme
        var accentColor: AccentColorOption
        var fontSize: FontSizeOption
        var messageWidth: MessageWidthOption
        var assistantName: String
        var assistantEmoji: String
        var systemPrompt: String
        var codeHighlight: Bool
        var renderMarkdown: Bool
        var ttsEnabled: Bool
        var streamingAnimation: Bool
        var showTimestamps: Bool
        var autoCollapseSidebar: Bool
        var chatIconEmoji: String?
        var forceJapanese: Bool?
    }
}

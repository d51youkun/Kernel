import SwiftUI

struct ThemeEngine {
    static func backgroundColor(for theme: UITheme) -> Color {
        switch theme {
        case .chatGPT:
            return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .claudeCode:
            return Color(red: 0.06, green: 0.09, blue: 0.13)
        }
    }

    static func sidebarBackgroundColor(for theme: UITheme) -> Color {
        switch theme {
        case .chatGPT:
            return Color(red: 0.12, green: 0.12, blue: 0.12)
        case .claudeCode:
            return Color(red: 0.08, green: 0.11, blue: 0.15)
        }
    }

    static func messageUserBackgroundColor(for theme: UITheme) -> Color {
        switch theme {
        case .chatGPT:
            return Color(red: 0.18, green: 0.18, blue: 0.18)
        case .claudeCode:
            return Color(red: 0.15, green: 0.20, blue: 0.25)
        }
    }

    static func messageAssistantBackgroundColor(for theme: UITheme) -> Color {
        switch theme {
        case .chatGPT:
            return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .claudeCode:
            return Color(red: 0.06, green: 0.09, blue: 0.13)
        }
    }

    static func textColor(for theme: UITheme) -> Color {
        switch theme {
        case .chatGPT:
            return Color(red: 0.90, green: 0.90, blue: 0.90)
        case .claudeCode:
            return Color(red: 0.85, green: 0.85, blue: 0.85)
        }
    }

    static func secondaryTextColor(for theme: UITheme) -> Color {
        switch theme {
        case .chatGPT:
            return Color(red: 0.60, green: 0.60, blue: 0.60)
        case .claudeCode:
            return Color(red: 0.55, green: 0.55, blue: 0.55)
        }
    }
}

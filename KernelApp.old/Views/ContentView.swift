// ContentView.swift
// ルートビュー: ThemeWrapper + NavigationSplitView（Magic Keyboard対応）

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var showSettings = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        ThemeWrapper(settings: settings) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(showSettings: $showSettings)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
            } detail: {
                detailContent
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(modelManager)
            }
            // Cmd+,: 設定を開く
            .background(
                Button("") { showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
                    .opacity(0)
            )
            // Cmd+Shift+S: サイドバー表示切り替え
            .background(
                Button("") {
                    withAnimation {
                        columnVisibility = columnVisibility == .all ? .detailOnly : .all
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .opacity(0)
            )
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let model = resolvedModel {
            ChatView(model: model)
        } else {
            NoModelPlaceholder(showSettings: $showSettings)
        }
    }

    private var resolvedModel: ModelEntry? {
        if let modelId = chatVM.currentConversation?.modelId,
           let m = modelManager.models.first(where: { $0.id == modelId }) { return m }
        return modelManager.selectedModel
    }
}

// ── モデルなし画面 ─────────────────────────────────────

private struct NoModelPlaceholder: View {
    @Binding var showSettings: Bool
    @Environment(\.themeTokens) var tokens

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 56))
                .foregroundStyle(tokens.textSecondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("モデルがありません")
                    .font(.title2.bold())
                    .foregroundStyle(tokens.textPrimary)
                Text("設定から GGUF ファイルを追加してください。")
                    .font(.body)
                    .foregroundStyle(tokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showSettings = true
            } label: {
                Label("設定を開く", systemImage: "gearshape.fill")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tokens.chatBackground)
    }
}

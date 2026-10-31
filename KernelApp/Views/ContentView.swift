// ContentView.swift
// ルートビュー: iPad の NavigationSplitView（サイドバー + チャット）

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var chatVM: ChatViewModel
    @State private var showSettings = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(showSettings: $showSettings)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 340)
        } detail: {
            detailContent
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(modelManager)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let model = resolvedModel {
            ChatView(model: model)
        } else {
            NoModelView(showSettings: $showSettings)
        }
    }

    private var resolvedModel: ModelEntry? {
        // 現在の会話で使ったモデル、なければ選択中モデル
        if let modelId = chatVM.currentConversation?.modelId,
           let m = modelManager.models.first(where: { $0.id == modelId }) {
            return m
        }
        return modelManager.selectedModel
    }
}

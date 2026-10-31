// ContentView.swift
// サイドバー + チャット画面のルートレイアウト (iPad 対応)

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationTitle("Kernel")
        } detail: {
            ChatView(showSettings: $showSettings)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

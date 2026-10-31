// KernelApp.swift
// アプリエントリポイント

import SwiftUI

@main
struct KernelApp: App {
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var chatVM       = ChatViewModel()

    init() {
        // llama.cpp バックエンドを初期化（Metal GPU 含む）
        LlamaBridge.initializeBackend()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modelManager)
                .environmentObject(chatVM)
        }
    }
}

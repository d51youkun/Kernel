// KernelApp.swift
// アプリのエントリポイント

import SwiftUI

@main
struct KernelApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var jitService = JITService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(chatVM)
                .environmentObject(modelManager)
                .environmentObject(jitService)
        }
    }
}

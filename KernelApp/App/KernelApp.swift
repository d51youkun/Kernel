// KernelApp.swift
// アプリエントリポイント

import SwiftUI

@main
struct KernelApp: App {
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var chatVM       = ChatViewModel()
    @StateObject private var settings     = AppSettingsStore()

    init() {
        LlamaBridge.initializeBackend()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modelManager)
                .environmentObject(chatVM)
                .environmentObject(settings.appSettings)
                .onReceive(NotificationCenter.default.publisher(for: .kernelOpenURL)) { note in
                    guard let url = note.object as? URL else { return }
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.willResignActiveNotification
                    )
                ) { _ in
                    settings.appSettings.save()
                    chatVM.saveToDisk()
                }
        }
    }
}

/// AppSettings をStateObjectとして保持するためのラッパー
final class AppSettingsStore: ObservableObject {
    let appSettings = AppSettings.shared
}

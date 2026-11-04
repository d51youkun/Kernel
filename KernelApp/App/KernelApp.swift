import SwiftUI

@main
struct KernelApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .environmentObject(store)
                .tint(.primary)
                .preferredColorScheme(store.settings.appearance == "dark" ? .dark : store.settings.appearance == "light" ? .light : nil)
                .onChange(of: phase) { _, value in
                    if value != .active { store.persist() }
                    if value == .background, store.busy {
                        store.stop()
                        store.error = "iPadOSのバックグラウンド制限により生成を中断しました。受信済みの回答は保存されます。アプリを開いたまま「続きを生成」を使用してください。"
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    store.memoryWarning()
                }
                .onOpenURL { url in
                    if url.pathExtension.lowercased() == "gguf" { store.importModels([url]) }
                    if url.scheme == "kernel", !store.busy {
                        if url.host == "settings" { store.showSettings = true }
                        else {
                            store.newChat()
                            store.shortcutDraft = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "prompt" })?.value ?? ""
                        }
                    }
                }
        }
    }
}

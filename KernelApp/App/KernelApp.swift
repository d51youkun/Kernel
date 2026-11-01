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
                    if value == .background { store.stop() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    store.memoryWarning()
                }
                .onOpenURL { url in
                    if url.pathExtension.lowercased() == "gguf" { store.importModels([url]) }
                }
        }
    }
}

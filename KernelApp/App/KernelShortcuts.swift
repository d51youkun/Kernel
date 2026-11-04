import AppIntents

struct OpenKernelChat: AppIntent {
    static var title: LocalizedStringResource = "Kernelで新しいチャット"
    static var description = IntentDescription("Kernelを開き、新しいチャットを作成します。")
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "kernel://new")!))
    }
}

struct DraftKernelPrompt: AppIntent {
    static var title: LocalizedStringResource = "Kernelに質問を渡す"
    static var description = IntentDescription("質問を入力欄に渡します。自動送信はせず、アプリで内容を確認して送信します。")
    static var openAppWhenRun = true
    @Parameter(title: "質問") var prompt: String
    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        var url = URLComponents(string: "kernel://new")!
        url.queryItems = [URLQueryItem(name: "prompt", value: prompt)]
        return .result(opensIntent: OpenURLIntent(url.url!))
    }
}

struct KernelShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenKernelChat(), phrases: ["\(.applicationName)で新しいチャット"], shortTitle: "新しいチャット", systemImageName: "square.and.pencil")
        AppShortcut(intent: DraftKernelPrompt(), phrases: ["\(.applicationName)に質問"], shortTitle: "質問を渡す", systemImageName: "bubble.left")
    }
}

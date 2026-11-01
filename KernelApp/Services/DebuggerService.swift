import SwiftUI

@MainActor
final class DebuggerService: NSObject, ObservableObject, KernelDebuggerHost {
    @Published var status = "未接続"
    @Published var logs: [String] = []
    @Published var busy = false
    @Published var pairingName: String?
    @Published var jitReady = false
    private var bridge: DebuggerBridge?
    private var runner: KernelDebuggerRunner?
    private var task: Task<Void, Never>?
    private var currentOperation = ""
    private var probing = false
    private var probeSucceeded = false
    private let pairingURL = Storage.documents.appendingPathComponent("StikJIT/pairingFile.plist")

    override init() {
        super.init()
        if FileManager.default.fileExists(atPath: pairingURL.path) { pairingName = "pairingFile.plist" }
    }
    var entitled: Bool { DebuggerBridge.hasDebugEntitlement() }
    var liveContainer: Bool { getenv("LC_HOME_PATH") != nil }
    func importPairing(_ url: URL) {
        do {
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) < 2_000_000 else { throw KernelError.message("ペアリングファイルが大きすぎます。") }
            let data = try Data(contentsOf: url)
            guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  plist["HostID"] != nil, plist["SystemBUID"] != nil else { throw KernelError.message("有効なペアリングplistではありません。") }
            try FileManager.default.createDirectory(at: pairingURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: pairingURL, options: [.atomic, .completeFileProtection])
            pairingName = url.lastPathComponent; status = "ペアリングファイルを更新しました。"
        } catch { status = error.localizedDescription }
    }
    func start(_ operation: String) {
        guard !busy else { return }
        guard !liveContainer else { status = "LiveContainer内では内蔵拡張を起動できません。通常のサイドロードでインストールしてください。"; return }
        guard entitled else { status = "get-task-allowがありません。この権限を保持する署名方式で再インストールしてください。"; return }
        guard let data = try? Data(contentsOf: pairingURL) else { status = "先にペアリングファイルを追加してください。"; return }
        // Never send protocol breakpoints to an unrelated debugger such as Xcode/LLDB.
        guard !DebuggerBridge.debugged() else { status = "すでに別のデバッガが接続しています。解除してから内蔵デバッガを使用してください。"; return }
        currentOperation = operation; probeSucceeded = false; probing = false
        busy = true; status = "内蔵デバッガを起動中…"; logs = []
        bridge?.invalidate()
        let bridge = DebuggerBridge(); self.bridge = bridge
        bridge.launch(with: self) { [weak self] runner, error in
            Task { @MainActor in
                guard let self else { return }
                if let error { self.finish(false, detail: error.localizedDescription); return }
                self.runner = runner
                runner?.run(operation, pid: getpid(), pairing: data)
                self.watch(operation)
            }
        }
    }
    private func watch(_ operation: String) {
        task = Task {
            for _ in 0..<600 {
                try? await Task.sleep(for: .milliseconds(500))
                if Task.isCancelled || !busy { return }
                if operation == "enable", !probing, DebuggerBridge.debugged() {
                    probing = true
                    let ok = await Task.detached { DebuggerBridge.prepareExecutableProbe() }.value
                    probeSucceeded = ok
                    if !ok { finish(false, detail: "実行メモリの準備を検証できませんでした。") }
                }
            }
            finish(false, detail: "デバッガ接続がタイムアウトしました。LocalDevVPN・開発者モード・ペアリングを確認してください。")
        }
    }
    nonisolated func ready() { Task { @MainActor in logs.append("デバッガ拡張に接続しました。") } }
    nonisolated func log(_ line: String) {
        Task { @MainActor in
            // Do not include pair records or key material in logs.
            if logs.count > 150 { logs.removeFirst(50) }
            logs.append(line); status = line
        }
    }
    nonisolated func finished(_ success: Bool, detail: String) {
        Task { @MainActor in
            if currentOperation == "enable", success {
                // The probe return is scheduled independently of the XPC completion.
                for _ in 0..<20 where !probeSucceeded && busy { try? await Task.sleep(for: .milliseconds(100)) }
                finish(probeSucceeded, detail: probeSucceeded ? "JIT実行テスト成功（42）· 内蔵デバッガ接続完了" : "接続は完了しましたがJIT実行テストは未確認です。")
            } else { finish(success, detail: detail) }
        }
    }
    private func finish(_ success: Bool, detail: String) {
        status = detail; busy = false; task?.cancel(); task = nil
        if currentOperation == "enable" { jitReady = success && probeSucceeded }
        bridge?.invalidate(); bridge = nil; runner = nil
    }
}

struct DebuggerScreen: View {
    @StateObject private var debugger = DebuggerService()
    @State private var importing = false
    var body: some View {
        Form {
            Section("内蔵StikJITデバッガ") {
                Label(debugger.jitReady ? "JIT実行確認済み" : "JIT未確認", systemImage: debugger.jitReady ? "checkmark.seal" : "ant")
                Text(debugger.status).font(.callout).textSelection(.enabled)
                LabeledContent("get-task-allow", value: debugger.entitled ? "あり" : "なし")
                Text("GGUF推論はMetal/CPUで動作し、JITは必須ではありません。JIT実行テストは内蔵デバッガによる実行メモリ準備を確認するもので、llama.cppをJIT化するものではありません。").font(.caption).foregroundStyle(.secondary)
            }
            Section("セットアップ") {
                Text("1. 開発者モードを有効にする\n2. このiPadのペアリングファイルを追加\n3. LocalDevVPNを接続する\n4. Wi-Fi接続を確認して準備を開始")
                Button(debugger.pairingName ?? "ペアリングファイルを追加", systemImage: "doc.badge.plus") { importing = true }
                Button("デバイスとDDIを準備", systemImage: "wrench.and.screwdriver") { debugger.start("prepare") }
                Button("内蔵デバッガでJITを有効化", systemImage: "bolt") { debugger.start("enable") }
                Button("DDIキャッシュをリセット", systemImage: "arrow.clockwise") { debugger.start("reset") }
                if debugger.busy { ProgressView("接続処理中…") }
            }.disabled(debugger.busy || debugger.liveContainer)
            Section("接続ログ") {
                ForEach(Array(debugger.logs.enumerated()), id: \.offset) { _, line in Text(line).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
            }
            Section {
                Link("StikJITのセットアップ手順", destination: URL(string: "https://github.com/StikDebug/StikJIT/blob/main/INTEGRATION.md")!)
                Text("接続に失敗した場合はVPN・ペアリングを確認し、iPadを再起動してください。iPadOSと署名環境によって内蔵拡張が制限される場合があります。").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("JIT・内蔵デバッガ")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
                if case .success(let url) = result { debugger.importPairing(url) }
            }
    }
}

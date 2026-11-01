import Foundation
import StikJIT

final class RequestHandler: NSObject, NSExtensionRequestHandling, KernelDebuggerRunner {
    private var connection: NSXPCConnection?
    private var context: NSExtensionContext?
    private let queue = DispatchQueue(label: "app.kernel.debugger", qos: .userInitiated)
    private var host: KernelDebuggerHost?
    private let paths = DDIPaths.default(in: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("StikJIT"))

    func beginRequest(with context: NSExtensionContext) {
        self.context = context
        guard let item = context.inputItems.first as? NSExtensionItem,
              let endpoint = item.userInfo?["KernelEndpoint"] as? NSXPCListenerEndpoint else {
            context.cancelRequest(withError: NSError(domain: "Kernel.Debugger", code: 1)); return
        }
        let connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.exportedInterface = NSXPCInterface(with: KernelDebuggerRunner.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: KernelDebuggerHost.self)
        connection.resume(); self.connection = connection
        host = connection.remoteObjectProxyWithErrorHandler { _ in } as? KernelDebuggerHost
        host?.ready()
    }

    func run(_ operation: String, pid: Int32, pairing data: Data) {
        queue.async { [self] in
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).plist")
            defer { try? FileManager.default.removeItem(at: file) }
            do {
                if operation == "reset" {
                    try StikJIT.resetCachedDDI(at: paths); host?.finished(true, detail: "DDIキャッシュを削除しました。"); return
                }
                try data.write(to: file, options: [.atomic, .completeFileProtection])
                if operation == "prepare" {
                    let result = StikJIT.prepareDevice(pairingFile: file, paths: paths) { [weak self] stage in self?.stage(stage) }
                    switch result {
                    case .ready(let state): host?.finished(true, detail: "準備完了 · TXM/SPTM: \(state.isTXMPresent.map { $0 ? "あり" : "なし" } ?? "不明")")
                    case .unreachable(let reason), .preparationFailed(let reason): host?.finished(false, detail: reason)
                    @unknown default: host?.finished(false, detail: "未知のデバイス状態です。")
                    }
                } else {
                    // Always use the matching universal handshake, even on pre-TXM devices.
                    try StikJIT.enableJIT(targetPID: pid, pairingFile: file, ddiPaths: paths, script: .universal, forceScript: true,
                        preparationProgress: { [weak self] stage in self?.stage(stage) }, progress: { [weak self] line in self?.host?.log(line) })
                    host?.finished(true, detail: "デバッガ接続が完了しました。")
                }
            } catch { host?.finished(false, detail: error.localizedDescription) }
        }
    }
    private func stage(_ stage: StikJIT.PreparationStage) {
        switch stage {
        case .checkingReachability: host?.log("トンネル接続を確認中…")
        case .checkingDDI: host?.log("Developer Disk Imageを確認中…")
        case .downloadingDDI(let progress, _): host?.log("DDIダウンロード \(Int(progress * 100))%")
        case .mountingDDI(let progress): host?.log("DDIマウント \(Int(progress * 100))%")
        case .verifyingDDI: host?.log("DDIを検証中…")
        case .ready: host?.log("デバイスの準備が完了しました。")
        @unknown default: host?.log("デバイスの状態を確認中…")
        }
    }
}

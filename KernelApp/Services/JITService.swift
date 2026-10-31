import Foundation
import Combine

private let CS_DEBUGGED: UInt32 = 0x10000000
private let CS_OPS_STATUS: UInt32 = 0
private let CS_OPS_SET_STATUS: UInt32 = 1
private let PT_TRACE_ME: Int32 = 0

@MainActor
final class JITService: ObservableObject {
    static let shared = JITService()

    enum JITStatus: Equatable {
        case unknown
        case notEnabled
        case enabling
        case enabled
        case failed(String)
    }

    @Published var status: JITStatus = .unknown
    @Published var pairingFileURL: URL?
    @Published var pairingFileName: String?

    private init() {
        loadExistingPairingFile()
        checkJITStatus()
    }

    func checkJITStatus() {
        var flags: UInt32 = 0
        _ = withUnsafeMutablePointer(to: &flags) { ptr in
            csops(getpid(), CS_OPS_STATUS, ptr, MemoryLayout<UInt32>.size)
        }
        status = (flags & CS_DEBUGGED != 0) ? .enabled : .notEnabled
    }

    func enableJIT() {
        status = .enabling

        if trySelfJIT() {
            checkJITStatus()
            if status == .enabled { return }
        }

        let bundleId = Bundle.main.bundleIdentifier ?? "com.kernel.app"
        let enc = bundleId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleId

        let candidates: [String] = [
            "stikjit://enable?bundle=\(enc)",
            "stikdebug://jit?bundle=\(enc)",
            "sidestore://jit?app=\(enc)",
        ]

        Task { @MainActor in
            for urlStr in candidates {
                guard let url = URL(string: urlStr) else { continue }
                NotificationCenter.default.post(name: .kernelOpenURL, object: url)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                checkJITStatus()
                if status == .enabled { return }
            }
            if status != .enabled {
                status = .failed("JITを有効化できませんでした。\nStikJIT / StikDebug / SideStore のいずれかが必要です。")
            }
        }
    }

    func trySelfJIT() -> Bool {
        let r = ptrace(PT_TRACE_ME, 0, nil, 0)
        guard r == 0 else { return false }
        var flag: UInt32 = CS_DEBUGGED
        let cr = csops(getpid(), CS_OPS_SET_STATUS, &flag, MemoryLayout<UInt32>.size)
        return cr == 0
    }

    func importPairingFile(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let dest = pairingFileDestination
        do {
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            pairingFileURL = dest
            pairingFileName = url.lastPathComponent
        } catch {
            status = .failed("ペアリングファイルのインポートに失敗: \(error.localizedDescription)")
        }
    }

    var pairingFileDestination: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JIT/device.mobiledevicepairing")
    }

    var hasPairingFile: Bool {
        FileManager.default.fileExists(atPath: pairingFileDestination.path)
    }

    func loadExistingPairingFile() {
        if hasPairingFile {
            pairingFileURL = pairingFileDestination
            pairingFileName = pairingFileDestination.lastPathComponent
        }
    }
}

extension Notification.Name {
    static let kernelOpenURL = Notification.Name("KernelOpenURL")
}

import SwiftUI

struct JITSettingsView: View {
    @EnvironmentObject private var jitService: JITService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                statusSection
                actionSection
                pairingFileSection
            }
            .navigationTitle("JIT設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        Section("ステータス") {
            HStack {
                Text("JIT状態")
                Spacer()
                statusBadge
            }

            if jitService.status == .enabled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("JITが有効です")
                        .foregroundColor(.green)
                }
            } else if case .failed(let message) = jitService.status {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var statusBadge: some View {
        Group {
            switch jitService.status {
            case .enabled:
                Text("有効")
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(8)
            case .notEnabled:
                Text("無効")
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(8)
            case .enabling:
                Text("有効化中...")
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .cornerRadius(8)
            case .failed:
                Text("失敗")
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(8)
            case .unknown:
                Text("不明")
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray)
                    .cornerRadius(8)
            }
        }
    }

    private var actionSection: some View {
        Section("アクション") {
            Button(action: jitService.enableJIT) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("JITを有効化")
                }
            }
            .disabled(jitService.status == .enabling)

            Button(action: jitService.checkJITStatus) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("ステータスを再確認")
                }
            }
        }
    }

    private var pairingFileSection: some View {
        Section("ペアリングファイル") {
            if jitService.hasPairingFile {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(jitService.pairingFileName ?? "ペアリングファイル")
                    Spacer()
                    Button("削除") {
                        try? FileManager.default.removeItem(at: jitService.pairingFileDestination)
                        jitService.pairingFileURL = nil
                        jitService.pairingFileName = nil
                    }
                    .foregroundColor(.red)
                }
            } else {
                HStack {
                    Image(systemName: "doc")
                    Text("ペアリングファイルがありません")
                }
                .foregroundColor(.secondary)
            }

            Button("ペアリングファイルをインポート") {
                showFilePicker()
            }
        }
    }

    private func showFilePicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = DocumentPickerDelegate { url in
            jitService.importPairingFile(from: url)
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(picker, animated: true)
        }
    }
}

class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let completion: (URL) -> Void

    init(completion: @escaping (URL) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            completion(url)
        }
    }
}

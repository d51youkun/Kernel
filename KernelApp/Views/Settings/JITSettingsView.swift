// JITSettingsView.swift
// JIT 有効化のための設定画面

import SwiftUI
import UniformTypeIdentifiers

struct JITSettingsView: View {
    @EnvironmentObject var jit: JITService
    @State private var showPairingImporter = false

    var body: some View {
        Form {
            Section {
                HStack {
                    statusIcon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle).font(.headline)
                        Text(statusDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if jit.status != .enabled {
                    Button {
                        jit.enableJIT()
                    } label: {
                        if case .enabling = jit.status {
                            HStack {
                                ProgressView()
                                Text("有効化中…")
                            }
                        } else {
                            Label("JITを有効化する", systemImage: "bolt.fill")
                        }
                    }
                }
            } header: {
                Text("JIT (Just-In-Time)")
            } footer: {
                Text("llama.cpp の Metal 推論には JIT が必要です。\n\n手順:\n1. 上のボタンをタップ (セルフJITを試します)\n2. 失敗したら StikJIT / StikDebug / SideStore をインストールしてからもう一度タップ\n3. それでも失敗する場合は、ペアリングファイル (.mobiledevicepairing) を下から読み込んでください")
            }

            Section {
                Button {
                    showPairingImporter = true
                } label: {
                    Label("ペアリングファイルを読み込む", systemImage: "square.and.arrow.down")
                }
                if let name = jit.pairingFileName {
                    LabeledContent("読み込み済み", value: name)
                }
            } header: {
                Text("ペアリングファイル (任意)")
            }
        }
        .navigationTitle("JIT設定")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showPairingImporter,
                      allowedContentTypes: [.data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                jit.importPairingFile(from: url)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch jit.status {
        case .enabled:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
        case .enabling:
            Image(systemName: "bolt.badge.clock")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)
        default:
            Image(systemName: "bolt.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
        }
    }

    private var statusTitle: String {
        switch jit.status {
        case .enabled:   return "JIT 有効"
        case .enabling:  return "有効化中…"
        case .notEnabled: return "JIT 無効"
        case .unknown:   return "状態を確認中…"
        case .failed(let msg): return msg
        }
    }

    private var statusDetail: String {
        switch jit.status {
        case .enabled: return "GPU (Metal) 推論が利用できます"
        case .enabling: return "StikJIT などのツールを呼び出しています…"
        case .notEnabled: return "有効化ボタンをタップしてください"
        case .unknown: return ""
        case .failed: return ""
        }
    }
}

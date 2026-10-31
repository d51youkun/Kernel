// SettingsView.swift
// モデル管理設定画面（追加・名前変更・削除）

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var modelManager: ModelManager

    @State private var showImporter     = false
    @State private var showRenameAlert  = false
    @State private var renamingModel:  ModelEntry?
    @State private var renameText      = ""
    @State private var importError:    String?

    // GGUF の UTType
    private let ggufType = UTType(filenameExtension: "gguf") ?? .data

    var body: some View {
        NavigationStack {
            List {
                // ── モデルセクション ──
                Section {
                    if modelManager.models.isEmpty {
                        emptyModelsRow
                    } else {
                        ForEach(modelManager.models) { model in
                            ModelRow(model: model) {
                                renamingModel = model
                                renameText    = model.displayName
                                showRenameAlert = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation { modelManager.delete(model) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Installed Models")
                } footer: {
                    Text("GGUFファイルは「＋」ボタンかFiles.app経由でDocuments/Modelsに追加してください。")
                }

                // ── エラーセクション ──
                if let err = importError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // ── JIT 情報セクション ──
                Section {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("JIT: StickJIT")
                                .font(.body.weight(.medium))
                            Text("StickJITでJITを有効にするとCPU推論が高速化されます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Link("StickJIT の使い方", destination: URL(string: "https://github.com/khanhduytran0/SparseBox")!)
                } header: {
                    Text("JIT")
                }

                // ── アプリ情報 ──
                Section {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Backend", value: "llama.cpp (Metal)")
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            // ── ファイルインポーター ──
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [ggufType],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        try modelManager.importModel(from: url)
                        importError = nil
                    } catch CocoaError.fileWriteFileExists {
                        importError = "同名のモデルが既に存在します。"
                    } catch {
                        importError = error.localizedDescription
                    }
                case .failure(let err):
                    if (err as NSError).code != NSUserCancelledError {
                        importError = err.localizedDescription
                    }
                }
            }
            // ── 名前変更アラート ──
            .alert("Rename Model", isPresented: $showRenameAlert) {
                TextField("Display Name", text: $renameText)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let m = renamingModel, !renameText.isEmpty {
                        modelManager.rename(m, to: renameText)
                    }
                }
            } message: {
                Text("Enter a new display name for this model.")
            }
        }
    }

    // ── サブビュー ────────────────────────────────

    private var emptyModelsRow: some View {
        Button {
            showImporter = true
        } label: {
            Label("Add GGUF Model…", systemImage: "plus.circle.fill")
                .foregroundStyle(.blue)
        }
    }
}

/// 1モデルの行ビュー
private struct ModelRow: View {
    let model: ModelEntry
    let onRename: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "cpu.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(model.fileName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let size = model.fileSizeString as String? {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button(action: onRename) {
                Image(systemName: "pencil")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

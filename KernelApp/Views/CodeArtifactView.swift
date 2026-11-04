import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct SourceFile: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(_ source: String) { data = Data(source.utf8) }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct CodeArtifactView: View {
    @EnvironmentObject private var store: AppStore
    let code: CodeDocument
    @State private var exporting = false
    @State private var preview = false
    @State private var action: String?
    @State private var path = ""
    @State private var working = false
    @State private var result = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(code.language.isEmpty ? "code" : code.language, systemImage: "chevron.left.forwardslash.chevron.right").font(.caption.monospaced())
                Spacer()
                Button { UIPasteboard.general.string = code.source } label: { Image(systemName: "doc.on.doc") }.accessibilityLabel("コードをコピー")
                Button { exporting = true } label: { Image(systemName: "arrow.down.to.line") }.accessibilityLabel("コードをダウンロード")
                Menu {
                    Button("ファイルに保存", systemImage: "square.and.arrow.down") { exporting = true }
                    if code.fileName.hasSuffix(".html") || code.fileName.hasSuffix(".js") {
                        Button("実行・コンソール", systemImage: "play") { preview = true }
                    }
                    Button("GitHubにコミット", systemImage: "arrow.triangle.branch") { path = code.fileName; action = "github" }
                    Button("Cloudflareに公開", systemImage: "cloud") { action = "cloudflare" }
                } label: { Image(systemName: "ellipsis") }
            }.buttonStyle(.plain).padding(12).background(Color.primary.opacity(0.06))
            ScrollView(.horizontal) { Text(code.source).font(.system(.subheadline, design: .monospaced)).textSelection(.enabled).padding(16) }
            if working { ProgressView("実行中…").padding(12) }
            if !result.isEmpty { Text(result).font(.caption).textSelection(.enabled).padding(12) }
        }
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .fileExporter(isPresented: $exporting, document: SourceFile(code.source), contentType: .data, defaultFilename: code.fileName) { outcome in
            if case .failure(let error) = outcome { result = error.localizedDescription }
        }
        .sheet(isPresented: $preview) { CodeConsoleScreen(code: code) }
        .alert(action == "github" ? "GitHubに書き込み" : "インターネットに公開", isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } })) {
            if action == "github" { TextField("保存先ファイルパス", text: $path) }
            Button("キャンセル", role: .cancel) { action = nil }
            Button("実行", role: .destructive) {
                let target = action; action = nil; working = true
                Task {
                    defer { working = false }
                    do {
                        result = target == "github" ? try await ConnectedAccounts.push(code, path: path, config: store.workspace) : try await ConnectedAccounts.deploy(code, config: store.workspace)
                    } catch { result = error.localizedDescription }
                }
            }
        } message: {
            Text(action == "github" ? "\(store.workspace.githubRepository) / \(store.workspace.githubBranch) に原文をコミットします。同名ファイルは更新されます。" : "\(store.workspace.workerName) を上書きし、誰でもアクセス可能なURLに公開します。コードに秘密情報が含まれていないことを確認してください。")
        }
    }
}

private struct CodeConsoleScreen: View {
    let code: CodeDocument
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [String] = []
    @State private var run = UUID()
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("隔離されたWebKitで実行します。ネットワーク・ファイル・アプリのトークンにはアクセスできません。JSはWebKit管理下で動作し、ネイティブJITやLLDBではありません。").font(.caption).foregroundStyle(.secondary).padding()
                SandboxedCode(code: code, logs: $logs).id(run)
                ScrollView { Text(logs.joined(separator: "\n")).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
                    .frame(height: 180).background(Color.primary.opacity(0.05))
            }.navigationTitle("プレビュー・Console")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button("再実行") { logs = []; run = UUID() } }
                }
        }
    }
}

private struct SandboxedCode: UIViewRepresentable {
    let code: CodeDocument
    @Binding var logs: [String]
    func makeCoordinator() -> Coordinator { Coordinator(logs: $logs) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "console")
        let script = """
        ['log','warn','error','info'].forEach(k => { console[k] = (...args) => window.webkit.messageHandlers.console.postMessage(k + ': ' + args.map(x => {try{return typeof x==='string'?x:JSON.stringify(x)}catch{return String(x)}}).join(' ')); });
        window.addEventListener('error', e => console.error(e.message + ' @' + e.lineno));
        window.addEventListener('unhandledrejection', e => console.error(String(e.reason)));
        """
        config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        let view = WKWebView(frame: .zero, configuration: config); view.navigationDelegate = context.coordinator
        let csp = "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval'; style-src 'unsafe-inline'; img-src data:; connect-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'\">"
        let html: String
        if code.fileName.hasSuffix(".js") {
            let literal = String(data: (try? JSONEncoder().encode(code.source)) ?? Data("\"\"".utf8), encoding: .utf8)!.replacingOccurrences(of: "<", with: "\\u003c")
            html = csp + "<script>try{(0,eval)(\(literal))}catch(e){console.error(String(e))}</script>"
        } else { html = csp + code.source }
        view.loadHTMLString(html, baseURL: nil)
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading(); uiView.configuration.userContentController.removeScriptMessageHandler(forName: "console")
    }
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        @Binding var logs: [String]
        init(logs: Binding<[String]>) { _logs = logs }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let text = message.body as? String { if logs.count >= 200 { logs.removeFirst() }; logs.append(String(text.prefix(4000))) }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
        }
    }
}

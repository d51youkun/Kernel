import SwiftUI

struct ConnectionsScreen: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            Section("AI接続") {
                Picker("回答エンジン", selection: $store.workspace.provider) {
                    Text("iPad内のGGUF").tag("local")
                    Text("OpenAI互換API").tag("api")
                }
                TextField("API Base URL", text: $store.workspace.apiBase).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("モデル名", text: $store.workspace.apiModel).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecretEditor(account: "openai", title: "APIキー", verifiable: false)
                Text("APIは別途契約・従量課金が必要です。APIを使用すると会話・カスタム指示・メモリ・添付の抽出テキストが設定先へ送信されます。ChatGPTのログインやPlus契約はAPIキーの代わりにはなりません。HTTPS接続先を必ず確認してください。").font(.caption).foregroundStyle(.secondary)
            }
            Section("GitHub") {
                SecretEditor(account: "github", title: "Fine-grained PAT", verifiable: true)
                TextField("owner/repository", text: $store.workspace.githubRepository)
                TextField("ブランチ", text: $store.workspace.githubBranch)
                Link("GitHubでトークンを作成", destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!)
                Text("対象リポジトリのContents: Read and write権限が必要です。コードのメニューから確認後にコミットできます。既存ファイルはSHAによる競合検出を行います。").font(.caption).foregroundStyle(.secondary)
            }.textInputAutocapitalization(.never).autocorrectionDisabled()
            Section("Cloudflare") {
                SecretEditor(account: "cloudflare", title: "API Token", verifiable: true)
                TextField("Account ID（32桁）", text: $store.workspace.cloudflareAccount)
                TextField("Worker名", text: $store.workspace.workerName)
                Link("Cloudflare API Tokens", destination: URL(string: "https://dash.cloudflare.com/profile/api-tokens")!)
                Text("Workers Scripts: Edit権限と対象Accountが必要です。単一HTMLまたはES module Workerをworkers.devへ公開します。同名Workerを上書きするため、コードごとに確認します。依存パッケージのビルドやPages連携は未対応です。").font(.caption).foregroundStyle(.secondary)
            }.textInputAutocapitalization(.never).autocorrectionDisabled()
            Section("Googleアカウント（アクセストークン連携）") {
                SecretEditor(account: "google", title: "Google OAuth access token", verifiable: true)
                Text("openid・emailスコープの有効なOAuthアクセストークンでアカウント情報を確認します。Googleログイン画面・トークンの自動更新・Drive連携は未実装です。トークン期限切れ時は再設定が必要です。接続確認に成功するまでは連携済みと表示しません。").font(.caption).foregroundStyle(.secondary)
            }
            Section("認証情報") {
                Text("トークンはこのデバイスのKeychainに保存します。会話の書き出し・GitHubへのプッシュに含めません。接続を解除するとKeychainから削除します。").font(.caption)
            }
        }.navigationTitle("アカウント・API").onDisappear { store.persist() }.disabled(store.busy)
    }
}

private struct SecretEditor: View {
    let account: String
    let title: String
    let verifiable: Bool
    @State private var value = ""
    @State private var status = ""
    @State private var working = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SecureField(title, text: $value).textInputAutocapitalization(.never).autocorrectionDisabled()
            HStack {
                Button("Keychainに保存") {
                    do { try CredentialVault.save(value, account: account); status = "保存済み（接続未確認）" }
                    catch { status = error.localizedDescription }
                }
                if verifiable {
                    Button("接続を確認") {
                        working = true
                        Task {
                            defer { working = false }
                            do { status = "接続確認済み: " + (try await ConnectedAccounts.verify(account)) }
                            catch { status = error.localizedDescription }
                        }
                    }
                }
                Button("解除", role: .destructive) {
                    do { try CredentialVault.save("", account: account); value = ""; status = "解除しました" }
                    catch { status = error.localizedDescription }
                }
            }.font(.caption).disabled(working)
            if working { ProgressView() }
            if !status.isEmpty { Text(status).font(.caption).textSelection(.enabled) }
        }.onAppear { value = CredentialVault.read(account) }.onChange(of: value) { _, _ in status = "変更未保存" }
    }
}

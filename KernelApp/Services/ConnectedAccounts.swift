import Foundation

enum ConnectedAccounts {
    static func request(_ url: URL, token: String, method: String = "GET", body: Data? = nil, contentType: String = "application/json") async throws -> [String: Any] {
        guard !token.isEmpty else { throw KernelError.message("先に設定でトークンを保存してください。") }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Kernel-iPad", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirectDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw KernelError.message("接続先がHTTP \(status)を返しました。権限・対象リポジトリ・Account IDを確認してください。")
        }
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if result["success"] as? Bool == false { throw KernelError.message("Cloudflare APIが操作を拒否しました。トークン権限・入力値を確認してください。") }
        return result
    }
    static func verify(_ provider: String) async throws -> String {
        let urls = ["github": "https://api.github.com/user", "cloudflare": "https://api.cloudflare.com/client/v4/user/tokens/verify", "google": "https://openidconnect.googleapis.com/v1/userinfo"]
        guard let address = urls[provider], let url = URL(string: address) else { throw KernelError.message("未対応の接続先です。") }
        let result = try await request(url, token: CredentialVault.read(provider))
        if provider == "github", let login = result["login"] as? String { return login }
        if provider == "google", let email = result["email"] as? String { return email }
        if provider == "cloudflare", let info = result["result"] as? [String: Any], info["status"] as? String == "active" { return "有効なAPI Token" }
        throw KernelError.message("アカウントを確認できませんでした。")
    }
    static func push(_ code: CodeDocument, path: String, config: WorkspaceConfiguration) async throws -> String {
        let repo = config.githubRepository.split(separator: "/")
        let valid: (String) -> Bool = { !$0.isEmpty && $0.range(of: "^[A-Za-z0-9_.-]+$", options: .regularExpression) != nil && $0 != "." && $0 != ".." }
        guard repo.count == 2, repo.allSatisfy({ valid(String($0)) }), !path.hasPrefix("/"), path.split(separator: "/").allSatisfy({ valid(String($0)) }), !path.isEmpty, !config.githubBranch.isEmpty else {
            throw KernelError.message("リポジトリはowner/repo形式、ファイルパスは相対パスで指定してください。")
        }
        let token = CredentialVault.read("github")
        let url = URL(string: "https://api.github.com/repos/\(repo[0])/\(repo[1])/contents")!.appendingPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "ref", value: config.githubBranch)]
        var body: [String: Any] = ["message": "Add \(path) from Kernel", "content": Data(code.source.utf8).base64EncodedString(), "branch": config.githubBranch]
        // Only 404 is interpreted as a new file. Never overwrite after another kind of error.
        var lookup = URLRequest(url: components.url!)
        lookup.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        lookup.setValue("Kernel-iPad", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirectDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: lookup)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 200 {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let sha = object["sha"] as? String else { throw KernelError.message("既存ファイルのSHAを取得できませんでした。") }
            body["sha"] = sha
        } else if status != 404 { throw KernelError.message("既存ファイルの確認に失敗しました（HTTP \(status)）。") }
        let result = try await request(url, token: token, method: "PUT", body: JSONSerialization.data(withJSONObject: body))
        guard let commit = result["commit"] as? [String: Any], let link = commit["html_url"] as? String else { throw KernelError.message("コミット結果を確認できませんでした。") }
        return link
    }
    static func deploy(_ code: CodeDocument, config: WorkspaceConfiguration) async throws -> String {
        guard config.cloudflareAccount.range(of: "^[a-fA-F0-9]{32}$", options: .regularExpression) != nil,
              config.workerName.range(of: "^[a-z0-9][a-z0-9-]{0,62}$", options: .regularExpression) != nil else {
            throw KernelError.message("32桁のCloudflare Account IDと英小文字・数字・ハイフンのWorker名を設定してください。")
        }
        let isHTML = code.fileName.hasSuffix(".html")
        guard isHTML || code.fileName.hasSuffix(".js") else { throw KernelError.message("デプロイは単一HTML、または依存のないES module WorkerのJavaScriptに対応します。") }
        let source: String
        if isHTML {
            let literal = String(data: try JSONEncoder().encode(code.source), encoding: .utf8)!
            source = "export default { async fetch() { return new Response(\(literal), {headers: {'content-type': 'text/html; charset=utf-8', 'x-content-type-options': 'nosniff'}}); } };"
        } else { source = code.source }
        let boundary = "Kernel-\(UUID().uuidString)"
        let metadata = try JSONSerialization.data(withJSONObject: ["main_module": "index.js", "compatibility_date": "2026-11-04", "observability": ["enabled": true, "traces": ["enabled": true]]])
        var body = Data()
        func append(_ value: String) { body.append(Data(value.utf8)) }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"metadata\"\r\nContent-Type: application/json\r\n\r\n")
        body.append(metadata)
        append("\r\n--\(boundary)\r\nContent-Disposition: form-data; name=\"index.js\"; filename=\"index.js\"\r\nContent-Type: application/javascript+module\r\n\r\n\(source)\r\n--\(boundary)--\r\n")
        let base = "https://api.cloudflare.com/client/v4/accounts/\(config.cloudflareAccount)/workers"
        let token = CredentialVault.read("cloudflare")
        _ = try await request(URL(string: "\(base)/scripts/\(config.workerName)")!, token: token, method: "PUT", body: body, contentType: "multipart/form-data; boundary=\(boundary)")
        _ = try await request(URL(string: "\(base)/scripts/\(config.workerName)/subdomain")!, token: token, method: "POST", body: JSONSerialization.data(withJSONObject: ["enabled": true]))
        let response = try await request(URL(string: "\(base)/subdomain")!, token: token)
        guard let result = response["result"] as? [String: Any], let subdomain = result["subdomain"] as? String else { throw KernelError.message("アップロード済みですが公開URLを確認できません。Cloudflare Dashboardを確認してください。") }
        return "https://\(config.workerName).\(subdomain).workers.dev"
    }
}

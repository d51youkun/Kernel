import Foundation

struct CloudChatService {
    struct Event: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { var content: String? }
            var delta: Delta
            var finish_reason: String?
        }
        var choices: [Choice]
    }
    /// No retries after any emitted token: a disconnected stream is shown as interrupted.
    func stream(messages: [[String: String]], config: WorkspaceConfiguration, maxTokens: Int,
                onUpdate: @MainActor (String) -> Void) async throws -> (text: String, limited: Bool) {
        guard let base = URL(string: config.apiBase), base.scheme == "https", base.host != nil,
              base.user == nil, base.password == nil, base.query == nil else {
            throw KernelError.message("API URLは認証情報・クエリを含まないHTTPS URLを指定してください。")
        }
        let token = CredentialVault.read("openai")
        guard !token.isEmpty else { throw KernelError.message("設定でAPIキーを保存してください。ChatGPTの契約とは別にAPI利用料が発生します。") }
        var request = URLRequest(url: base.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"; request.timeoutInterval = 180
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": config.apiModel, "messages": messages, "stream": true, "max_tokens": maxTokens])
        // Ephemeral sessions avoid persisting chat content in an HTTP cache.
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirectDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw KernelError.message("API接続に失敗しました（HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)）。キー・モデル名・利用上限を確認してください。")
        }
        var result = "", finish: String?, ended = false, lastUpdate = Date.distantPast
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { ended = true; break }
            guard let data = payload.data(using: .utf8) else { continue }
            let event = try JSONDecoder().decode(Event.self, from: data)
            for choice in event.choices {
                result += choice.delta.content ?? ""
                if let reason = choice.finish_reason { finish = reason }
            }
            if Date().timeIntervalSince(lastUpdate) > 0.06 { await onUpdate(result); lastUpdate = Date() }
        }
        await onUpdate(result)
        guard ended || finish != nil else { throw KernelError.message("通信が途中で切れました。受信済みの回答は保持しています。「続きを生成」を使用できます。") }
        if finish == "content_filter" { throw KernelError.message("提供元のコンテンツ制限で停止しました。受信済みの内容は保持しています。") }
        return (result, finish == "length")
    }
}

final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

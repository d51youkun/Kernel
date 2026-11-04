import Foundation

struct WorkspaceConfiguration: Codable, Equatable {
    var provider = "local"
    var apiBase = "https://api.openai.com/v1"
    var apiModel = "gpt-4.1-mini"
    var autoTranslate = true
    var autoContinue = true
    var githubRepository = ""
    var githubBranch = "main"
    var cloudflareAccount = ""
    var workerName = "kernel-preview"
    var googleClientID = ""
}

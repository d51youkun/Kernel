// AppSettings.swift
// 推論パラメータなどのアプリ設定 (UserDefaults に永続化)

import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// 温度 (0.0 - 2.0)
    @Published var temperature: Double { didSet { save() } }
    /// Top-K
    @Published var topK: Int { didSet { save() } }
    /// Top-P (0.0 - 1.0)
    @Published var topP: Double { didSet { save() } }
    /// 1 回の生成で出力する最大トークン数
    @Published var maxNewTokens: Int { didSet { save() } }
    /// コンテキスト長
    @Published var contextLength: Int { didSet { save() } }
    /// AI の回答を日本語に強制する
    @Published var forceJapanese: Bool { didSet { save() } }
    /// 回答を読み上げる
    @Published var speakResponses: Bool { didSet { save() } }

    private struct Snapshot: Codable {
        var temperature: Double
        var topK: Int
        var topP: Double
        var maxNewTokens: Int
        var contextLength: Int
        var forceJapanese: Bool
        var speakResponses: Bool
    }

    private let defaults = UserDefaults.standard
    private let storageKey = "kernel.settings.v2"

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let s = try? JSONDecoder().decode(Snapshot.self, from: data) {
            temperature = s.temperature
            topK = s.topK
            topP = s.topP
            maxNewTokens = s.maxNewTokens
            contextLength = s.contextLength
            forceJapanese = s.forceJapanese
            speakResponses = s.speakResponses
        } else {
            temperature = 0.8
            topK = 40
            topP = 0.95
            maxNewTokens = 1024
            contextLength = 4096
            forceJapanese = true
            speakResponses = false
        }
    }

    private func save() {
        let snapshot = Snapshot(temperature: temperature,
                                topK: topK,
                                topP: topP,
                                maxNewTokens: maxNewTokens,
                                contextLength: contextLength,
                                forceJapanese: forceJapanese,
                                speakResponses: speakResponses)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: storageKey)
        }
    }
}

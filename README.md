# Kernel v2.0.0

iPad用ローカルAIチャットアプリ — llama.cpp ベースの完全オンデバイス推論

## ⚠️ v2.0 について

このバージョンは **v1.x をゼロから作り直したもの** です。
v1.x では以下の問題がありビルド・動作が不完全でした:

| 問題 | v2.0 での修正 |
|---|---|
| `csops` / `ptrace` が未宣言でコンパイルエラー | `JITService.swift` に `@_silgen_name` 宣言を追加 |
| llama.cpp の API と xcframework の不一致 | 最新 `b12020` に固定し、全 API をヘッダと突き合わせて検証 |
| コミット済み xcodeproj が project.yml と不整合 | xcodeproj はコミットせず CI で毎回生成 |
| ブリッジのメモリ管理・キャンセル処理の不備 | キュー設計を整理し、コンテキスト溢れチェックを追加 |

## 🎯 機能

- 🤖 **ローカルAI推論** — llama.cpp (Metal GPU・全レイヤー) 完全オンデバイス
- 🎨 **iPad ChatGPT風UI** — NavigationSplitView による横画面対応
- 🗣️ **音声入力** — 日本語音声認識 (SFSpeechRecognizer ja-JP)
- 🇯🇵 **日本語出力強制** — システムプロンプトで日本語に統一 (ON/OFF可)
- 📊 **トークン統計** — トークン数と生成速度 (tok/s) の表示
- 👍👎 **フィードバック** / 📅 **日付別グループ化** / 🗄️ **アーカイブ** / 📌 **ピン留め**
- 🔊 **読み上げ** (TTS) / 🔍 **会話検索**
- ⚡ **JIT有効化支援** — セルフJIT → StikJIT → StikDebug → SideStore の自動フォールバック

## 📦 IPA の入手方法 (一番かんたん)

1. このリポジトリの **Actions → Build IPA** を開いて手動実行 (workflow_dispatch)
2. 完了したら Artifacts から `Kernel-IPA` をダウンロード
3. [タグ](../../releases) (`v2.0.0`) を付けると **Release.yml が自動で IPA をリリースに添付**します

## 📲 インストール

1. `Kernel.ipa` をダウンロード
2. AltStore / Sideloadly / Xcode で iPad にインストール
3. 設定 → 一般 → VPNとデバイス管理 で証明書を信頼
4. アプリ内 **JIT設定** で JIT を有効化 (StikJIT などの JIT ツールが必要)

## 🗃️ モデルの入れ方

1. Hugging Face などから **GGUF モデル** をダウンロード
   - 例: `Qwen3-1.7B-Q4_K_M.gguf` (約1GB、iPad のメモリに収まる)
2. ファイルアプリで **Kernel の `Documents/Models/`** に保存
   (設定 → モデル → 「GGUFモデルを追加」でもOK)
3. 設定 → モデル で選択してチャット開始

## 🔨 ローカルビルド (macOS)

```bash
git clone https://github.com/d51youkun/Kernel.git
cd Kernel
./build_ipa.sh     # XcodeGen・llama.xcframework を自動で揃えて IPA まで作る
```

または Xcode で:

```bash
brew install xcodegen
xcodegen generate
open KernelApp.xcodeproj   # ⌘R
```

## 📁 プロジェクト構造

```
Kernel/
├── KernelApp/
│   ├── App/KernelApp.swift          # エントリポイント
│   ├── Models/                      # Conversation / Message / ModelEntry / AppSettings
│   ├── ViewModels/ChatViewModel.swift
│   ├── Views/                       # Chat / Sidebar / Settings / Theme
│   ├── Services/
│   │   ├── LlamaService.swift       # 推論サービス
│   │   ├── ModelManager.swift       # GGUF 管理
│   │   ├── SpeechRecognitionService.swift
│   │   └── JITService.swift
│   └── Bridge/LlamaBridge.{h,mm}    # llama.cpp C API ブリッジ (b12020 検証済み)
├── Frameworks/                      # ビルド時に llama.xcframework を自動ダウンロード
├── .github/workflows/               # build.yml / release.yml
└── project.yml                      # XcodeGen 設定
```

## 🔑 必要な権限

- **マイク使用許可** (`NSMicrophoneUsageDescription`)
- **音声認識許可** (`NSSpeechRecognitionUsageDescription`)

## 📄 ライセンス / 謝辞

- MIT License
- [llama.cpp](https://github.com/ggml-org/llama.cpp) — ローカルLLM推論エンジン
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — プロジェクト生成

## 📝 バージョン履歴

- **v2.0.0 (2026-10-31)** — ゼロから作り直し。コンパイルエラー解消、llama.cpp b12020 対応、CI ビルド刷新
- v1.0.0 (2026-10-31) — 初版

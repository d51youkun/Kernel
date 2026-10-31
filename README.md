# Kernel

iPad用ローカルAIチャットアプリ - llama.cppベースのオンデバイスAI推論

## 🎯 主な機能

- 🤖 **ローカルAI推論**: llama.cppを使用した完全オンデバイス動作
- 🎨 **iPad ChatGPT風UI**: モダンで使いやすいチャットインターフェース
- 🗣️ **音声入力**: 日本語音声認識によるハンズフリー入力
- 🇯🇵 **日本語出力強制**: AIの回答を自動的に日本語に統一
- 📊 **トークン統計**: 生成速度とトークン数のリアルタイム表示
- 👍👎 **フィードバック機能**: 各回答に対する評価機能
- 📅 **日付別グループ化**: 会話を日付ごとに自動整理
- 🗄️ **アーカイブ機能**: 古い会話をアーカイブ可能
- 📱 **iPad最適化**: 横向き・縦向き両対応

## 📦 インストール方法

### 方法1: GitHubリリースからダウンロード

1. [Releases](https://github.com/d51youkun/Kernel/releases)ページから最新の`Kernel.ipa`をダウンロード
2. AltStore、Sideloadly、またはXcodeを使用してiPadにインストール
3. 設定 > 一般 > VPNとデバイス管理で証明書を信頼

### 方法2: ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/d51youkun/Kernel.git
cd Kernel

# Xcodeプロジェクトを生成
.tools/xcodegen/bin/xcodegen generate

# Xcodeで開く
open Kernel.xcodeproj
```

## 🔧 開発環境

- Xcode 15.0以上
- iOS 17.0以上（iPad専用）
- Swift 5.10
- XcodeGen（プロジェクト生成）

## 🚀 ビルド方法

### XcodeGenでプロジェクト生成

```bash
chmod +x .tools/xcodegen/bin/xcodegen
.tools/xcodegen/bin/xcodegen generate
```

### Xcodeでビルド

1. `Kernel.xcodeproj`を開く
2. ターゲットを「Kernel」に設定
3. 実機またはシミュレータを選択
4. ⌘R でビルド＆実行

### コマンドラインでビルド

```bash
# デバッグビルド
xcodebuild -project Kernel.xcodeproj \
  -scheme Kernel \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)'

# リリースビルド（IPA生成）
xcodebuild -project Kernel.xcodeproj \
  -scheme Kernel \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Kernel.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath build/Kernel.xcarchive \
  -exportPath build \
  -exportOptionsPlist ExportOptions.plist
```

## 📁 プロジェクト構造

```
Kernel/
├── KernelApp/
│   ├── Models/          # データモデル（Conversation, Message）
│   ├── ViewModels/      # ビジネスロジック（ChatViewModel）
│   ├── Views/           # SwiftUI画面
│   │   ├── Chat/        # チャット画面
│   │   └── Sidebar/     # サイドバー
│   ├── Services/        # 外部サービス連携
│   │   ├── LlamaService.swift
│   │   └── SpeechRecognitionService.swift
│   └── Bridge/          # C++ブリッジ
├── Frameworks/          # llama.xcframework
├── .github/workflows/   # CI/CD
└── project.yml          # XcodeGen設定
```

## 🔑 必要な権限

アプリは以下の権限を要求します：

- **マイク使用許可** (`NSMicrophoneUsageDescription`): 音声入力機能
- **音声認識許可** (`NSSpeechRecognitionUsageDescription`): 音声→テキスト変換

## 🤝 貢献

プルリクエストを歓迎します！

1. このリポジトリをフォーク
2. フィーチャーブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 🙏 謝辞

- [llama.cpp](https://github.com/ggerganov/llama.cpp) - ローカルLLM推論エンジン
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) - Xcodeプロジェクト生成ツール

## 📝 バージョン履歴

### v1.0.0 (2026-10-31)

初回リリース

- iPad ChatGPT風UIの実装
- 音声入力機能
- 日本語出力強制
- トークン統計表示
- フィードバック・アーカイブ機能
- 日付別会話グループ化
- クラッシュ修正と安定性向上

# Kernel — Local AI for iPad (StickJIT Ready)

iPad上でローカルLLM（GGUFモデル）を実行するiPadOS専用AIチャットアプリです。  
ChatGPT for iPad 風のモダンなUI、GGUFモデルの追加・名前変更・削除管理、StickJIT による高速JIT推論をサポートしています。

---

## 主な特徴

- 🧠 **GGUF モデル対応**: `llama.cpp` バックエンドによるオンデバイス推論（Metal GPU & CPU）
- 💬 **ChatGPT for iPad UI**: 左サイドバー付きの分割画面、ストリーミング出力、自動タイトル生成
- ⚙️ **モデル管理**: Files.app からの GGUF インポート、表示名変更、不要モデルの削除
- ⚡ **StickJIT 対応**: `get-task-allow` エンタイトルメントを組み込み、SideStore / AltStore / SparseBox 等のツール経由で JIT を有効化可能
- 🚀 **GitHub Actions 自動ビルド**: push するだけで unsigned / ad-hoc IPA を自動生成し、Artifacts からダウンロード可能

---

## 構成

```
Kernel/
├── .github/workflows/
│   └── build.yml               # GitHub Actions による IPA 自動ビルド
├── KernelApp/
│   ├── App/                    # エントリポイント
│   ├── Bridge/                 # llama.cpp C/C++ API ラッパー (Objective-C++)
│   ├── Models/                 # 会話・メッセージ・モデルデータモデル
│   ├── Services/               # LlamaService (推論・ストリーミング), ModelManager (CRUD)
│   ├── ViewModels/             # ChatViewModel
│   ├── Views/                  # Sidebar, Chat, Settings, MessageBubble
│   ├── Info.plist              # iPad専用設定, ファイル共有許可
│   └── KernelApp.entitlements  # StickJIT 用 get-task-allow
├── project.yml                 # XcodeGen プロジェクト仕様
├── build_ipa.sh                # ローカル用ワンクリック IPA ビルドスクリプト
└── KernelApp.xcodeproj         # 生成済み Xcode プロジェクト
```

---

## ビルド方法

### ローカルでのビルド
```bash
chmod +x build_ipa.sh
./build_ipa.sh
```
ビルド完了後、ルートディレクトリに `Kernel.ipa` が生成されます。

### GitHub Actions でのビルド
本リポジトリを push すると、Actions タブでビルドが自動実行され、最新の `Kernel.ipa` が Artifacts からダウンロードできます。

---

## ライセンス

MIT License

# Kernel · iPad AI Workspace

iPadOS 18以降向けのSwiftUIアプリ。Bundle ID: `com.kernel.app.K5PVDY39NR`。

**ChatGPTの非公式クライアント／完全な複製ではありません。ChatGPTの全機能を実装したという主張はしません。**
v10は生成・翻訳・ファイル操作・外部連携を実装し直したバージョンです。既存の会話データは保持し、読めないデータは復旧コピーを作成します。

## 実装した機能

- iPad向けサイドバー、検索、会話・プロジェクト、ピン留め、アーカイブ、一時チャット、ライト／ダークモード。
- GGUFのインポートとllama.cppによるMetal／CPU推論。モデルファイルは別途必要です。
- OpenAI互換Chat Completions APIのSSEストリーミング。APIキー・URL・モデルを設定できます。
- カスタム指示、手動編集のメモリ、編集再送信、再生成、分岐、会話共有・JSON書き出し。
- 日本語出力指示と生成完了後の英語説明の自動翻訳。固有名詞・技術用語は維持する指示を与え、fenced codeは翻訳対象から除外します。翻訳品質はモデル依存であり、完全性は保証しません。失敗時は原文を保持します。
- 回答を約2秒間隔で保存。通信切断・出力上限・プロセス終了による未完了回答を完了扱いにしません。
- APIの出力上限では設定により最大3回自動継続。ローカル出力上限は明示し「続きを生成」で再開できます。継続による重複の排除はモデル依存です。
- コードブロックのコピー・ファイル保存（HTML、JS、Python等）。フェンス内のUTF-8原文と改行を保持します。
- HTML／JSのWebKitプレビューとconsole・例外表示。非永続ストア、CSPでネットワーク・フレーム・フォーム・ファイルアクセスを制限します。ネイティブアプリへのAPIブリッジやトークン提供はありません。
- テキスト・コード・PDFの文字抽出、画像のOCR、長文資料のローカル分割要約。画像の視覚理解ではありません。
- 日本語の音声入力（端末対応・権限が必要）、読み上げ。
- GitHub PATの検証、コード単体の作成／更新コミット（SHAによる競合検出）。Gitのclone・rebase等のフルクライアントではありません。
- Cloudflare API Tokenの検証、単一HTML／依存のないES module Workerの公開。同名Workerを更新します。
- Google OAuthアクセストークンによるユーザー情報確認。**ブラウザでのGoogleログイン・refresh token・Driveアクセスは未実装**。
- App Intentsによる「新しいチャット」「質問を入力欄に渡す」、`kernel://new?prompt=...` URL Scheme。
- WidgetKitの小・中サイズのチャット起動ウィジェット。会話・秘密情報はウィジェットに共有しません。
- StikJIT連携による内蔵デバッガの準備／接続UIと実行メモリの検証経路。**本バージョンでの実機JIT動作は未検証**です。

## 未対応・保証できないこと

ChatGPT独自のGPTs、Deep Research、Web検索、画像／動画生成、Realtime Voice、視覚モデル、自動メモリ、タスクのバックグラウンド実行、Pythonの実行環境、フルLLDBデバッガ、Google OAuthログイン画面は搭載していません。

ChatGPTのPlus等の契約はAPI利用権ではありません。APIには別途料金とキーが必要です。
外部APIを使う場合、会話・カスタム指示・メモリ・添付の抽出内容が設定先に送られます。

回答が「絶対に途中で止まらない」ことは保証できません。iPadOSのメモリ制限、バックグラウンド停止、提供元の利用制限、通信切断があります。生成中は自動ロックを抑止しますが、アプリをバックグラウンドに移すと停止し、受信済み内容を保持します。

## iPad Pro M4

M4 iPad Proは構成により9／10コア・8／16GBメモリです。CPUスレッドは実機の利用可能コア数以内に制限し、初期値は最大10。Metal GPUオフロードを利用します。10スレッドが常に最速とは限りません。Neural Engineの利用やJITによるllama.cpp高速化は行いません。

利用可能メモリの90%以上のサイズのモデルは読み込みを拒否します。モデルサイズ以外にもKVキャッシュ・GPUメモリが必要であり、このチェックでOOMを完全には防げません。実機ベンチマークは未実施です。

## アカウント設定

設定 → アカウント・API接続。

- トークンは`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`のKeychainに保存。バックアップ書き出し・コードコミットに含めません。
- GitHub: 対象リポジトリに限定したFine-grained PAT、Contents: Read and write。`owner/repository`とブランチを指定。
- Cloudflare: 対象AccountのWorkers Scripts: Edit権限を持つAPI Token、32桁のAccount ID。workers.devのサブドメインを事前にDashboardで作成してください。
- Google: `openid email`権限を持つ有効なアクセストークン。期限が切れたら再設定が必要です。
- 「保存済み」は「接続確認済み」ではありません。接続の確認を実行してください。

GitHubへの書き込み・Cloudflareへの公開は、各コードブロックのメニューから確認後にのみ実行します。秘密情報を含むコードを公開しないでください。

## JIT・署名

JITは任意機能です。GGUF推論・HTML/JS実行には不要です。
内蔵StikJITの利用には対応iPadOS、開発者モード、当該端末のpairing plist、LocalDevVPN、`get-task-allow`を保持した署名が必要です。OS・署名方式・拡張起動制限によって動作しません。
内蔵接続には非公開の拡張起動APIを含むため、現状はApp Store公開用の構成ではありません。接続UIはフルソースレベルデバッガではありません。

IPAは**アドホック署名（`codesign -s -`）の再署名用パッケージ**です。AppleのAd Hoc配布プロファイルで署名したものではありません。指定Bundle IDと全拡張に対応したプロビジョニングがない状態では、IPAをそのままタップしてインストールできません。サイドロード時の再署名と拡張・権限の維持が必要です。

## ビルド・テスト

必要: macOS、現行Xcode、XcodeGen、Python 3。StikJIT 1.5.0とllama.cpp b10549の配布バイナリを使用します。

```sh
brew install xcodegen
swift test
bash build_ipa.sh
```

`scripts/prepare_dependencies.py`は初回ダウンロード時のSHA-256を検証し、StikJITのSwift interface名衝突に対処します。

```sh
KERNEL_IPA_OUTPUT="$HOME/Downloads/Kernel-10.0.0.ipa" bash build_ipa.sh
```

`KERNEL_DERIVED_DATA`でビルド先を変更できます。XcodeGenの定義は`project.yml`です。
`KernelPreview`スキームはシミュレータでUI/APIの確認に使用し、GGUF推論・JITは実機のみです。

ローカルテストの対象はコードフェンス解析・ファイル名・改行保持です。実機推論、Google/GitHub/Cloudflare認証と実アカウントへの書き込み、JITは別途実機・認証情報を用いた検証が必要です。

## アイコン

深い青緑、淡いミントのK、中心の核を表すグリーンの点。ChatGPTや他社の商標アイコンは使用していません。
再生成: `swift scripts/generate_icon.swift "$PWD"`。

## 既存ファイル

`KernelApp.old`は従来のバックアップとして保持し、ビルド対象には含めません。既存の未追跡ローカル作業や認証情報は無断で削除しません。

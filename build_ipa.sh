#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== 🚀 Building Kernel for iPadOS (StickJIT Ready) ==="

# 1. Xcode のパス設定
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

# 2. xcodegen が無ければローカルポータブルバイナリを使用
if command -v xcodegen &> /dev/null; then
    XCODEGEN="xcodegen"
elif [ -f ".tools/xcodegen/bin/xcodegen" ]; then
    XCODEGEN=".tools/xcodegen/bin/xcodegen"
else
    echo "⬇️  Downloading portable XcodeGen..."
    mkdir -p .tools
    curl -sL https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip -o .tools/xcodegen.zip
    unzip -q .tools/xcodegen.zip -d .tools/
    rm .tools/xcodegen.zip
    XCODEGEN=".tools/xcodegen/bin/xcodegen"
fi

# 3. llama.xcframework が無ければダウンロード
if [ ! -d "Frameworks/llama.xcframework" ]; then
    echo "⬇️  Downloading official llama.xcframework..."
    mkdir -p Frameworks
    curl -L https://github.com/ggml-org/llama.cpp/releases/download/b10549/llama-b10549-xcframework.zip -o Frameworks/llama-xcframework.zip
    unzip -q Frameworks/llama-xcframework.zip -d Frameworks/
    mv Frameworks/build-apple/llama.xcframework Frameworks/
    rm -rf Frameworks/build-apple Frameworks/llama-xcframework.zip
fi

# 4. Xcode プロジェクト生成
echo "⚙️  Generating Xcode project..."
"$XCODEGEN" generate --spec project.yml

# 5. ビルド
echo "🔨 Compiling Release build..."
"$DEVELOPER_DIR/usr/bin/xcodebuild" build \
    -project KernelApp.xcodeproj \
    -scheme KernelApp \
    -destination "generic/platform=iOS" \
    -derivedDataPath ./build/DerivedData \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# 6. 署名 & IPA パッケージング
echo "📦 Signing with StickJIT get-task-allow & packaging IPA..."
APP_PATH="./build/DerivedData/Build/Products/Release-iphoneos/Kernel.app"
xattr -rc "$APP_PATH"
codesign -s - --force --entitlements KernelApp/KernelApp.entitlements "$APP_PATH"

rm -rf Payload Kernel.ipa
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qr Kernel.ipa Payload/
rm -rf Payload

echo "========================================="
echo "🎉 SUCCESS! IPA created at:"
echo "   $SCRIPT_DIR/Kernel.ipa ($(du -sh Kernel.ipa | cut -f1))"
echo "========================================="

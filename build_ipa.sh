#!/usr/bin/env bash
# ローカルで IPA をビルドするスクリプト (macOS + Xcode が必要)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LLAMA_VERSION="${LLAMA_VERSION:-b12020}"

echo "=== 🚀 Building Kernel for iPadOS ==="

# 1. xcodegen を用意
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

# 2. llama.xcframework を用意
if [ ! -d "Frameworks/llama.xcframework" ]; then
    echo "⬇️  Downloading llama.xcframework ${LLAMA_VERSION}..."
    mkdir -p Frameworks
    curl -fL "https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_VERSION}/llama-${LLAMA_VERSION}-xcframework.zip" \
      -o Frameworks/llama-xcframework.zip
    unzip -q Frameworks/llama-xcframework.zip -d Frameworks/
    if [ -d "Frameworks/build-apple/llama.xcframework" ]; then
        rm -rf Frameworks/llama.xcframework
        mv Frameworks/build-apple/llama.xcframework Frameworks/
    fi
    rm -rf Frameworks/build-apple Frameworks/llama-xcframework.zip
fi

# 3. Xcode プロジェクトを生成
echo "⚙️  Generating Xcode project..."
"$XCODEGEN" generate --spec project.yml

# 4. ビルド
echo "🔨 Compiling Release build..."
xcodebuild build \
    -project KernelApp.xcodeproj \
    -scheme KernelApp \
    -sdk iphoneos \
    -derivedDataPath ./build/DerivedData \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# 5. 署名 & IPA 化
echo "📦 Signing & packaging IPA..."
APP_PATH="./build/DerivedData/Build/Products/Release-iphoneos/Kernel.app"
xattr -rc "$APP_PATH"
codesign -s - --force --entitlements KernelApp/KernelApp.entitlements "$APP_PATH"

rm -rf Payload Kernel.ipa
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qr Kernel.ipa Payload/
rm -rf Payload

echo "========================================="
echo "🎉 SUCCESS! Kernel.ipa created:"
echo "   $SCRIPT_DIR/Kernel.ipa ($(du -sh Kernel.ipa | cut -f1))"
echo "========================================="

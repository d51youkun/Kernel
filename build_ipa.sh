#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
python3 scripts/prepare_dependencies.py
xcodegen generate --spec project.yml
DERIVED="${KERNEL_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/KernelRebuild}"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/kernel-ipa.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
DEVDIR="$(xcode-select -p)"
MACRO_DIR="$DEVDIR/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
MACRO_FLAGS=""
for lib in libSwiftUIMacros libObservationMacros libFoundationMacros; do
    if [ -f "$MACRO_DIR/$lib.dylib" ]; then MACRO_FLAGS="$MACRO_FLAGS -load-plugin-library $MACRO_DIR/$lib.dylib"; fi
done
xcodebuild build -project KernelApp.xcodeproj -scheme KernelApp -sdk iphoneos \
    -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" -configuration Release \
    OTHER_SWIFT_FLAGS="$MACRO_FLAGS" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
mkdir -p "$STAGING/Payload"
ditto "$DERIVED/Build/Products/Release-iphoneos/Kernel.app" "$STAGING/Payload/Kernel.app"
xattr -cr "$STAGING/Payload/Kernel.app"
while IFS= read -r -d '' framework; do codesign --force --sign - "$framework"; done < <(find "$STAGING/Payload/Kernel.app" -type d -name '*.framework' -print0)
while IFS= read -r -d '' extension; do codesign --force --sign - "$extension"; done < <(find "$STAGING/Payload/Kernel.app/PlugIns" -type d -name '*.appex' -print0)
codesign --force --sign - --entitlements KernelApp/KernelApp.entitlements "$STAGING/Payload/Kernel.app"
codesign --verify --deep --strict "$STAGING/Payload/Kernel.app"
OUTPUT="${KERNEL_IPA_OUTPUT:-$ROOT/Kernel.ipa}"
ditto -c -k --keepParent "$STAGING/Payload" "$OUTPUT"
echo "IPA created: $OUTPUT"
echo "Ad-hoc signed for re-signing/sideloading; not a provisioned installation IPA. JIT is not verified."

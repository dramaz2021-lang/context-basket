#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
bundle="dist/Context Basket.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_dir/ContextBasket" "$bundle/Contents/MacOS/ContextBasket.new"
mv -f "$bundle/Contents/MacOS/ContextBasket.new" "$bundle/Contents/MacOS/ContextBasket"
cp Sources/ContextBasketApp/Resources/Info.plist "$bundle/Contents/Info.plist"
swift scripts/make-icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$bundle/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$bundle"
printf 'Built %s\n' "$PWD/$bundle"

#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="VidCropper"
APP_BUNDLE="$ROOT/dist/$APP_NAME.app"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
    echo "→ Generating app icon…"
    swift "$ROOT/Tools/make_icon.swift"
fi

echo "→ Building release binary…"
swift build -c release --product "$APP_NAME"

echo "→ Assembling $APP_NAME.app…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$ROOT/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

echo "→ Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

echo "✓ Built $APP_BUNDLE"
echo "  Open it with: open \"$APP_BUNDLE\""

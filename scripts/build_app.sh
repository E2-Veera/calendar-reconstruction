#!/bin/zsh
# Builds "build/Calendar Reconstruction.app" (release, ad-hoc signed) from the Swift package.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"

ARCHS=(--arch arm64 --arch x86_64)   # universal: Apple Silicon + Intel
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/CalendarReconstruction"

APP="$ROOT/build/Calendar Reconstruction.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CalendarReconstruction"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Calendar Reconstruction</string>
    <key>CFBundleDisplayName</key><string>Calendar Reconstruction</string>
    <key>CFBundleIdentifier</key><string>com.e2info.calendarreconstruction</string>
    <key>CFBundleExecutable</key><string>CalendarReconstruction</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built: $APP"

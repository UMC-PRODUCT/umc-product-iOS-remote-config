#!/bin/sh
# UMC Launchpad.app 을 만든다. swift run 으로 띄운 실행 파일은 앱 번들이 없어 아이콘(AppIcon.icon)과 앱 이름이 안 보인다
set -eu
cd "$(dirname "$0")"

# Developer ID 인증서는 이 Mac 의 키체인에서 찾는다. 여러 인증서가 있으면 SIGNING_IDENTITY 로 지정한다
SIGNING_IDENTITY=${SIGNING_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1)}
[ -n "$SIGNING_IDENTITY" ] || { echo "Developer ID Application 인증서가 키체인에 없습니다" >&2; exit 1; }

# actool 은 상대 경로를 엉뚱한 위치 기준으로 풀어서 절대 경로로 넘긴다
APP="$PWD/.build/UMC Launchpad.app"
# 버전은 코드 한 곳(RemoteConfigEditorApp.version)에서만 관리한다
VERSION=$(sed -n 's/.*static let version = "\(.*\)"/\1/p' Sources/RemoteConfigEditor/RemoteConfigEditorApp.swift)

swift build -c release
BIN=$(swift build -c release --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/RemoteConfigEditor" "$APP/Contents/MacOS/"

# Liquid Glass 아이콘(.icon)은 Xcode 26 의 actool 로만 컴파일된다
xcrun actool "$PWD/AppIcon.icon" \
    --compile "$APP/Contents/Resources" \
    --app-icon AppIcon \
    --platform macosx \
    --target-device mac \
    --minimum-deployment-target 26.0 \
    --output-partial-info-plist "$PWD/.build/AppIcon-partial.plist" \
    --output-format human-readable-text

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>UMC Launchpad</string>
    <key>CFBundleDisplayName</key>
    <string>UMC Launchpad</string>
    <key>CFBundleIdentifier</key>
    <string>com.umc.product.tree</string>
    <key>CFBundleExecutable</key>
    <string>RemoteConfigEditor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
</dict>
</plist>
EOF

# 공증에 필요한 Hardened Runtime 과 안전한 타임스탬프를 포함해 서명한다
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "완료: $APP"

#!/bin/sh
# UMC Launchpad.app 을 DMG 로 묶어 GitHub 릴리즈로 올린다. 사용: ./release.sh 릴리즈노트.md
# 태그는 코드의 버전에서 만든다. 태그와 앱 버전이 어긋나면 업데이트 알림이 끝없이 뜬다
set -eu
cd "$(dirname "$0")"

NOTES=$(cd "$OLDPWD" && realpath "$1")
git diff --quiet HEAD || { echo "커밋하지 않은 변경이 있어요. 릴리즈할 코드를 커밋하고 push 한 뒤 다시 실행하세요"; exit 1; }

SIGNING_IDENTITY=${SIGNING_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1)}
[ -n "$SIGNING_IDENTITY" ] || { echo "Developer ID Application 인증서가 키체인에 없습니다" >&2; exit 1; }
NOTARY_PROFILE=${NOTARY_PROFILE:-UMCLaunchpadNotary}
export SIGNING_IDENTITY

./build-app.sh
VERSION=$(sed -n 's/.*static let version = "\(.*\)"/\1/p' Sources/RemoteConfigEditor/RemoteConfigEditorApp.swift)

# 앱을 먼저 공증하고 티켓을 붙인다
APP=".build/UMC Launchpad.app"
APP_ZIP=.build/UMC-Launchpad-notarization.zip
rm -f "$APP_ZIP"
ditto -c -k --keepParent "$APP" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

# Finder 창 배경과 아이콘 배치를 포함한 읽기/쓰기 이미지를 만든다
STAGE=.build/dmg
RWDMG=.build/UMC-Launchpad-rw.dmg
DMG=.build/UMC-Launchpad.dmg
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/UMC Launchpad.app"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
swift Assets/dmg-background.swift "$STAGE/.background/background.png"
hdiutil create -volname "UMC Launchpad" -srcfolder "$STAGE" -format UDRW -ov "$RWDMG"
MOUNT=
detach_mount() {
    [ -z "$MOUNT" ] || hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
}
trap detach_mount EXIT
ATTACH_OUTPUT=$(hdiutil attach "$RWDMG" -readwrite -noverify -noautoopen)
MOUNT=$(printf '%s\n' "$ATTACH_OUTPUT" | sed -n 's|.*\(/Volumes/.*\)$|\1|p' | tail -n 1)
[ -n "$MOUNT" ] || { echo "DMG 볼륨을 찾지 못했습니다" >&2; exit 1; }
osascript - "$MOUNT/.background/background.png" "${MOUNT##*/}" <<'APPLESCRIPT'
on run argv
    tell application "Finder"
        tell disk (item 2 of argv)
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {120, 100, 780, 522}
            set options to icon view options of container window
            set arrangement of options to not arranged
            set icon size of options to 128
            set text size of options to 13
            set label position of options to bottom
            set shows item info of options to false
            set background picture of options to (POSIX file (item 1 of argv))
            set position of item "UMC Launchpad.app" of container window to {180, 190}
            set position of item "Applications" of container window to {480, 190}
            close container window
        end tell
    end tell
end run
APPLESCRIPT
sleep 2
hdiutil detach "$MOUNT"
MOUNT=
trap - EXIT
hdiutil convert "$RWDMG" -format UDZO -ov -o "$DMG"
rm -f "$RWDMG"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 파일 이름을 버전 없이 고정해 releases/latest/download/UMC-Launchpad.dmg 가 늘 최신을 가리키게 한다
gh release create "v$VERSION" "$DMG" \
    --target "$(git rev-parse HEAD)" \
    --title "UMC Launchpad $VERSION" \
    --notes-file "$NOTES"

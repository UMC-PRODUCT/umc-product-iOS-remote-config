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

# Applications 바로가기를 같이 넣어 DMG 를 열면 끌어다 설치할 수 있게 한다
STAGE=.build/dmg
DMG=.build/UMC-Launchpad.dmg
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/UMC Launchpad.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "UMC Launchpad" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 파일 이름을 버전 없이 고정해 releases/latest/download/UMC-Launchpad.dmg 가 늘 최신을 가리키게 한다
gh release create "v$VERSION" "$DMG" \
    --target "$(git rev-parse HEAD)" \
    --title "UMC Launchpad $VERSION" \
    --notes-file "$NOTES"

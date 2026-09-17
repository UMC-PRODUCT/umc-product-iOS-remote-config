#!/bin/sh
# UMC Tree.app 을 DMG 로 묶어 GitHub 릴리즈로 올린다. 사용: ./release.sh 릴리즈노트.md
# 태그는 코드의 버전에서 만든다. 태그와 앱 버전이 어긋나면 업데이트 알림이 끝없이 뜬다
set -eu
cd "$(dirname "$0")"

NOTES=$(cd "$OLDPWD" && realpath "$1")
git diff --quiet HEAD || { echo "커밋하지 않은 변경이 있어요. 릴리즈할 코드를 커밋하고 push 한 뒤 다시 실행하세요"; exit 1; }

./build-app.sh
VERSION=$(sed -n 's/.*static let version = "\(.*\)"/\1/p' Sources/RemoteConfigEditor/RemoteConfigEditorApp.swift)

# Applications 바로가기를 같이 넣어 DMG 를 열면 끌어다 설치할 수 있게 한다
STAGE=.build/dmg
DMG=.build/UMC-Tree.dmg
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto ".build/UMC Tree.app" "$STAGE/UMC Tree.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "UMC Tree" -srcfolder "$STAGE" -format UDZO -ov "$DMG"

# 파일 이름을 버전 없이 고정해 releases/latest/download/UMC-Tree.dmg 가 늘 최신을 가리키게 한다
gh release create "v$VERSION" "$DMG" \
    --target "$(git rev-parse HEAD)" \
    --title "UMC Tree $VERSION" \
    --notes-file "$NOTES"

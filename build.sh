#!/bin/bash
# Builds "SNI Launcher.app" (universal) with SNI.app and SNFM.app inside it.
#   SNI comes from ../sni (current checkout), built universal like the fork's release workflow.
#   SNFM.app comes from out/SNFM.app, made by ./build-snfm.sh.
# Options:
#   --install   copy the result to the Desktop
#   --zip       write out/SNI-Launcher-<version>-macos-universal.zip for a release
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SNI_SRC="$(cd "$HERE/../sni" && pwd)"
OUT="$HERE/out"
WORK="$OUT/work"
LAUNCHER="$OUT/SNI Launcher.app"
SNFM_APP="$OUT/SNFM.app"
export BUNDLE_VERSION="$(cat "$HERE/VERSION")"
source "$HERE/bundle.sh"

[ -d "$SNFM_APP" ] || { echo "missing $SNFM_APP, run ./build-snfm.sh first"; exit 1; }
rm -rf "$WORK" "$LAUNCHER"
mkdir -p "$WORK"

# SNI.app
version=$(git -C "$SNI_SRC" describe --tags --always)
commit=$(git -C "$SNI_SRC" rev-parse --short HEAD)
ldflags="-w -X 'main.version=$version' -X 'main.commit=$commit' -X 'main.date=$(date -u +%Y-%m-%dT%H:%M:%S)' -X 'main.builtBy=$(go version | cut -f3 -d ' ')'"
for arch in amd64 arm64; do
    (cd "$SNI_SRC" && CGO_ENABLED=1 GOOS=darwin GOARCH=$arch go build -gcflags=all=-l -ldflags="$ldflags" -o "$WORK/sni.$arch" ./cmd/sni)
done
SNI_APP="$WORK/SNI.app"
mkdir -p "$SNI_APP/Contents/MacOS" "$SNI_APP/Contents/Resources"
lipo -create -output "$SNI_APP/Contents/MacOS/sni" "$WORK/sni.amd64" "$WORK/sni.arm64"
make_icns "$SNI_SRC/cmd/sni/icon/sni-logo-square.png" "$SNI_APP/Contents/Resources/SNI.icns"
write_plist "$SNI_APP/Contents/Info.plist" SNI com.cvw-hmb.sni sni SNI "	<key>LSUIElement</key><true/>"
cp "$SNI_SRC/LICENSE" "$SNI_APP/Contents/Resources/LICENSE"
codesign --force -s - "$SNI_APP"

# Launcher
mkdir -p "$LAUNCHER/Contents/MacOS" "$LAUNCHER/Contents/Resources"
for arch in arm64 x86_64; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos15" "$HERE/main.swift" -o "$WORK/sni-launcher.$arch"
done
lipo -create -output "$LAUNCHER/Contents/MacOS/sni-launcher" "$WORK/sni-launcher.arm64" "$WORK/sni-launcher.x86_64"
make_icns "$SNI_SRC/cmd/sni/icon/sni-logo-square.png" "$LAUNCHER/Contents/Resources/Launcher.icns"
write_plist "$LAUNCHER/Contents/Info.plist" "SNI Launcher" com.cvw-hmb.sni-launcher sni-launcher Launcher ""
cp "$HERE/LICENSE" "$LAUNCHER/Contents/Resources/LICENSE"
cp -R "$SNI_APP" "$LAUNCHER/Contents/Resources/SNI.app"
cp -R "$SNFM_APP" "$LAUNCHER/Contents/Resources/SNFM.app"
codesign --force --deep -s - "$LAUNCHER"
codesign --verify --deep "$LAUNCHER"
rm -rf "$WORK"
echo "built $LAUNCHER $BUNDLE_VERSION (sni $version $commit)"

for arg in "$@"; do
    case "$arg" in
    --install)
        rm -rf "$HOME/Desktop/SNI Launcher.app"
        cp -R "$LAUNCHER" "$HOME/Desktop/SNI Launcher.app"
        echo "installed $HOME/Desktop/SNI Launcher.app"
        ;;
    --zip)
        zip="$OUT/SNI-Launcher-v$BUNDLE_VERSION-macos-universal.zip"
        rm -f "$zip"
        ditto -c -k --keepParent "$LAUNCHER" "$zip"
        echo "packaged $zip"
        ;;
    esac
done

#!/bin/bash
# Builds the Windows launcher and packages it with SNI and SNFM as a zip.
#   SNI and SNFM come from the CVW-HMB/sni release sni-v0.0.104-fxpak1.
#   SNFM_EXE=path/to/manage_files.exe replaces the release's manage_files.exe.
# Needs go and go-winres (go install github.com/tc-hib/go-winres@latest) and the gh CLI.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SNI_SRC="$(cd "$HERE/../sni" && pwd)"
OUT="$HERE/out"
VERSION="$(cat "$HERE/VERSION")"
NAME="SNI-Launcher-v$VERSION-windows-x64"
WORK="$OUT/work-windows"
FOLDER="$WORK/$NAME"
RELEASE_TAG="v0.0.104-fxpak1"
RELEASE_ASSET="sni-v0.0.104-fxpak1-windows-amd64.zip"
export PATH="$PATH:$HOME/go/bin"

rm -rf "$WORK"
mkdir -p "$WORK" "$FOLDER"

gh release download "$RELEASE_TAG" --repo CVW-HMB/sni --pattern "$RELEASE_ASSET" --dir "$WORK"
unzip -q "$WORK/$RELEASE_ASSET" -d "$FOLDER"
# Some archives wrap everything in one folder
if [ ! -f "$FOLDER/sni.exe" ]; then
    inner=$(dirname "$(find "$FOLDER" -name sni.exe | head -n 1)")
    mv "$inner"/* "$FOLDER"/ 2>/dev/null || true
fi

cd "$HERE/windows"
rm -f rsrc_windows_amd64.syso
go-winres simply --arch amd64 --manifest gui --icon "$SNI_SRC/cmd/sni/icon/sni-logo-square-256.png" \
    --product-name "SNI Launcher" --file-description "SNI Launcher"
GOOS=windows GOARCH=amd64 go build -ldflags "-H=windowsgui" -o "$FOLDER/SNI Launcher.exe" .
rm -f rsrc_windows_amd64.syso
cd "$HERE"

if [ -n "${SNFM_EXE:-}" ]; then
    cp "$SNFM_EXE" "$FOLDER/manage_files.exe"
    echo "manage_files.exe from SNFM_EXE: $SNFM_EXE"
else
    echo "manage_files.exe from release $RELEASE_TAG"
fi
cp "$HERE/LICENSE" "$FOLDER/LICENSE-launcher.txt"

zip="$OUT/$NAME.zip"
rm -f "$zip"
ditto -c -k --keepParent "$FOLDER" "$zip"
rm -rf "$WORK"
echo "packaged $zip"

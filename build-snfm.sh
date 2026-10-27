#!/bin/bash
# Builds a universal (arm64 + x86_64) SNFM.app from ../snfm with vcpkg static dependencies,
# using the repo's own macOS presets and triplets. The first run builds gRPC, protobuf and
# wxWidgets from source for both architectures, which takes a while.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SNFM_SRC="$(cd "$HERE/../snfm" && pwd)"
export VCPKG_ROOT="$(cd "$HERE/../vcpkg" && pwd)"
OUT="$HERE/out"
APP="$OUT/SNFM.app"

for target in macos-arm64-release:arm64 macos-x64-release:x86_64; do
    preset="${target%%:*}"
    (cd "$SNFM_SRC" &&
        cmake --preset "$preset" -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
            -DCMAKE_OSX_ARCHITECTURES="${target##*:}" \
            -DCMAKE_PROJECT_INCLUDE="$HERE/cmake/no-libprotoc.cmake" &&
        cmake --build "out/build/$preset" --target manage_files)
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/manage_files" \
    "$SNFM_SRC/out/build/macos-arm64-release/manage_files" \
    "$SNFM_SRC/out/build/macos-x64-release/manage_files"

source "$HERE/bundle.sh"
make_icns "$SNFM_SRC/icons/manage_files.png" "$APP/Contents/Resources/SNFM.icns"
write_plist "$APP/Contents/Info.plist" SNFM com.cvw-hmb.snfm manage_files SNFM ""
cp "$SNFM_SRC/LICENSE.txt" "$APP/Contents/Resources/LICENSE.txt"
codesign --force -s - "$APP"
echo "built $APP ($(lipo -archs "$APP/Contents/MacOS/manage_files"), snfm $(git -C "$SNFM_SRC" rev-parse --short HEAD))"

# Helpers for assembling .app bundles; sourced by the build scripts.

make_icns() { # src.png dest.icns
    local tmp set side
    tmp="$(mktemp -d)"
    set="$tmp/icon.iconset"
    mkdir -p "$set"
    side=$(sips -g pixelWidth -g pixelHeight "$1" | awk '/pixel/ {print $2}' | sort -n | tail -1)
    sips -s format png --padToHeightWidth "$side" "$side" "$1" --out "$tmp/square.png" >/dev/null
    for sz in 16 32 128 256 512; do
        sips -z $sz $sz "$tmp/square.png" --out "$set/icon_${sz}x${sz}.png" >/dev/null
        sips -z $((sz * 2)) $((sz * 2)) "$tmp/square.png" --out "$set/icon_${sz}x${sz}@2x.png" >/dev/null
    done
    iconutil -c icns "$set" -o "$2"
    rm -rf "$tmp"
}

write_plist() { # dest name id executable icon extra-xml
    cat > "$1" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>$2</string>
	<key>CFBundleIdentifier</key><string>$3</string>
	<key>CFBundleExecutable</key><string>$4</string>
	<key>CFBundleIconFile</key><string>$5</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>${BUNDLE_VERSION:-1.0.0}</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
	<key>NSHighResolutionCapable</key><true/>
$6
</dict>
</plist>
EOF
}

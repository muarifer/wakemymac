#!/bin/zsh
# Builds WakeMyMac.app (menu bar app + embedded root daemon).
#   ./build.sh              native build
#   ./build.sh --universal  arm64 + x86_64 fat binary (requires Xcode)
#   ./build.sh --release    universal build + notarized zip for GitHub release
set -e
cd "$(dirname "$0")"

VERSION="${VERSION:-0.1.0}"
MODE="${1:-}"

BUNDLE_ID="com.muarifer.wakemymac"
DAEMON_LABEL="com.muarifer.wakemymac.daemon"

if [[ "$MODE" == "--universal" || "$MODE" == "--release" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN_DIR=".build/apple/Products/Release"
else
    swift build -c release
    BIN_DIR=".build/release"
fi

APP="WakeMyMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchDaemons"

cp "$BIN_DIR/WakeMyMac" "$APP/Contents/MacOS/WakeMyMac"
cp "$BIN_DIR/wakemymacd" "$APP/Contents/MacOS/wakemymacd"

# App icon (Dock, Finder, About panel) and the menu bar template image.
# Regenerate from Assets/WakeMyMacLogo.png with Assets/make-icons.swift.
cp Assets/AppIcon.icns "$APP/Contents/Resources/"
cp Assets/MenuBarIcon.png Assets/MenuBarIcon@2x.png "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>WakeMyMac</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>WakeMyMac</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 Murat Çeliker</string>
</dict>
</plist>
PLIST

# SMAppService.daemon(plistName:) bu dizine bakar; BundleProgram bundle köküne
# görelidir. launchd root olarak çalıştırır (wake/poweron root ister), KeepAlive
# ile re-arm döngüsü hep ayakta kalır.
cat > "$APP/Contents/Library/LaunchDaemons/${DAEMON_LABEL}.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>${DAEMON_LABEL}</string>
    <key>BundleProgram</key><string>Contents/MacOS/wakemymacd</string>
    <key>MachServices</key><dict>
        <key>${DAEMON_LABEL}</key><true/>
    </dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>AssociatedBundleIdentifiers</key><string>${BUNDLE_ID}</string>
</dict>
</plist>
PLIST

# Varsa Developer ID ile (notarization için hardened runtime + timestamp),
# yoksa ad-hoc imzala. Daemon binary'si önce, sonra bundle'ın tamamı.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')}"
if [[ -n "$IDENTITY" ]]; then
    echo "Signing with: $IDENTITY"
    codesign --force --options runtime --timestamp --identifier "$DAEMON_LABEL" --sign "$IDENTITY" "$APP/Contents/MacOS/wakemymacd"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
    echo "No Developer ID certificate found; ad-hoc signing."
    codesign --force --identifier "$DAEMON_LABEL" --sign - "$APP/Contents/MacOS/wakemymacd"
    codesign --force --sign - "$APP"
fi

if [[ "$MODE" == "--release" ]]; then
    ZIP="WakeMyMac-${VERSION}.zip"
    rm -f "$ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

    # Notarize et ve bileti zımbala. Ön koşullar eksikse release ÜRETME —
    # bilerek imzasız release isteniyorsa ALLOW_UNSIGNED_RELEASE=1 verilmeli.
    PROFILE="${NOTARY_PROFILE:-wakemymac-notary}"
    if [[ -n "$IDENTITY" ]] && xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
        echo "Notarizing (this can take a few minutes)..."
        SUBMIT_LOG=$(xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait)
        echo "$SUBMIT_LOG"
        if ! grep -q "status: Accepted" <<< "$SUBMIT_LOG"; then
            echo "ERROR: notarization was not accepted." >&2
            exit 1
        fi
        xcrun stapler staple "$APP"
        rm -f "$ZIP"
        ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
    elif [[ "${ALLOW_UNSIGNED_RELEASE:-0}" == "1" ]]; then
        echo "WARNING: producing UNSIGNED release (ALLOW_UNSIGNED_RELEASE=1)."
    else
        echo "ERROR: cannot notarize (missing Developer ID identity or '$PROFILE' keychain profile)." >&2
        echo "Set ALLOW_UNSIGNED_RELEASE=1 to build an unsigned release anyway." >&2
        exit 1
    fi

    echo "Release artifact: $PWD/$ZIP"
    shasum -a 256 "$ZIP"
else
    echo "Ready: $PWD/$APP  (run with: open $APP)"
fi

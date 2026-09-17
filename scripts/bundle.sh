#!/usr/bin/env bash
# Assembles a double-clickable OpenOSK.app from the release build.
# The app bundle is required for macOS to remember the Accessibility
# permission across launches (a bare binary is re-prompted after rebuilds).
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(grep -m1 'let appVersion' Sources/OpenOSK/main.swift | sed 's/.*"\(.*\)"/\1/')"
APP="build/OpenOSK.app"

# Same variable as the Makefile: build products may live off the checkout.
SCRATCH="${SCRATCH_PATH:-.build}"
swift build -c release --scratch-path "$SCRATCH"
BIN="$(swift build -c release --scratch-path "$SCRATCH" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/openosk" "$APP/Contents/MacOS/OpenOSK"
cp -R "$BIN/OpenOSK_OpenOSKCore.bundle" "$APP/Contents/Resources/"
if [ -d "$BIN/OpenOSK_OpenOSK.bundle" ]; then
	cp -R "$BIN/OpenOSK_OpenOSK.bundle" "$APP/Contents/Resources/"
fi
if [ -f Assets/OpenOSK.icns ]; then
	cp Assets/OpenOSK.icns "$APP/Contents/Resources/"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>OpenOSK</string>
	<key>CFBundleDisplayName</key>
	<string>OpenOSK</string>
	<key>CFBundleIdentifier</key>
	<string>com.secondtruth.OpenOSK</string>
	<key>CFBundleVersion</key>
	<string>${VERSION}</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleExecutable</key>
	<string>OpenOSK</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleIconFile</key>
	<string>OpenOSK</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleLocalizations</key>
	<array>
		<string>en</string>
		<string>de</string>
	</array>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>© 2026 Christian Neff. MIT License.</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --sign - "$APP" 2>/dev/null \
	|| echo "warning: ad-hoc codesign failed; the app will still run locally"

echo "Created $APP"
echo "Install with: cp -R $APP /Applications/"

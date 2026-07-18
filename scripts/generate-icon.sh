#!/usr/bin/env bash
# Regenerates Assets/OpenOSK.icns from scripts/generate-icon.swift.
set -euo pipefail

cd "$(dirname "$0")/.."

ICONSET="build/OpenOSK.iconset"
mkdir -p Assets build
swift scripts/generate-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o Assets/OpenOSK.icns
echo "Created Assets/OpenOSK.icns"

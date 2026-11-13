#!/bin/zsh
# Builds Summon.app into ./build. Pass `install` to copy it to /Applications and launch it.
# Set SIGN_IDENTITY to sign with a real certificate instead of ad-hoc.
set -euo pipefail
cd "${0:A:h}"

swift build -c release

app=build/Summon.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Summon" "$app/Contents/MacOS/Summon"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  # Distribution build: hardened runtime and a secure timestamp are required for notarization.
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app"
else
  codesign --force --sign - "$app"
fi
echo "Built $app"

if [[ "${1:-}" == "install" ]]; then
  pkill -x Summon || true
  rm -rf /Applications/Summon.app
  cp -R "$app" /Applications/Summon.app
  open /Applications/Summon.app
  echo "Installed /Applications/Summon.app"
fi

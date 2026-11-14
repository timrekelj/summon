#!/bin/zsh
# Builds, signs, notarizes and publishes a Summon release, then updates the Homebrew tap.
#
#   ./release.sh 1.0.0
#
# One-time setup:
#   - A "Developer ID Application" certificate in the keychain.
#   - Notary credentials: xcrun notarytool store-credentials summon-notary --apple-id <email> --team-id <team>
set -euo pipefail
cd "${0:A:h}"

version=${1:?usage: ./release.sh <version>}
tag="v$version"
identity=${SIGN_IDENTITY:-Developer ID Application}
notary_profile=${NOTARY_PROFILE:-summon-notary}
tap_repo=timrekelj/homebrew-tap
plist=Resources/Info.plist
app=build/Summon.app
zip=build/Summon.zip

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean; commit or stash first." >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Tag $tag already exists." >&2
  exit 1
fi

build=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist") + 1 ))
plutil -replace CFBundleShortVersionString -string "$version" "$plist"
plutil -replace CFBundleVersion -string "$build" "$plist"

SIGN_IDENTITY="$identity" ./build.sh

rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$app"
spctl --assess --type execute --verbose "$app"

# Re-zip so the published archive contains the stapled ticket.
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
sha=$(shasum -a 256 "$zip" | cut -d' ' -f1)

git commit -m "chore: release $tag" -- "$plist"
git tag "$tag"
git push origin HEAD "$tag"
gh release create "$tag" "$zip" --title "Summon $version" --generate-notes

tap=$(mktemp -d)
gh repo clone "$tap_repo" "$tap" -- --quiet
sed -i '' -E \
  -e "s/^  version \".*\"/  version \"$version\"/" \
  -e "s/^  sha256 \".*\"/  sha256 \"$sha\"/" \
  "$tap/Casks/summon.rb"
git -C "$tap" commit -am "summon $version"
git -C "$tap" push
rm -rf "$tap"

echo "Released Summon $version ($sha)"

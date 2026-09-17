#!/bin/zsh
# Full release: universal build, Developer ID signing, notarization,
# GitHub release, and Homebrew cask update.
#   ./release.sh 1.0.0
set -e
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>}"
TAP_DIR="${TAP_DIR:-$HOME/htdocs/homebrew-tap}"
CASK="$TAP_DIR/Casks/wakemymac.rb"

# ZIP ile tag aynı kaynağı temsil etsin: çalışma ağacı temiz olmalı
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: working tree is dirty; commit or stash before releasing." >&2
    exit 1
fi

# Tag varsa HEAD'i göstermeli (yarım kalmış release'in tekrarına izin ver)
if git rev-parse -q --verify "refs/tags/v${VERSION}" >/dev/null; then
    if [[ "$(git rev-parse "v${VERSION}^{commit}")" != "$(git rev-parse HEAD)" ]]; then
        echo "ERROR: tag v${VERSION} already exists and does not point to HEAD." >&2
        exit 1
    fi
else
    git tag "v${VERSION}"
fi

VERSION="$VERSION" ./build.sh --release

ZIP="WakeMyMac-${VERSION}.zip"
SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')

git push origin "v${VERSION}"
gh release create "v${VERSION}" "$ZIP" --title "WakeMyMac ${VERSION}" --generate-notes

sed -i '' \
    -e "s/^  version .*/  version \"${VERSION}\"/" \
    -e "s/^  sha256 .*/  sha256 \"${SHA}\"/" \
    "$CASK"
# Yalnızca cask dosyasını ekle ve commit'le — tap reposundaki ilgisiz
# değişikliklere dokunma. `add` ilk release için gerekli: o ana kadar cask
# tap'te takipsiz durur ve pathspec'li commit onu bulamaz.
git -C "$TAP_DIR" add Casks/wakemymac.rb
git -C "$TAP_DIR" commit -m "wakemymac ${VERSION}" -- Casks/wakemymac.rb
git -C "$TAP_DIR" push

echo "Released v${VERSION} and updated the Homebrew cask."

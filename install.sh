#!/bin/sh
# Installs the latest BgSounds release into /Applications (or ~/Applications if that isn't writable).
# Usage: curl -fsSL https://raw.githubusercontent.com/Waleed-Almutairi/BgSounds/main/install.sh | sh
set -eu
[ "$(uname)" = Darwin ] || { echo "BgSounds only runs on macOS." >&2; exit 1; }
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] || { echo "BgSounds needs macOS 13 or later." >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "Downloading BgSounds..."
curl -fsSL "https://github.com/Waleed-Almutairi/BgSounds/releases/latest/download/BgSounds.zip" -o "$tmp/BgSounds.zip"
ditto -x -k "$tmp/BgSounds.zip" "$tmp"
[ -d "$tmp/BgSounds.app" ] || { echo "The download did not contain BgSounds.app." >&2; exit 1; }

dest=/Applications
[ -w "$dest" ] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
pkill -x BgSounds 2>/dev/null || true
rm -rf "$dest/BgSounds.app"
mv "$tmp/BgSounds.app" "$dest/"
open "$dest/BgSounds.app"
echo "Installed to $dest/BgSounds.app. Look for the three-notes icon in your menu bar."

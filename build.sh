#!/bin/zsh
# Builds build/BgSounds.app (Apple silicon + Intel) and build/BgSounds.zip. Needs Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"
app=build/BgSounds.app
rm -rf build && mkdir -p $app/Contents/MacOS $app/Contents/Resources
for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -target $arch-apple-macos13 Sources/main.swift -o build/BgSounds-$arch
done
lipo -create build/BgSounds-arm64 build/BgSounds-x86_64 -output $app/Contents/MacOS/BgSounds
rm build/BgSounds-arm64 build/BgSounds-x86_64
cp Resources/Info.plist $app/Contents/
cp Resources/AppIcon.icns $app/Contents/Resources/
codesign --force -s - $app   # ad-hoc signature: enough to run, not notarized
ditto -c -k --keepParent $app build/BgSounds.zip
echo "Built $app and build/BgSounds.zip"

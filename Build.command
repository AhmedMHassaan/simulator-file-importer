#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
if ! command -v xcodebuildmcp >/dev/null; then
  print 'To rebuild, install XcodeBuildMCP, or open SimulatorPhotos.xcodeproj in Xcode and build the SimulatorPhotos scheme.'
  exit 1
fi
xcodebuildmcp macos build \
  --project-path "$PWD/SimulatorPhotos.xcodeproj" \
  --scheme SimulatorPhotos --configuration Release \
  --derived-data-path "$PWD/build" \
  --extra-args 'ARCHS=arm64 x86_64' 'ONLY_ACTIVE_ARCH=NO'
mkdir -p dist
ditto 'build/Build/Products/Release/Simulator File Importer.app' 'dist/Simulator File Importer.app'
codesign --verify --deep --strict 'dist/Simulator File Importer.app'
ditto README.md dist/README.md
ditto USER_GUIDE.md dist/USER_GUIDE.md
ditto docs dist/docs
package_dir="$PWD/build/portable/Simulator File Importer"
mkdir -p "$package_dir"
ditto 'dist/Simulator File Importer.app' "$package_dir/Simulator File Importer.app"
ditto README.md "$package_dir/README.md"
ditto USER_GUIDE.md "$package_dir/USER_GUIDE.md"
ditto docs "$package_dir/docs"
ditto -c -k --sequesterRsrc --keepParent "$package_dir" 'dist/Simulator File Importer.zip'
print "Ready: $PWD/dist/Simulator File Importer.app"

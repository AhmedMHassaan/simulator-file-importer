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
ditto 'build/Build/Products/Release/Simulator photos importer.app' 'dist/Simulator photos importer.app'
codesign --verify --deep --strict 'dist/Simulator photos importer.app'
ditto README.md dist/README.md
ditto USER_GUIDE.md dist/USER_GUIDE.md
ditto docs/images dist/docs/images
package_dir="$PWD/build/portable/Simulator photos importer"
mkdir -p "$package_dir"
ditto 'dist/Simulator photos importer.app' "$package_dir/Simulator photos importer.app"
ditto README.md "$package_dir/README.md"
ditto USER_GUIDE.md "$package_dir/USER_GUIDE.md"
ditto docs/images "$package_dir/docs/images"
ditto -c -k --sequesterRsrc --keepParent "$package_dir" 'dist/Simulator photos importer.zip'
print "Ready: $PWD/dist/Simulator photos importer.app"

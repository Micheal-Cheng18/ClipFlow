#!/bin/zsh
set -eu
cd "${0:A:h}/.."
# Keep caches project-local; no global SwiftPM or machine-specific paths.
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build -c release --cache-path "$PWD/.build/cache"
bin_dir=$(swift build -c release --show-bin-path)
app_dir="$PWD/dist/ClipFlow.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$bin_dir/ClipFlow" "$app_dir/Contents/MacOS/ClipFlow"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
codesign --force --sign "${CLIPFLOW_SIGN_IDENTITY:--}" "$app_dir"
codesign --verify --deep --strict "$app_dir"
print "Built: $app_dir"

#!/bin/zsh
# Build a universal macOS release without requiring a signing certificate.
# The default ad hoc signature is for integrity only; this script does not
# notarize the app. Set CLIPFLOW_SIGN_IDENTITY to use a local signing identity.
set -euo pipefail
cd "${0:A:h}/.."

if [[ "$(uname -s)" != Darwin ]]; then
  print -u2 "Release packaging requires macOS with Xcode command line tools."
  exit 1
fi

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
if [[ -z "$version" || "$version" == *[^0-9.]* ]]; then
  print -u2 "Invalid release version in Resources/Info.plist: $version"
  exit 1
fi

# Keep compiler and SwiftPM caches inside the project.
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
typeset -a binaries
for arch in arm64 x86_64; do
  typeset -a build_args
  build_args=(
    -c release
    --triple "$arch-apple-macosx14.0"
    --scratch-path "$PWD/.build/release-$arch"
    --cache-path "$PWD/.build/cache"
  )
  swift build "${build_args[@]}"
  bin_dir=$(swift build "${build_args[@]}" --show-bin-path)
  binaries+=("$bin_dir/ClipFlow")
done

app_dir="$PWD/dist/ClipFlow.app"
archive_name="ClipFlow-$version-macOS-universal.zip"
mkdir -p "$PWD/dist"
# Replace only the generated bundle after both architecture builds succeed.
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
lipo -create "${binaries[@]}" -output "$app_dir/Contents/MacOS/ClipFlow"
chmod +x "$app_dir/Contents/MacOS/ClipFlow"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
codesign --force --sign "${CLIPFLOW_SIGN_IDENTITY:--}" "$app_dir"
codesign --verify --deep --strict "$app_dir"
lipo -verify_arch arm64 x86_64 "$app_dir/Contents/MacOS/ClipFlow"
print "Architectures: $(lipo -archs "$app_dir/Contents/MacOS/ClipFlow")"

rm -f "$PWD/dist/$archive_name"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$PWD/dist/$archive_name"
(
  cd dist
  shasum -a 256 "$archive_name" > "$archive_name.sha256"
  shasum -a 256 -c "$archive_name.sha256"
)
print "Packaged: $PWD/dist/$archive_name"
print "Checksum: $PWD/dist/$archive_name.sha256"

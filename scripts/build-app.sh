#!/bin/zsh

set -euo pipefail

configuration="${1:-debug}"
root_dir="${0:A:h:h}"
build_dir="$root_dir/.build/$configuration"
app_dir="$root_dir/dist/Liminal Lacuna.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
bundle_identifier="dev.liminallacuna.menubarexpander"

cd "$root_dir"
mkdir -p /tmp/liminal-swift-cache /tmp/liminal-swift-config /tmp/liminal-swift-security /tmp/liminal-clang-cache
CLANG_MODULE_CACHE_PATH=/tmp/liminal-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/liminal-clang-cache \
swift build \
    --disable-sandbox \
    --configuration "$configuration" \
    --cache-path /tmp/liminal-swift-cache \
    --config-path /tmp/liminal-swift-config \
    --security-path /tmp/liminal-swift-security \
    --scratch-path .build

rm -rf "$app_dir"
mkdir -p "$macos_dir"
cp "$build_dir/LiminalLacuna" "$macos_dir/LiminalLacuna"
cp "$root_dir/Support/Info.plist" "$contents_dir/Info.plist"

xattr -cr "$app_dir"
# Keep the designated requirement stable across local development builds.
# Without this, ad-hoc signing falls back to a changing cdhash and macOS TCC
# treats every rebuild as a different Accessibility client.
codesign \
    --force \
    --sign - \
    --requirements "=designated => identifier \"$bundle_identifier\"" \
    "$app_dir"
xattr -cr "$app_dir"
echo "$app_dir"

#!/usr/bin/env zsh
set -euo pipefail
config=${1:-debug}
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
app_name=Mote
bundle_dir="$repo_dir/.build/$config/$app_name.app"
contents_dir="$bundle_dir/Contents"
macos_dir="$contents_dir/MacOS"
mkdir -p "$macos_dir"
cp "$repo_dir/.build/$config/$app_name" "$macos_dir/$app_name"
cp "$repo_dir/Sources/Mote/Info.plist" "$contents_dir/Info.plist"

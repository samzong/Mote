#!/usr/bin/env zsh
set -euo pipefail
config=${1:-debug}
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_dir"
swift build -c "$config"
"$repo_dir/.build/$config/Mote"

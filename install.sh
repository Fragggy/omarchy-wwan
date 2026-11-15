#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/munzlind.wwan"
mkdir -p "$target"
rsync -a --delete --exclude '.git' --exclude 'node_modules' "$source_dir/" "$target/"
omarchy plugin validate "$target"
printf 'Installed %s\n' "$target"

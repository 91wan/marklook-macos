#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: Scripts/validate-signed-quicklook.sh /path/to/MarkLook.app" >&2
  exit 64
fi

app="$1"
if [ ! -d "$app" ]; then
  echo "error: app bundle not found: $app" >&2
  exit 66
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
samples_dir="$repo_root/Samples"
app="$(cd "$(dirname "$app")" && pwd -P)/$(basename "$app")"

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

test -f "$samples_dir/basic.md"
test -f "$samples_dir/gfm-table-task-list.md"
test -f "$samples_dir/unsafe-html.md"

run codesign --verify --deep --strict --verbose=4 "$app"
run spctl --assess --type execute --verbose=4 "$app"
run open "$app"
run qlmanage -r
run qlmanage -r cache
run killall Finder || true

pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
pluginkit -mAv -p com.apple.quicklook.thumbnail | grep -i MarkLook

run mdls -name kMDItemContentType "$samples_dir/basic.md"
run qlmanage -p "$samples_dir/basic.md"
run qlmanage -p "$samples_dir/gfm-table-task-list.md"
run qlmanage -p "$samples_dir/unsafe-html.md"
run qlmanage -t -s 512 -o /tmp "$samples_dir/basic.md"

echo "thumbnail output should be at /tmp/basic.md.png when MarkLookThumbnail is selected"

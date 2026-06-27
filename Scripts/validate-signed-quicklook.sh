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

capture() {
  output_file="$1"
  shift
  printf '+'
  printf ' %q' "$@"
  printf ' | tee %q\n' "$output_file"
  "$@" | tee "$output_file"
}

preview_plugins="$(mktemp)"
thumbnail_plugins="$(mktemp)"
trap 'rm -f "$preview_plugins" "$thumbnail_plugins"' EXIT

test -f "$samples_dir/basic.md"
test -f "$samples_dir/gfm-table-task-list.md"
test -f "$samples_dir/long-ai-review.md"
test -f "$samples_dir/unsafe-html.md"
test -f "$samples_dir/large-fast-mode.md"

run "$repo_root/Scripts/validate-built-bundle.sh" "$app"
run codesign --verify --deep --strict --verbose=4 "$app"
run spctl --assess --type execute --verbose=4 "$app"
run open "$app"
sleep 2
run qlmanage -r
run qlmanage -r cache
run killall Finder || true

capture "$preview_plugins" pluginkit -mAv -p com.apple.quicklook.preview
capture "$thumbnail_plugins" pluginkit -mAv -p com.apple.quicklook.thumbnail

grep -E 'MarkLookPreview|com\.91wan\.MarkLook\.Preview' "$preview_plugins"
grep -E 'MarkLookThumbnail|com\.91wan\.MarkLook\.Thumbnail' "$thumbnail_plugins"

run mdls -name kMDItemContentType "$samples_dir/basic.md"
run qlmanage -p "$samples_dir/basic.md"
run qlmanage -p "$samples_dir/gfm-table-task-list.md"
run qlmanage -p "$samples_dir/long-ai-review.md"
run qlmanage -p "$samples_dir/unsafe-html.md"
run qlmanage -p "$samples_dir/large-fast-mode.md"
run qlmanage -t -s 512 -o /tmp "$samples_dir/basic.md"

echo "thumbnail output should be at /tmp/basic.md.png when MarkLookThumbnail is selected"

#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: Scripts/validate-signed-quicklook.sh [--development|--release] /path/to/MarkLook.app" >&2
}

mode="release"
if [ "$#" -eq 2 ]; then
  case "$1" in
    --development)
      mode="development"
      shift
      ;;
    --release)
      mode="release"
      shift
      ;;
    *)
      usage
      exit 64
      ;;
  esac
elif [ "$#" -ne 1 ]; then
  usage
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

capture_all() {
  output_file="$1"
  shift
  printf '+'
  printf ' %q' "$@"
  printf ' 2>&1 | tee %q\n' "$output_file"
  "$@" 2>&1 | tee "$output_file"
}

preview_plugins="$(mktemp)"
thumbnail_plugins="$(mktemp)"
signature_details="$(mktemp)"
trap 'rm -f "$preview_plugins" "$thumbnail_plugins" "$signature_details"' EXIT

if [ "$mode" = "development" ]; then
  echo "WARNING: --development mode does not prove public distribution trust."
  echo "Developer ID + notarization + stapling remain required for release."
fi

test -f "$samples_dir/basic.md"
test -f "$samples_dir/gfm-table-task-list.md"
test -f "$samples_dir/long-ai-review.md"
test -f "$samples_dir/unsafe-html.md"
test -f "$samples_dir/large-fast-mode.md"

run "$repo_root/Scripts/validate-built-bundle.sh" "$app"
run codesign --verify --deep --strict --verbose=4 "$app"
capture_all "$signature_details" codesign -dv --verbose=4 "$app"

if grep -q 'Signature=adhoc' "$signature_details"; then
  echo "error: app is ad-hoc signed; use Apple Development or Developer ID signing" >&2
  exit 65
fi

if ! grep -Eq '^TeamIdentifier=[^[:space:]]+' "$signature_details" || grep -q '^TeamIdentifier=not set$' "$signature_details"; then
  echo "error: TeamIdentifier is missing; use a non-ad-hoc Apple signing identity" >&2
  exit 65
fi

if [ "$mode" = "release" ]; then
  run spctl --assess --type execute --verbose=4 "$app"
else
  if run spctl --assess --type execute --verbose=4 "$app"; then
    echo "development spctl assessment: accepted"
  else
    echo "WARNING: development spctl assessment failed; continuing because signature is non-ad-hoc and TeamIdentifier is set."
    echo "WARNING: this does not prove public release trust."
  fi
fi
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

#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: Scripts/diagnose-thumbnail-selection.sh /path/to/MarkLook.app [path/to/sample.md]" >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 64
fi

app="$1"
sample_arg="${2:-}"

if [ ! -d "$app" ]; then
  echo "error: app bundle not found: $app" >&2
  exit 66
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
if [ -z "$sample_arg" ]; then
  sample="$repo_root/Samples/basic.md"
else
  sample="$sample_arg"
fi

if [ ! -f "$sample" ]; then
  echo "error: sample file not found: $sample" >&2
  exit 66
fi

app="$(cd "$(dirname "$app")" && pwd -P)/$(basename "$app")"
sample="$(cd "$(dirname "$sample")" && pwd -P)/$(basename "$sample")"
thumbnail_appex="$app/Contents/PlugIns/MarkLookThumbnail.appex"
thumbnail_binary="$thumbnail_appex/Contents/MacOS/MarkLookThumbnail"
output_dir="/tmp/marklook-thumbnail-diagnostics-$(date +%Y%m%d-%H%M%S)"
sample_png="$output_dir/$(basename "$sample").png"
unique_sample="/tmp/marklook-thumbnail-$(date +%s)-$(basename "$sample")"
unique_png="$output_dir/$(basename "$unique_sample").png"

mkdir -p "$output_dir"

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
  set +e
  "$@" | tee "$output_file"
  command_status="${PIPESTATUS[0]}"
  set -e
  if [ "$command_status" -ne 0 ]; then
    echo "warning: command exited $command_status; continuing diagnostics"
  fi
}

capture_all() {
  output_file="$1"
  shift
  printf '+'
  printf ' %q' "$@"
  printf ' 2>&1 | tee %q\n' "$output_file"
  set +e
  "$@" 2>&1 | tee "$output_file"
  command_status="${PIPESTATUS[0]}"
  set -e
  if [ "$command_status" -ne 0 ]; then
    echo "warning: command exited $command_status; continuing diagnostics"
  fi
}

capture_shell() {
  output_file="$1"
  shift
  printf '+ %s | tee %q\n' "$*" "$output_file"
  set +e
  bash -lc "$*" | tee "$output_file"
  command_status="${PIPESTATUS[0]}"
  set -e
  if [ "$command_status" -ne 0 ]; then
    echo "warning: command exited $command_status; continuing diagnostics"
  fi
}

echo "Writing thumbnail diagnostics to: $output_dir"
echo "App: $app"
echo "Sample: $sample"
echo "Unique sample: $unique_sample"

run "$repo_root/Scripts/validate-built-bundle.sh" "$app"

capture_all "$output_dir/app-codesign-dv.txt" codesign -dv --verbose=4 "$app"
capture_all "$output_dir/app-codesign-verify.txt" codesign --verify --deep --strict --verbose=4 "$app"

capture_all "$output_dir/thumbnail-codesign-dv.txt" codesign -dv --verbose=4 "$thumbnail_appex"
capture_all "$output_dir/thumbnail-codesign-verify.txt" codesign --verify --deep --strict --verbose=4 "$thumbnail_appex"
capture_shell "$output_dir/thumbnail-entitlements.txt" "codesign -d --entitlements - '$thumbnail_appex' || true"

capture "$output_dir/thumbnail-binary-file.txt" file "$thumbnail_binary"
capture "$output_dir/thumbnail-info-plist.txt" plutil -p "$thumbnail_appex/Contents/Info.plist"

capture "$output_dir/pluginkit-thumbnail-family.txt" pluginkit -mAv -p com.apple.quicklook.thumbnail
capture "$output_dir/pluginkit-thumbnail-exact.txt" pluginkit -mAv -i com.91wan.MarkLook.Thumbnail
capture "$output_dir/pluginkit-thumbnail-exact-all.txt" pluginkit -mADv -i com.91wan.MarkLook.Thumbnail
capture_shell "$output_dir/pluginkit-all-marklook.txt" "pluginkit -mADv | grep -i MarkLook || true"

if grep -i 'MarkLook' "$output_dir/pluginkit-all-marklook.txt" | grep -Fv "$app/Contents/PlugIns" >/dev/null; then
  echo
  echo "WARNING: PlugInKit lists MarkLook registrations outside the tested app bundle."
  echo "These stale or competing registrations can affect Quick Look provider selection:"
  grep -i 'MarkLook' "$output_dir/pluginkit-all-marklook.txt" | grep -Fv "$app/Contents/PlugIns" || true
fi

capture_all "$output_dir/mdls-sample.txt" \
  mdls -name kMDItemContentType -name kMDItemContentTypeTree -name kMDItemKind "$sample"

run qlmanage -r cache
capture_all "$output_dir/qlmanage-sample-t.txt" qlmanage -t -s 512 -o "$output_dir" "$sample"
capture_all "$output_dir/qlmanage-sample-tx.txt" qlmanage -t -x -s 512 -o "$output_dir" "$sample"

run cp "$sample" "$unique_sample"
capture_all "$output_dir/mdls-unique-sample.txt" \
  mdls -name kMDItemContentType -name kMDItemContentTypeTree "$unique_sample"
capture_all "$output_dir/qlmanage-unique-tx.txt" qlmanage -t -x -s 512 -o "$output_dir" "$unique_sample"

capture "$output_dir/output-files.txt" find "$output_dir" -maxdepth 1 -type f -print
if [ -f "$sample_png" ]; then
  capture "$output_dir/sample-png-size.txt" sips -g pixelWidth -g pixelHeight "$sample_png"
  capture "$output_dir/sample-png-sha256.txt" shasum -a 256 "$sample_png"
else
  echo "warning: expected sample PNG not found: $sample_png"
fi

if [ -f "$unique_png" ]; then
  capture "$output_dir/unique-png-size.txt" sips -g pixelWidth -g pixelHeight "$unique_png"
  capture "$output_dir/unique-png-sha256.txt" shasum -a 256 "$unique_png"
else
  echo "warning: expected unique PNG not found: $unique_png"
fi

echo
echo "Runtime log-stream command:"
echo "log stream --style compact --info --predicate 'subsystem == \"com.91wan.MarkLook\" || process CONTAINS \"MarkLookThumbnail\" || eventMessage CONTAINS \"MarkLookThumbnail\" || eventMessage CONTAINS \"ThumbnailProvider\"'"
echo
echo "Interpretation:"
echo "No ThumbnailProvider logs:"
echo "  provider is registered but not selected/invoked."
echo "  Focus on Info.plist, LaunchServices, extension enablement, cache, and provider priority."
echo
echo "ThumbnailProvider logs appear:"
echo "  provider is invoked."
echo "  Focus on QLThumbnailReply drawing/output/cache behavior."

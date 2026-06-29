#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: Scripts/diagnose-quicklook-selection.sh [--enable] /path/to/MarkLook.app" >&2
}

enable="false"
if [ "$#" -eq 2 ] && [ "$1" = "--enable" ]; then
  enable="true"
  shift
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
output_dir="${MARKLOOK_DIAGNOSTICS_DIR:-/tmp/marklook-quicklook-diagnostics-$(date +%Y%m%d-%H%M%S)}"
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

echo "Writing Quick Look diagnostics to: $output_dir"
echo "App: $app"

run "$repo_root/Scripts/validate-built-bundle.sh" "$app"
capture_all "$output_dir/codesign-dv.txt" codesign -dv --verbose=4 "$app"
capture_all "$output_dir/codesign-verify.txt" codesign --verify --deep --strict --verbose=4 "$app"

capture "$output_dir/pluginkit-preview-family.txt" pluginkit -mAv -p com.apple.quicklook.preview
capture "$output_dir/pluginkit-preview-bundle.txt" pluginkit -mAv -i com.91wan.MarkLook.Preview
capture "$output_dir/pluginkit-preview-bundle-all.txt" pluginkit -mADv -i com.91wan.MarkLook.Preview
capture "$output_dir/pluginkit-thumbnail-family.txt" pluginkit -mAv -p com.apple.quicklook.thumbnail
capture "$output_dir/pluginkit-thumbnail-bundle.txt" pluginkit -mAv -i com.91wan.MarkLook.Thumbnail
capture "$output_dir/pluginkit-thumbnail-bundle-all.txt" pluginkit -mADv -i com.91wan.MarkLook.Thumbnail
capture_shell "$output_dir/pluginkit-all-marklook.txt" "pluginkit -mADv | grep -i MarkLook || true"

if grep -i 'MarkLook' "$output_dir/pluginkit-all-marklook.txt" | grep -Fv "$app/Contents/PlugIns" >/dev/null; then
  echo
  echo "WARNING: PlugInKit lists MarkLook registrations outside the tested app bundle."
  echo "These stale or competing registrations can affect Quick Look provider selection:"
  grep -i 'MarkLook' "$output_dir/pluginkit-all-marklook.txt" | grep -Fv "$app/Contents/PlugIns" || true
fi

if [ "$enable" = "true" ]; then
  echo "Attempting local development PlugInKit enablement for MarkLook extensions."
  run pluginkit -e use -i com.91wan.MarkLook.Preview || true
  run pluginkit -e use -i com.91wan.MarkLook.Thumbnail || true
else
  echo "Skipping PlugInKit enablement. Re-run with --enable to attempt local development enablement commands."
fi

for sample in \
  basic.md \
  gfm-table-task-list.md \
  unsafe-html.md \
  long-ai-review.md \
  large-fast-mode.md
do
  sample_path="$samples_dir/$sample"
  test -f "$sample_path"
  capture_all "$output_dir/mdls-$sample.txt" \
    mdls -name kMDItemContentType -name kMDItemContentTypeTree -name kMDItemKind "$sample_path"
done

capture_shell "$output_dir/qlmanage-plugins-marklook.txt" "qlmanage -m plugins | grep -i MarkLook || true"
run qlmanage -r
run qlmanage -r cache
run killall Finder || true

echo
echo "Next manual checks:"
echo "1. Run:"
echo "   log stream --style compact --info --predicate 'subsystem == \"com.91wan.MarkLook\" || process CONTAINS \"MarkLookPreview\" || eventMessage CONTAINS \"MarkLookPreview\"'"
echo "2. In another terminal, run: open -R Samples/basic.md"
echo "3. Press Space in Finder and check whether PreviewExtension logs appear."

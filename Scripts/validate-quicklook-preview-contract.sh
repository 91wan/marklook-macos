#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: Scripts/validate-quicklook-preview-contract.sh [/path/to/MarkLook.app]" >&2
}

if [ "$#" -gt 1 ]; then
  usage
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"

validate_preview_info() {
  info_plist="$1"
  label="$2"

  test -f "$info_plist"
  plutil -lint "$info_plist" >/dev/null

  /usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$info_plist" |
    grep -q '^com.apple.quicklook.preview$'
  /usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPrincipalClass' "$info_plist" |
    grep -q 'PreviewViewController'

  data_based="$(mktemp)"
  if /usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLIsDataBasedPreview' "$info_plist" >"$data_based" 2>/dev/null; then
    if grep -Eiq '^(true|yes|1)$' "$data_based"; then
      echo "error: $label declares QLIsDataBasedPreview=true but uses view-based PreviewViewController" >&2
      rm -f "$data_based"
      exit 1
    fi
  fi
  rm -f "$data_based"
}

validate_preview_info "$repo_root/PreviewExtension/Info.plist" "PreviewExtension/Info.plist"

grep -R "preparePreviewOfFile" "$repo_root/PreviewExtension" >/dev/null
if grep -R "providePreview" "$repo_root/PreviewExtension" >/dev/null; then
  echo "error: PreviewExtension implements a data-based providePreview path; v0.1 must stay view-based" >&2
  exit 1
fi

if [ "$#" -eq 1 ]; then
  app="$1"
  preview_info="$app/Contents/PlugIns/MarkLookPreview.appex/Contents/Info.plist"
  validate_preview_info "$preview_info" "$preview_info"
fi

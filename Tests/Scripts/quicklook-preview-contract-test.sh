#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
validator="$repo_root/Scripts/validate-quicklook-preview-contract.sh"

if [ ! -x "$validator" ]; then
  echo "error: validator is missing or not executable: $validator" >&2
  exit 1
fi

"$validator"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

preview_info="$fixture_root/MarkLook.app/Contents/PlugIns/MarkLookPreview.appex/Contents/Info.plist"
mkdir -p "$(dirname "$preview_info")"
cp "$repo_root/PreviewExtension/Info.plist" "$preview_info"

if /usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLIsDataBasedPreview' "$preview_info" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c 'Set :NSExtension:NSExtensionAttributes:QLIsDataBasedPreview true' "$preview_info"
else
  /usr/libexec/PlistBuddy -c 'Add :NSExtension:NSExtensionAttributes:QLIsDataBasedPreview bool true' "$preview_info"
fi

if "$validator" "$fixture_root/MarkLook.app" >"$fixture_root/validator.out" 2>&1; then
  echo "error: validator accepted a data-based preview declaration for a view-based controller" >&2
  exit 1
fi

grep -q 'QLIsDataBasedPreview=true' "$fixture_root/validator.out"

#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: Scripts/validate-package-artifact.sh path/to/MarkLook-...zip" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 64
fi

zip_path="$1"
if [ ! -f "$zip_path" ]; then
  echo "error: package zip not found: $zip_path" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
package_dir="$(cd "$(dirname "$zip_path")" && pwd -P)"
zip_name="$(basename "$zip_path")"
manifest_path="$package_dir/MANIFEST.txt"
sha_path="$zip_path.sha256"

if [ -f "$sha_path" ]; then
  (
    cd "$package_dir"
    shasum -a 256 -c "$(basename "$sha_path")"
  )
fi

extract_root="$(mktemp -d)"
apps_file="$(mktemp)"
entitlements_file="$(mktemp)"
trap 'rm -rf "$extract_root"; rm -f "$apps_file" "$entitlements_file"' EXIT

ditto -x -k "$zip_path" "$extract_root"

/usr/bin/find "$extract_root" -name MarkLook.app -type d -prune -print >"$apps_file"
app_count="$(wc -l <"$apps_file" | tr -d ' ')"
if [ "$app_count" -ne 1 ]; then
  echo "error: expected exactly one MarkLook.app in package, found $app_count" >&2
  cat "$apps_file" >&2
  exit 1
fi

app="$(sed -n '1p' "$apps_file")"
preview="$app/Contents/PlugIns/MarkLookPreview.appex"
thumbnail="$app/Contents/PlugIns/MarkLookThumbnail.appex"

test -d "$preview"
test -d "$thumbnail"

"$repo_root/Scripts/validate-built-bundle.sh" "$app"
"$repo_root/Scripts/validate-quicklook-preview-contract.sh" "$app"

if [ ! -f "$manifest_path" ]; then
  extracted_manifest="$extract_root/MANIFEST.txt"
  if [ -f "$extracted_manifest" ]; then
    manifest_path="$extracted_manifest"
  else
    echo "error: MANIFEST.txt not found next to package or inside extracted archive" >&2
    exit 1
  fi
fi

if grep -q '^AppIcon status: committed' "$manifest_path"; then
  test -f "$app/Contents/Resources/Assets.car"
fi

check_no_network_entitlement() {
  local target="$1"
  if codesign -d --entitlements :- "$target" >"$entitlements_file" 2>/dev/null; then
    if grep -q 'com.apple.security.network.client' "$entitlements_file"; then
      echo "error: network client entitlement found in $target" >&2
      exit 1
    fi
  fi
}

check_no_network_entitlement "$app"
check_no_network_entitlement "$preview"
check_no_network_entitlement "$thumbnail"

preview_types="$(mktemp)"
thumbnail_types="$(mktemp)"
trap 'rm -rf "$extract_root"; rm -f "$apps_file" "$entitlements_file" "$preview_types" "$thumbnail_types"' EXIT

/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLSupportedContentTypes' "$preview/Contents/Info.plist" |
  awk '/^[[:space:]]+[[:alnum:].-]+$/ { gsub(/^[[:space:]]+/, ""); print }' >"$preview_types"

/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLSupportedContentTypes' "$thumbnail/Contents/Info.plist" |
  awk '/^[[:space:]]+[[:alnum:].-]+$/ { gsub(/^[[:space:]]+/, ""); print }' >"$thumbnail_types"

! grep -q 'public.plain-text' "$preview_types"
! grep -q 'public.plain-text' "$thumbnail_types"

if grep -q '^Build mode: apple-development' "$manifest_path"; then
  codesign --verify --deep --strict --verbose=4 "$app"
fi

echo "Package artifact OK: $zip_path"

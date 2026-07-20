#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  Scripts/validate-developer-id-artifact.sh --signed-only path/to/MarkLook.app-or.zip
  Scripts/validate-developer-id-artifact.sh --notarized path/to/MarkLook.app-or.zip

Modes:
  --signed-only  Require Developer ID Application signing and hardened runtime.
  --notarized    Require signed-only checks plus stapler validation and spctl assessment.
USAGE
}

die_usage() {
  usage
  exit 64
}

if [ "$#" -ne 2 ]; then
  die_usage
fi

mode="$1"
artifact_path="$2"
case "$mode" in
  --signed-only|--notarized)
    ;;
  *)
    echo "error: unknown Developer ID artifact validation mode: $mode" >&2
    die_usage
    ;;
esac

if [ ! -e "$artifact_path" ]; then
  echo "error: artifact not found: $artifact_path" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
codesign_cmd="${MARKLOOK_DEVID_CODESIGN:-codesign}"
ditto_cmd="${MARKLOOK_DEVID_DITTO:-ditto}"
xcrun_cmd="${MARKLOOK_DEVID_XCRUN:-xcrun}"
spctl_cmd="${MARKLOOK_DEVID_SPCTL:-spctl}"
ruby_cmd="${MARKLOOK_DEVID_RUBY:-ruby}"
validate_built_bundle="${MARKLOOK_DEVID_VALIDATE_BUILT_BUNDLE:-$repo_root/Scripts/validate-built-bundle.sh}"
validate_preview_contract="${MARKLOOK_DEVID_VALIDATE_PREVIEW_CONTRACT:-$repo_root/Scripts/validate-quicklook-preview-contract.sh}"
validate_thumbnail_boundaries="${MARKLOOK_DEVID_VALIDATE_THUMBNAIL_BOUNDARIES:-$repo_root/Scripts/validate-thumbnail-boundaries.sh}"

extract_root=""
apps_file=""
entitlements_file="$(mktemp)"
entitlements_json="$(mktemp)"
details_file="$(mktemp)"
trap 'rm -rf "$extract_root"; rm -f "$apps_file" "$entitlements_file" "$entitlements_json" "$details_file"' EXIT

case "$artifact_path" in
  *.app)
    app="$artifact_path"
    ;;
  *.zip)
    extract_root="$(mktemp -d)"
    apps_file="$(mktemp)"
    "$ditto_cmd" -x -k "$artifact_path" "$extract_root"
    /usr/bin/find "$extract_root" -name MarkLook.app -type d -prune -print >"$apps_file"
    app_count="$(wc -l <"$apps_file" | tr -d ' ')"
    if [ "$app_count" -ne 1 ]; then
      echo "error: expected exactly one MarkLook.app in package, found $app_count" >&2
      cat "$apps_file" >&2
      exit 1
    fi
    app="$(sed -n '1p' "$apps_file")"
    ;;
  *)
    echo "error: artifact must be a .app bundle or .zip package: $artifact_path" >&2
    exit 1
    ;;
esac

preview="$app/Contents/PlugIns/MarkLookPreview.appex"
thumbnail="$app/Contents/PlugIns/MarkLookThumbnail.appex"
test -d "$app"
test -d "$preview"
test -d "$thumbnail"

"$validate_built_bundle" "$app"
"$validate_preview_contract" "$app"
"$validate_thumbnail_boundaries"

check_codesign_details() {
  local target="$1"
  local label="$2"

  "$codesign_cmd" --verify --deep --strict --verbose=4 "$target"
  "$codesign_cmd" -dv --verbose=4 "$target" >"$details_file" 2>&1
  if ! grep -q '^Authority=Developer ID Application:' "$details_file"; then
    echo "error: $label is not signed by Developer ID Application" >&2
    exit 1
  fi
  if ! awk -F= '/^TeamIdentifier=/ { if ($2 != "" && $2 != "not set") found = 1 } END { exit found ? 0 : 1 }' "$details_file"; then
    echo "error: $label is missing TeamIdentifier" >&2
    exit 1
  fi
  if ! grep -Eq 'Runtime Version=|flags=.*runtime' "$details_file"; then
    echo "error: $label is missing hardened runtime" >&2
    exit 1
  fi
}

check_exact_entitlements() {
  local target="$1"
  local label="$2"
  shift 2

  : >"$entitlements_file"
  if ! "$codesign_cmd" -d --entitlements :- "$target" >"$entitlements_file" 2>/dev/null; then
    echo "error: could not read entitlements from $label" >&2
    exit 1
  fi
  if [ ! -s "$entitlements_file" ]; then
    echo "error: $label has no entitlement payload" >&2
    exit 1
  fi
  if ! /usr/bin/plutil -convert json -o "$entitlements_json" "$entitlements_file" >/dev/null 2>&1; then
    echo "error: $label has an invalid entitlement payload" >&2
    exit 1
  fi

  "$ruby_cmd" -rjson - "$entitlements_json" "$label" "$@" <<'RUBY'
path = ARGV.shift
label = ARGV.shift
expected = ARGV.sort
entitlements = JSON.parse(File.read(path))

unless entitlements.is_a?(Hash)
  warn "error: #{label} entitlement payload is not a dictionary"
  exit 1
end

actual = entitlements.keys.sort
unless actual == expected
  warn "error: #{label} entitlements differ"
  warn "expected: #{expected.inspect}"
  warn "actual:   #{actual.inspect}"
  exit 1
end

invalid = expected.reject { |key| entitlements[key] == true }
unless invalid.empty?
  warn "error: #{label} required entitlements are not true: #{invalid.inspect}"
  exit 1
end
RUBY
}

check_codesign_details "$app" "MarkLook.app"
check_codesign_details "$preview" "MarkLookPreview.appex"
check_codesign_details "$thumbnail" "MarkLookThumbnail.appex"

check_exact_entitlements \
  "$app" \
  "MarkLook.app" \
  com.apple.security.app-sandbox \
  com.apple.security.files.user-selected.read-only
check_exact_entitlements \
  "$preview" \
  "MarkLookPreview.appex" \
  com.apple.security.app-sandbox
check_exact_entitlements \
  "$thumbnail" \
  "MarkLookThumbnail.appex" \
  com.apple.security.app-sandbox

if [ "$mode" = "--notarized" ]; then
  "$xcrun_cmd" stapler validate "$app"
  "$spctl_cmd" --assess --type execute --verbose=4 "$app"
fi

echo "Developer ID artifact OK: $artifact_path"

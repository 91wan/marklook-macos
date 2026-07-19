#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  Scripts/package-debug.sh --unsigned-ci
  DEVELOPMENT_TEAM=<TEAM_ID> Scripts/package-debug.sh --apple-development

Modes:
  --unsigned-ci        Build a CI-only unsigned Debug bundle and package it.
  --apple-development Build with Apple Development signing for local validation only.
USAGE
}

die_usage() {
  usage
  exit 64
}

if [ "$#" -ne 1 ]; then
  die_usage
fi

mode="$1"
case "$mode" in
  --unsigned-ci)
    build_mode="unsigned-ci"
    ;;
  --apple-development)
    build_mode="apple-development"
    if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
      echo "error: DEVELOPMENT_TEAM is required for --apple-development" >&2
      die_usage
    fi
    ;;
  *)
    echo "error: unknown packaging mode: $mode" >&2
    die_usage
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
cd "$repo_root"

xcodegen_cmd="${MARKLOOK_PACKAGE_XCODEGEN:-xcodegen}"
xcodebuild_cmd="${MARKLOOK_PACKAGE_XCODEBUILD:-xcodebuild}"
ditto_cmd="${MARKLOOK_PACKAGE_DITTO:-ditto}"
shasum_cmd="${MARKLOOK_PACKAGE_SHASUM:-shasum}"
codesign_cmd="${MARKLOOK_PACKAGE_CODESIGN:-codesign}"
lsregister_cmd="${MARKLOOK_PACKAGE_LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister}"
pluginkit_cmd="${MARKLOOK_PACKAGE_PLUGINKIT:-pluginkit}"
validate_built_bundle="${MARKLOOK_PACKAGE_VALIDATE_BUILT_BUNDLE:-$repo_root/Scripts/validate-built-bundle.sh}"
validate_preview_contract="${MARKLOOK_PACKAGE_VALIDATE_PREVIEW_CONTRACT:-$repo_root/Scripts/validate-quicklook-preview-contract.sh}"
validate_thumbnail_boundaries="${MARKLOOK_PACKAGE_VALIDATE_THUMBNAIL_BOUNDARIES:-$repo_root/Scripts/validate-thumbnail-boundaries.sh}"
validate_diagnostics_boundaries="${MARKLOOK_PACKAGE_VALIDATE_DIAGNOSTICS_BOUNDARIES:-$repo_root/Scripts/validate-diagnostics-boundaries.sh}"
build_apple_development="${MARKLOOK_PACKAGE_BUILD_APPLE_DEVELOPMENT:-$repo_root/Scripts/build-local-apple-development.sh}"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' MarkLookApp/Info.plist)"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' MarkLookApp/Info.plist)"
short_sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
commit_sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
artifact_stem="MarkLook-${version}-debug-${short_sha}"
dist_root="${MARKLOOK_PACKAGE_DIST_DIR:-$repo_root/dist}"
output_dir="$dist_root/$artifact_stem"
package_app="$output_dir/MarkLook.app"
zip_name="$artifact_stem.zip"
zip_path="$output_dir/$zip_name"
sha_path="$zip_path.sha256"
manifest_path="$output_dir/MANIFEST.txt"
built_app=""

unregister_disposable_app() {
  local app="$1"

  [ -n "$app" ] || return
  "$pluginkit_cmd" -r "$app/Contents/PlugIns/MarkLookPreview.appex" >/dev/null 2>&1 || true
  "$pluginkit_cmd" -r "$app/Contents/PlugIns/MarkLookThumbnail.appex" >/dev/null 2>&1 || true
  "$lsregister_cmd" -u "$app" >/dev/null 2>&1 || true
}

cleanup_disposable_registrations() {
  unregister_disposable_app "$built_app"
  unregister_disposable_app "$package_app"
}

trap cleanup_disposable_registrations EXIT

rm -rf "$output_dir"
mkdir -p "$output_dir"

case "$build_mode" in
  unsigned-ci)
    derived_data=".build/PackageUnsignedDerivedData"
    built_app="$repo_root/$derived_data/Build/Products/Debug/MarkLook.app"
    rm -rf "$derived_data"
    "$xcodegen_cmd" generate
    "$xcodebuild_cmd" \
      -project MarkLook.xcodeproj \
      -scheme MarkLook \
      -configuration Debug \
      -derivedDataPath "$derived_data" \
      CODE_SIGNING_ALLOWED=NO \
      build
    signing_identity_summary="unsigned CI build; not a launchable trust artifact"
    team_identifier="not available"
    codesign_verification_result="not run for unsigned-ci mode"
    codesign_details="not recorded for unsigned-ci mode"
    ;;
  apple-development)
    built_app="$repo_root/.build/LocalDerivedData/Build/Products/Debug/MarkLook.app"
    "$build_apple_development"
    signing_identity_summary="Apple Development local validation package"
    ;;
esac

test -d "$built_app"
"$ditto_cmd" "$built_app" "$package_app"

"$validate_built_bundle" "$package_app"
"$validate_preview_contract" "$package_app"
"$validate_thumbnail_boundaries"
"$validate_diagnostics_boundaries"

if [ "$build_mode" = "apple-development" ]; then
  codesign_verify_file="$output_dir/codesign-verify.txt"
  codesign_details_file="$output_dir/codesign-details.txt"
  "$codesign_cmd" --verify --deep --strict --verbose=4 "$package_app" >"$codesign_verify_file" 2>&1
  codesign_details="$("$codesign_cmd" -dv --verbose=4 "$package_app" 2>&1)"
  printf '%s\n' "$codesign_details" >"$codesign_details_file"
  if printf '%s\n' "$codesign_details" | grep -q 'Signature=adhoc'; then
    echo "error: Apple Development package resolved to ad-hoc signature" >&2
    exit 1
  fi
  team_identifier="$(printf '%s\n' "$codesign_details" | awk -F= '/^TeamIdentifier=/ { print $2; exit }')"
  if [ -z "$team_identifier" ] || [ "$team_identifier" = "not set" ]; then
    echo "error: Apple Development package is missing TeamIdentifier" >&2
    exit 1
  fi
  first_authority="$(printf '%s\n' "$codesign_details" | awk -F= '/^Authority=/ { print $2; exit }')"
  if [ -n "$first_authority" ]; then
    signing_identity_summary="$first_authority"
  fi
  codesign_verification_result="passed; see $codesign_verify_file"
fi

if [ -d MarkLookApp/Assets.xcassets/AppIcon.appiconset ]; then
  test -f "$package_app/Contents/Resources/Assets.car"
  icon_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$package_app/Contents/Info.plist" 2>/dev/null || true)"
  if [ -f "$package_app/Contents/Resources/AppIcon.icns" ]; then
    appicon_status="committed; Assets.car present; AppIcon.icns present; CFBundleIconName=${icon_name:-not set}"
  else
    appicon_status="committed; Assets.car present; AppIcon.icns not emitted by this build; CFBundleIconName=${icon_name:-not set}"
  fi
else
  appicon_status="generic/default icon; production icon not yet merged"
fi

(
  cd "$output_dir"
  "$ditto_cmd" -c -k --keepParent MarkLook.app "$zip_name"
  "$shasum_cmd" -a 256 "$zip_name" >"$(basename "$sha_path")"
)
zip_sha="$(awk '{ print $1 }' "$sha_path")"

cat >"$manifest_path" <<EOF
MarkLook debug package manifest

MarkLook version: $version ($build_number)
Git commit: $commit_sha
Build mode: $build_mode
Signing identity summary: $signing_identity_summary
TeamIdentifier: $team_identifier
Codesign verification result: $codesign_verification_result
AppIcon status: $appicon_status
Package directory: $output_dir
Package path: $zip_path
ZIP sha256: $zip_sha

Public release caveat:
Developer ID Application signing, hardened runtime, notarization, and stapling are still required for public distribution.

Known limitations:
- Apple Development packages are local validation only and do not prove public distribution trust.
- unsigned-ci packages are not installable trust artifacts.
- No v0.1.0 tag or public GitHub Release is created by this script.
EOF

echo "Package directory: $output_dir"
echo "App bundle: $package_app"
echo "ZIP: $zip_path"
echo "SHA256: $zip_sha"
echo "Manifest: $manifest_path"

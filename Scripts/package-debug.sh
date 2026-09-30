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

# Admit both directories before traps, disposable allocation, or release tools.
# The fixed locale is required by system Ruby's Unicode path normalization.
source "$script_dir/release-path-policy.sh"
dist_root="$(LC_ALL=en_US.UTF-8 canonicalize_release_path dist MARKLOOK_PACKAGE_DIST_DIR \
  "${MARKLOOK_PACKAGE_DIST_DIR-$repo_root/dist}" "$repo_root" /usr/bin/ruby /usr/bin/getconf)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' MarkLookApp/Info.plist)"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' MarkLookApp/Info.plist)"
short_sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
commit_sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
artifact_stem="MarkLook-${version}-debug-${short_sha}"
output_input="$dist_root/$artifact_stem"
output_dir="$(LC_ALL=en_US.UTF-8 canonicalize_release_path dist debug-artifact-directory \
  "$output_input" "$repo_root" /usr/bin/ruby /usr/bin/getconf)"
if [ -L "$output_input" ]; then
  echo 'error: unsafe debug-artifact-directory: linked artifact directory' >&2
  exit 1
fi
case "$output_dir" in
  "$dist_root"/*) ;;
  *) echo 'error: unsafe debug-artifact-directory: outside admitted dist' >&2; exit 1 ;;
esac
os_temp="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)"
zip_name="$artifact_stem.zip"
zip_path="$output_dir/$zip_name"
sha_path="$zip_path.sha256"
manifest_path="$output_dir/MANIFEST.txt"
built_app=""
package_app=""
run_root=""
active_tool=""
launching_tool=0
pending_signal=0
cleanup_failed=0

handle_signal() {
  [ "$pending_signal" -ne 0 ] || pending_signal="$1"
  # Defer exit until $! (or the newly allocated root) has been captured.
  [ "$launching_tool" -eq 1 ] || exit "$pending_signal"
}

stop_owned_tool() {
  local attempt
  [ -n "$active_tool" ] || return 0
  # Monitor mode gives each launched tool its own group, including descendants.
  kill -KILL -- "-$active_tool" 2>/dev/null || true
  # Cap settlement at 50 polls; reap only after the whole group has stopped.
  for ((attempt=0; attempt<50; attempt++)); do
    kill -0 -- "-$active_tool" 2>/dev/null || break
    /bin/sleep 0.02
  done
  if kill -0 -- "-$active_tool" 2>/dev/null; then
    cleanup_failed=1
    return 1
  fi
  wait "$active_tool" 2>/dev/null || true
  active_tool=""
}

run_tool() {
  local status=0
  launching_tool=1
  "$@" &
  active_tool=$!
  launching_tool=0
  [ "$pending_signal" -eq 0 ] || exit "$pending_signal"
  wait "$active_tool" || status=$?
  # Reap/stop remaining writers even if the leader failed or exited early.
  if ! stop_owned_tool; then
    [ "$status" -ne 0 ] || status=1
  fi
  return "$status"
}

unregister_disposable_app() {
  local app="$1"

  [ -n "$app" ] || return
  "$pluginkit_cmd" -r "$app/Contents/PlugIns/MarkLookPreview.appex" >/dev/null 2>&1 || true
  "$pluginkit_cmd" -r "$app/Contents/PlugIns/MarkLookThumbnail.appex" >/dev/null 2>&1 || true
  "$lsregister_cmd" -u "$app" >/dev/null 2>&1 || true
}

cleanup_disposable_registrations() {
  local status=$? removal_status
  trap - EXIT
  trap '' HUP TERM INT
  set +e
  if [ "$cleanup_failed" -eq 1 ] || ! stop_owned_tool; then
    echo "error: cleanup failure: owned tool group $active_tool did not settle within 50 polls; preserving run root: $run_root" >&2
    [ "$status" -ne 0 ] || status=1
    exit "$status"
  fi
  if [ "$build_mode" = unsigned-ci ]; then
    unregister_disposable_app "$built_app"
  fi
  unregister_disposable_app "$package_app"
  if [ -n "$run_root" ]; then
    rm -rf "$run_root"
    removal_status=$?
    if [ "$removal_status" -ne 0 ]; then
      echo "error: cleanup failure: rm exited $removal_status; retained run root: $run_root" >&2
      [ "$status" -ne 0 ] || status=1
    fi
  fi
  exit "$status"
}

trap cleanup_disposable_registrations EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 143' TERM
trap 'handle_signal 130' INT
set -m

launching_tool=1
run_root="$(/usr/bin/mktemp -d "${os_temp%/}/marklook-debug.XXXXXX")"
launching_tool=0
[ "$pending_signal" -eq 0 ] || exit "$pending_signal"
package_app="$run_root/package/MarkLook.app"
mkdir -p "$run_root/package"

rm -rf "$output_dir"
mkdir -p "$output_dir"

case "$build_mode" in
  unsigned-ci)
    derived_data="$run_root/DerivedData"
    built_app="$derived_data/Build/Products/Debug/MarkLook.app"
    run_tool "$xcodegen_cmd" generate
    run_tool "$xcodebuild_cmd" \
      -project MarkLook.xcodeproj \
      -scheme MarkLook \
      -configuration Debug \
      -derivedDataPath "$derived_data" \
      CODE_SIGNING_ALLOWED=NO \
      build
    signing_identity_summary="unsigned CI build; not a launchable trust artifact"
    team_identifier="not available"
    codesign_verification_result="not run for unsigned-ci mode"
    ;;
  apple-development)
    built_app="$repo_root/.build/LocalDerivedData/Build/Products/Debug/MarkLook.app"
    # The source helper retains its existing lifecycle; suppress its raw report.
    run_tool "$build_apple_development" >"$run_root/apple-development-build.log" 2>&1
    signing_identity_summary="Apple Development local validation package; certificate subject redacted"
    ;;
esac

test -d "$built_app"
run_tool "$ditto_cmd" "$built_app" "$package_app"

run_tool "$validate_built_bundle" "$package_app"
run_tool "$validate_preview_contract" "$package_app"
run_tool "$validate_thumbnail_boundaries"
run_tool "$validate_diagnostics_boundaries"

if [ "$build_mode" = "apple-development" ]; then
  codesign_verify_file="$run_root/codesign-verify.txt"
  codesign_details_file="$run_root/codesign-details.txt"
  run_tool "$codesign_cmd" --verify --deep --strict --verbose=4 "$package_app" >"$codesign_verify_file" 2>&1
  run_tool "$codesign_cmd" -dv --verbose=4 "$package_app" >"$codesign_details_file" 2>&1
  if grep -q 'Signature=adhoc' "$codesign_details_file"; then
    echo "error: Apple Development package resolved to ad-hoc signature" >&2
    exit 1
  fi
  team_identifier="$(awk -F= '/^TeamIdentifier=/ { print $2; exit }' "$codesign_details_file")"
  if [ -z "$team_identifier" ] || [ "$team_identifier" = "not set" ]; then
    echo "error: Apple Development package is missing TeamIdentifier" >&2
    exit 1
  fi
  team_identifier="redacted"
  codesign_verification_result="passed; raw verification/details were temporary and are removed after packaging"
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

run_tool "$ditto_cmd" -c -k --keepParent "$package_app" "$zip_path"
cd "$output_dir"
run_tool "$shasum_cmd" -a 256 "$zip_name" >"$sha_path"
cd "$repo_root"
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
Package directory: .
Package path: $zip_name
ZIP sha256: $zip_sha

Public release caveat:
Developer ID Application signing, hardened runtime, notarization, and stapling are still required for public distribution.

Known limitations:
- Apple Development packages are local validation only and do not prove public distribution trust.
- unsigned-ci packages are not installable trust artifacts.
- The Apple Development source build lifecycle is excluded; .build/LocalDerivedData and its source App remain owned by the unchanged source builder, not this packaging cleanup.
- Packaged copies and unsigned DerivedData are temporary; SIGKILL and power loss cannot run cleanup.
- No v0.1.0 tag or public GitHub Release is created by this script.
EOF

echo "Package directory: $output_dir"
echo "ZIP: $zip_path"
echo "SHA256: $zip_sha"
echo "Manifest: $manifest_path"

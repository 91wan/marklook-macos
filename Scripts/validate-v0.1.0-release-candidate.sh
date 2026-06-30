#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  Scripts/validate-v0.1.0-release-candidate.sh --ci
  DEVELOPMENT_TEAM=<TEAM_ID> Scripts/validate-v0.1.0-release-candidate.sh --local

Modes:
  --ci     Run the unsigned CI-compatible v0.1.0 release candidate gate.
  --local  Run the CI gate plus Apple Development local signing/runtime checks.
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
  --ci)
    gate_mode="ci"
    ;;
  --local)
    gate_mode="local"
    if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
      echo "error: DEVELOPMENT_TEAM is required for --local" >&2
      die_usage
    fi
    ;;
  *)
    echo "error: unknown release candidate validation mode: $mode" >&2
    die_usage
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
cd "$repo_root"

ruby_cmd="${MARKLOOK_RC_RUBY:-ruby}"
xcodegen_cmd="${MARKLOOK_RC_XCODEGEN:-xcodegen}"
xcodebuild_cmd="${MARKLOOK_RC_XCODEBUILD:-xcodebuild}"
xcrun_cmd="${MARKLOOK_RC_XCRUN:-xcrun}"
swift_cmd="${MARKLOOK_RC_SWIFT:-swift}"
ditto_cmd="${MARKLOOK_RC_DITTO:-ditto}"
open_cmd="${MARKLOOK_RC_OPEN:-open}"
package_debug="${MARKLOOK_RC_PACKAGE_DEBUG:-$repo_root/Scripts/package-debug.sh}"
validate_package_artifact="${MARKLOOK_RC_VALIDATE_PACKAGE_ARTIFACT:-$repo_root/Scripts/validate-package-artifact.sh}"
validate_built_bundle="${MARKLOOK_RC_VALIDATE_BUILT_BUNDLE:-$repo_root/Scripts/validate-built-bundle.sh}"
validate_preview_contract="${MARKLOOK_RC_VALIDATE_PREVIEW_CONTRACT:-$repo_root/Scripts/validate-quicklook-preview-contract.sh}"
validate_renderer_security="${MARKLOOK_RC_VALIDATE_RENDERER_SECURITY:-$repo_root/Scripts/validate-renderer-security.sh}"
validate_diagnostics_boundaries="${MARKLOOK_RC_VALIDATE_DIAGNOSTICS_BOUNDARIES:-$repo_root/Scripts/validate-diagnostics-boundaries.sh}"
validate_thumbnail_boundaries="${MARKLOOK_RC_VALIDATE_THUMBNAIL_BOUNDARIES:-$repo_root/Scripts/validate-thumbnail-boundaries.sh}"
validate_supported_types="${MARKLOOK_RC_VALIDATE_SUPPORTED_TYPES:-$repo_root/Scripts/validate-supported-types.sh}"
package_debug_test="${MARKLOOK_RC_PACKAGE_DEBUG_TEST:-$repo_root/Tests/Scripts/package-debug-test.sh}"
quicklook_preview_contract_test="${MARKLOOK_RC_QUICKLOOK_PREVIEW_CONTRACT_TEST:-$repo_root/Tests/Scripts/quicklook-preview-contract-test.sh}"
validate_signed_mode_test="${MARKLOOK_RC_VALIDATE_SIGNED_MODE_TEST:-$repo_root/Tests/Scripts/validate-signed-quicklook-mode-test.sh}"
doctor_signing_test="${MARKLOOK_RC_DOCTOR_SIGNING_TEST:-$repo_root/Tests/Scripts/doctor-signing-team-id-test.sh}"
build_apple_development="${MARKLOOK_RC_BUILD_APPLE_DEVELOPMENT:-$repo_root/Scripts/build-local-apple-development.sh}"
validate_signed_quicklook="${MARKLOOK_RC_VALIDATE_SIGNED_QUICKLOOK:-$repo_root/Scripts/validate-signed-quicklook.sh}"
diagnose_thumbnail_selection="${MARKLOOK_RC_DIAGNOSE_THUMBNAIL_SELECTION:-$repo_root/Scripts/diagnose-thumbnail-selection.sh}"
dist_root="${MARKLOOK_RC_DIST_DIR:-$repo_root/dist}"
install_app="${MARKLOOK_RC_INSTALL_APP:-/Applications/MarkLook.app}"
renderer_fixture="${MARKLOOK_RC_RENDERER_FIXTURE:-/tmp/marklook-renderer-safe-v0.1.0.html}"
project_dump="${MARKLOOK_RC_PROJECT_DUMP:-/tmp/marklook-project-dump-v0.1.0.yml}"
derived_data="${MARKLOOK_RC_DERIVED_DATA:-.build/ReleaseCandidateDerivedData}"
short_sha="$(git rev-parse --short HEAD)"
commit_sha="$(git rev-parse HEAD)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' MarkLookApp/Info.plist)"
artifact_stem="MarkLook-${version}-debug-${short_sha}"
package_zip="$dist_root/$artifact_stem/$artifact_stem.zip"
package_checksum=""

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

run_to_file() {
  local output_file="$1"
  shift
  printf '+'
  printf ' %q' "$@"
  printf ' > %q\n' "$output_file"
  "$@" >"$output_file"
}

wait_for_test_bundles() {
  local bundle_name
  local bundle_path
  local executable_name

  for bundle_name in MarkLookAppTests MarkLookPreviewTests MarkLookThumbnailTests; do
    bundle_path="$derived_data/Build/Products/Debug/$bundle_name.xctest"
    test -d "$bundle_path"
    plutil -lint "$bundle_path/Contents/Info.plist" >/dev/null
    executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle_path/Contents/Info.plist")"
    test -x "$bundle_path/Contents/MacOS/$executable_name"
  done
}

run_xctest_bundle() {
  local bundle_name="$1"
  local bundle_path="$derived_data/Build/Products/Debug/$bundle_name.xctest"
  local log_file="/tmp/marklook-v0.1.0-$bundle_name-xctest.log"

  printf '+'
  printf ' %q' "$xcrun_cmd" xctest "$bundle_path"
  printf ' > %q\n' "$log_file"
  if "$xcrun_cmd" xctest "$bundle_path" >"$log_file" 2>&1; then
    echo "Test log: $log_file"
  else
    tail -n 120 "$log_file" >&2
    return 1
  fi
}

run_xctest_bundles() {
  wait_for_test_bundles
  run_xctest_bundle MarkLookAppTests
  run_xctest_bundle MarkLookPreviewTests
  run_xctest_bundle MarkLookThumbnailTests
}

quit_marklook_if_running() {
  local pid
  local pids
  local wait_count

  if ! pgrep -x MarkLook >/dev/null 2>&1; then
    return 0
  fi

  osascript -e 'tell application "MarkLook" to quit' >/dev/null 2>&1 || true
  for wait_count in 1 2 3 4 5 6 7 8 9 10; do
    if ! pgrep -x MarkLook >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done

  pids="$(pgrep -x MarkLook || true)"
  for pid in $pids; do
    kill "$pid" >/dev/null 2>&1 || true
  done
}

validate_installed_marklook_process() {
  local pid
  local process_path
  local process_count

  sleep 2
  process_count="$(pgrep -x MarkLook | wc -l | tr -d ' ')"
  if [ "$process_count" -eq 0 ]; then
    echo "error: MarkLook process did not launch from $install_app" >&2
    exit 1
  fi
  if [ "$process_count" -ne 1 ]; then
    echo "error: expected one MarkLook process, found $process_count" >&2
    pgrep -x MarkLook | while IFS= read -r pid; do
      ps -p "$pid" -o command=
    done >&2
    exit 1
  fi

  pid="$(pgrep -x MarkLook)"
  process_path="$(ps -p "$pid" -o command=)"
  case "$process_path" in
    "$install_app/Contents/MacOS/MarkLook"*)
      ;;
    *)
      echo "error: MarkLook launched from unexpected path: $process_path" >&2
      exit 1
      ;;
  esac
}

unregister_local_build_quicklook_plugins() {
  local plugin_path

  for plugin_path in \
    "$repo_root/.build/LocalDerivedData/Build/Products/Debug/MarkLook.app/Contents/PlugIns/MarkLookPreview.appex" \
    "$repo_root/.build/LocalDerivedData/Build/Products/Debug/MarkLook.app/Contents/PlugIns/MarkLookThumbnail.appex"; do
    if [ -d "$plugin_path" ]; then
      pluginkit -r "$plugin_path" >/dev/null 2>&1 || true
    fi
  done
}

run_ci_gate() {
  run "$ruby_cmd" -e "require 'yaml'; YAML.load_file('.github/workflows/ci.yml')"

  run sh -n Scripts/package-debug.sh
  run sh -n Scripts/validate-package-artifact.sh
  run sh -n Scripts/validate-v0.1.0-release-candidate.sh
  run sh -n Tests/Scripts/package-debug-test.sh
  run sh -n Tests/Scripts/quicklook-preview-contract-test.sh
  run sh -n Tests/Scripts/validate-signed-quicklook-mode-test.sh
  run sh -n Tests/Scripts/doctor-signing-team-id-test.sh
  run sh -n Tests/Scripts/v0.1-release-gate-test.sh

  run "$package_debug_test"
  run "$quicklook_preview_contract_test"
  run "$validate_signed_mode_test"
  run "$doctor_signing_test"

  run "$validate_diagnostics_boundaries"
  run "$validate_thumbnail_boundaries"
  run "$validate_preview_contract"
  run "$validate_supported_types"

  run_to_file "$project_dump" "$xcodegen_cmd" dump --spec project.yml
  run "$xcodegen_cmd" generate

  rm -rf "$derived_data"
  run "$xcodebuild_cmd" \
    -project MarkLook.xcodeproj \
    -scheme MarkLook \
    -configuration Debug \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build-for-testing

  run_xctest_bundles

  run "$xcodebuild_cmd" \
    -project MarkLook.xcodeproj \
    -scheme MarkLook \
    -configuration Debug \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build

  run "$validate_built_bundle" "$derived_data/Build/Products/Debug/MarkLook.app"
  run "$validate_preview_contract" "$derived_data/Build/Products/Debug/MarkLook.app"

  (
    cd Packages/MarkdownCore
    run env MARKLOOK_RENDERER_SECURITY_FIXTURE="$renderer_fixture" "$swift_cmd" test
  )
  run "$validate_renderer_security" "$renderer_fixture"

  rm -rf "$dist_root"
  run env MARKLOOK_PACKAGE_DIST_DIR="$dist_root" "$package_debug" --unsigned-ci
  run "$validate_package_artifact" "$package_zip"
  package_checksum="$(awk '{ print $1 }' "$package_zip.sha256")"
}

run_local_gate() {
  run env MARKLOOK_PACKAGE_DIST_DIR="$dist_root" "$package_debug" --apple-development
  run "$validate_package_artifact" "$package_zip"
  package_checksum="$(awk '{ print $1 }' "$package_zip.sha256")"

  run "$build_apple_development"
  quit_marklook_if_running
  rm -rf "$install_app"
  run "$ditto_cmd" .build/LocalDerivedData/Build/Products/Debug/MarkLook.app "$install_app"
  run "$open_cmd" "$install_app"
  validate_installed_marklook_process
  unregister_local_build_quicklook_plugins
  run "$validate_signed_quicklook" --development --noninteractive "$install_app"
  run "$diagnose_thumbnail_selection" "$install_app" Samples/basic.md
}

run_ci_gate

if [ "$gate_mode" = "local" ]; then
  run_local_gate
fi

if [ -z "$package_checksum" ] && [ -f "$package_zip.sha256" ]; then
  package_checksum="$(awk '{ print $1 }' "$package_zip.sha256")"
fi

echo "MarkLook v0.1.0 release candidate validation: PASS"
echo "Commit: $commit_sha"
echo "Mode: $gate_mode"
echo "Package path: $package_zip"
echo "Checksum: $package_checksum"

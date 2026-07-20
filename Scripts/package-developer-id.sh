#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  Scripts/package-developer-id.sh --dry-run
  DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<TEAM_ID>)" Scripts/package-developer-id.sh --developer-id
  DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<TEAM_ID>)" NOTARYTOOL_PROFILE=<PROFILE> Scripts/package-developer-id.sh --developer-id --notarize

Modes:
  --dry-run       Validate lane tooling and print intended commands. No signing or notarization is attempted.
  --developer-id  Build, sign, validate, and package a Developer ID Application artifact.
  --notarize      Submit, staple, and assess the Developer ID artifact. Requires --developer-id and NOTARYTOOL_PROFILE.
USAGE
}

die_usage() {
  usage
  exit 64
}

dry_run=0
developer_id=0
notarize=0

if [ "$#" -eq 0 ]; then
  die_usage
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --developer-id)
      developer_id=1
      ;;
    --notarize)
      notarize=1
      ;;
    *)
      echo "error: unknown Developer ID packaging option: $1" >&2
      die_usage
      ;;
  esac
  shift
done

if [ "$dry_run" -eq 1 ] && { [ "$developer_id" -eq 1 ] || [ "$notarize" -eq 1 ]; }; then
  echo "error: --dry-run must be used by itself" >&2
  die_usage
fi

if [ "$dry_run" -eq 0 ] && [ "$developer_id" -eq 0 ]; then
  echo "error: choose --dry-run or --developer-id" >&2
  die_usage
fi

if [ "$notarize" -eq 1 ] && [ "$developer_id" -eq 0 ]; then
  echo "error: --notarize requires --developer-id" >&2
  die_usage
fi

if [ "$developer_id" -eq 1 ] && [ -z "${DEVELOPER_ID_APPLICATION:-}" ]; then
  echo "error: DEVELOPER_ID_APPLICATION is required for --developer-id" >&2
  die_usage
fi

if [ "$notarize" -eq 1 ] && [ -z "${NOTARYTOOL_PROFILE:-}" ]; then
  echo "error: NOTARYTOOL_PROFILE is required for --notarize" >&2
  die_usage
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
cd "$repo_root"

xcodegen_cmd="${MARKLOOK_DEVID_XCODEGEN:-xcodegen}"
xcodebuild_cmd="${MARKLOOK_DEVID_XCODEBUILD:-xcodebuild}"
codesign_cmd="${MARKLOOK_DEVID_CODESIGN:-codesign}"
ditto_cmd="${MARKLOOK_DEVID_DITTO:-ditto}"
shasum_cmd="${MARKLOOK_DEVID_SHASUM:-shasum}"
xcrun_cmd="${MARKLOOK_DEVID_XCRUN:-xcrun}"
spctl_cmd="${MARKLOOK_DEVID_SPCTL:-spctl}"
ruby_cmd="/usr/bin/ruby"
getconf_cmd="/usr/bin/getconf"
validate_release_candidate="${MARKLOOK_DEVID_VALIDATE_RELEASE_CANDIDATE:-$repo_root/Scripts/validate-release-candidate.sh}"
validate_artifact="${MARKLOOK_DEVID_VALIDATE_ARTIFACT:-$repo_root/Scripts/validate-developer-id-artifact.sh}"

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: required tool not found: $tool" >&2
    exit 1
  fi
}

require_executable() {
  local path="$1"
  if [ ! -x "$path" ]; then
    echo "error: required executable not found: $path" >&2
    exit 1
  fi
}

require_lane_tools() {
  require_tool "$xcodegen_cmd"
  require_tool "$xcodebuild_cmd"
  require_tool "$codesign_cmd"
  require_tool "$ditto_cmd"
  require_tool "$shasum_cmd"
  require_tool "$xcrun_cmd"
  require_tool "$spctl_cmd"
  require_tool "$ruby_cmd"
  require_tool "$getconf_cmd"
  require_executable "$validate_release_candidate"
  require_executable "$validate_artifact"
}

canonicalize_disposable_derived_data() {
  local input="$1"
  local resolved
  local repo_build_root="$repo_root/.build"
  local darwin_user_temp
  local darwin_user_temp_root
  local private_tmp_root

  if ! resolved="$("$ruby_cmd" - "$input" <<'RUBY'
path = File.expand_path(ARGV.fetch(0))
cursor = path
suffix = []

until File.exist?(cursor) || File.symlink?(cursor)
  parent = File.dirname(cursor)
  abort "could not resolve path: #{path}" if parent == cursor
  suffix.unshift(File.basename(cursor))
  cursor = parent
end

puts File.join(File.realpath(cursor), *suffix)
RUBY
  )"; then
    echo "error: could not resolve MARKLOOK_DEVID_DERIVED_DATA: $input" >&2
    exit 1
  fi

  if ! darwin_user_temp="$("$getconf_cmd" DARWIN_USER_TEMP_DIR 2>/dev/null)" || [ -z "$darwin_user_temp" ]; then
    echo "error: could not resolve the OS-owned user temporary directory" >&2
    exit 1
  fi
  darwin_user_temp_root="$("$ruby_cmd" -e 'puts File.realpath(ARGV.fetch(0))' "$darwin_user_temp")"
  private_tmp_root="$("$ruby_cmd" -e 'puts File.realpath(ARGV.fetch(0))' /private/tmp)"

  case "$resolved" in
    "$repo_root"|"$repo_root"/*)
      case "$resolved" in
        "$repo_build_root"/*)
          ;;
        *)
          echo "error: unsafe MARKLOOK_DEVID_DERIVED_DATA overlaps the repository: $input" >&2
          exit 1
          ;;
      esac
      ;;
  esac

  if [ "$resolved" = "/" ] || [ "$resolved" = "$repo_root" ] || [[ "$repo_root" == "$resolved"/* ]]; then
    echo "error: unsafe MARKLOOK_DEVID_DERIVED_DATA contains the repository: $input" >&2
    exit 1
  fi

  case "$resolved" in
    "$repo_build_root"/*|"$darwin_user_temp_root"/*|"$private_tmp_root"/*)
      ;;
    *)
      echo "error: unsafe MARKLOOK_DEVID_DERIVED_DATA: $input" >&2
      echo "Use a child of $repo_build_root or a system temporary directory." >&2
      exit 1
      ;;
  esac

  printf '%s\n' "$resolved"
}

require_lane_tools
derived_data_input="${MARKLOOK_DEVID_DERIVED_DATA:-.build/DeveloperIDDerivedData}"
derived_data="$(canonicalize_disposable_derived_data "$derived_data_input")"

if [ "$dry_run" -eq 1 ]; then
  echo "DRY RUN: Developer ID package lane"
  echo "Would run: Scripts/validate-release-candidate.sh --ci"
  echo "Would run: xcodegen generate"
  echo "Would let xcodebuild sign MarkLook.app and embedded Quick Look appex bundles once with Developer ID Application, hardened runtime, target entitlements, and a secure timestamp"
  echo "Would validate with: Scripts/validate-developer-id-artifact.sh --signed-only <artifact>"
  echo "Would create ZIP package and MANIFEST.txt"
  echo "Would notarize only when --notarize and NOTARYTOOL_PROFILE are supplied"
  echo "No signing or notarization attempted."
  exit 0
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' MarkLookApp/Info.plist)"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' MarkLookApp/Info.plist)"
short_sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
commit_sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
artifact_stem="MarkLook-${version}-developer-id-${short_sha}"
dist_root="${MARKLOOK_DEVID_DIST_DIR:-$repo_root/dist}"
output_dir="$dist_root/$artifact_stem"
package_app="$output_dir/MarkLook.app"
zip_name="$artifact_stem.zip"
zip_path="$output_dir/$zip_name"
sha_path="$zip_path.sha256"
manifest_path="$output_dir/MANIFEST.txt"

rm -rf "$output_dir" "$derived_data"
mkdir -p "$output_dir"

"$validate_release_candidate" --ci
"$xcodegen_cmd" generate
"$xcodebuild_cmd" \
  -project MarkLook.xcodeproj \
  -scheme MarkLook \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build

built_app="$derived_data/Build/Products/Release/MarkLook.app"
test -d "$built_app"
"$ditto_cmd" "$built_app" "$package_app"

preview="$package_app/Contents/PlugIns/MarkLookPreview.appex"
thumbnail="$package_app/Contents/PlugIns/MarkLookThumbnail.appex"
test -d "$preview"
test -d "$thumbnail"

"$validate_artifact" --signed-only "$package_app"

(
  cd "$output_dir"
  "$ditto_cmd" -c -k --keepParent MarkLook.app "$zip_name"
  "$shasum_cmd" -a 256 "$zip_name" >"$(basename "$sha_path")"
)
zip_sha="$(awk '{ print $1 }' "$sha_path")"
notarization_status="not requested"
spctl_status="not run"

if [ "$notarize" -eq 1 ]; then
  "$xcrun_cmd" notarytool submit "$zip_path" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  "$xcrun_cmd" stapler staple "$package_app"
  "$spctl_cmd" --assess --type execute --verbose=4 "$package_app"
  spctl_status="passed"
  notarization_status="submitted, accepted, stapled"
  (
    cd "$output_dir"
    rm -f "$zip_name" "$(basename "$sha_path")"
    "$ditto_cmd" -c -k --keepParent MarkLook.app "$zip_name"
    "$shasum_cmd" -a 256 "$zip_name" >"$(basename "$sha_path")"
  )
  zip_sha="$(awk '{ print $1 }' "$sha_path")"
  "$validate_artifact" --notarized "$zip_path"
fi

cat >"$manifest_path" <<EOF
MarkLook Developer ID package manifest

MarkLook version: $version ($build_number)
Git commit: $commit_sha
Build mode: developer-id
Signing identity summary: Developer ID Application: <redacted>
Hardened runtime: required
Notarization: $notarization_status
spctl assessment: $spctl_status
Package directory: $artifact_stem
Package path: $artifact_stem/$zip_name
ZIP sha256: $zip_sha

Public release caveat:
Do not publish this artifact unless Developer ID signing, hardened runtime,
notarization, stapling, and Gatekeeper assessment have all passed.
EOF

echo "Package directory: $output_dir"
echo "App bundle: $package_app"
echo "ZIP: $zip_path"
echo "SHA256: $zip_sha"
echo "Manifest: $manifest_path"

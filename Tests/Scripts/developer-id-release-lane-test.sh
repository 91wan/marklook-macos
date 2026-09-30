#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
doctor="$repo_root/Scripts/doctor-release-identity.sh"
packager="$repo_root/Scripts/package-developer-id.sh"
validator="$repo_root/Scripts/validate-developer-id-artifact.sh"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

assert_status() {
  local expected_status="$1"
  local output_file="$2"
  shift 2
  set +e
  "$@" >"$output_file" 2>&1
  local actual_status="$?"
  set -e
  if [ "$actual_status" -ne "$expected_status" ]; then
    echo "error: expected exit $expected_status, got $actual_status for: $*" >&2
    cat "$output_file" >&2
    exit 1
  fi
}

assert_no_fixture_identity_details() {
  local output_file="$1"
  if grep -Eq 'TEAMTEST01|Example Developer|Local Validation' "$output_file"; then
    echo "error: release lane output leaked synthetic identity details" >&2
    cat "$output_file" >&2
    exit 1
  fi
}

stub_bin="$fixture_root/bin"
stub_log="$fixture_root/stub.log"
mkdir -p "$stub_bin"
touch "$stub_log"
printf '%s\n' "$HOME" >"$fixture_root/expected-home"
printf '%s\n' "$USER" >"$fixture_root/expected-user"

cat >"$stub_bin/security" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ge 3 ] && [ "$1" = "find-identity" ] && [ "$2" = "-p" ] && [ "$3" = "codesigning" ]; then
  cat "$MARKLOOK_RELEASE_IDENTITY_FIXTURE"
  exit 0
fi
echo "unexpected security invocation: $*" >&2
exit 2
STUB

cat >"$stub_bin/pass" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >>"$MARKLOOK_DEVID_TEST_LOG"
STUB

cat >"$stub_bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'xcodebuild %s\n' "$*" >>"$MARKLOOK_DEVID_TEST_LOG"
derived_data=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -derivedDataPath)
      shift
      derived_data="$1"
      ;;
  esac
  shift || true
done
if [ -z "$derived_data" ]; then
  echo "missing derived data path" >&2
  exit 1
fi
mkdir -p \
  "$derived_data/Build/Products/Release/MarkLook.app/Contents/PlugIns/MarkLookPreview.appex" \
  "$derived_data/Build/Products/Release/MarkLook.app/Contents/PlugIns/MarkLookThumbnail.appex"
STUB

cat >"$stub_bin/codesign" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'codesign %s\n' "$*" >>"$MARKLOOK_DEVID_TEST_LOG"
case "${1:-}" in
  --verify)
    exit 0
    ;;
  -dv)
    target="${!#}"
    case "$(basename "$target")" in
      MarkLook.app)
        cat "$MARKLOOK_DEVID_DETAILS_DIR/app.txt" >&2
        ;;
      MarkLookPreview.appex)
        cat "$MARKLOOK_DEVID_DETAILS_DIR/preview.txt" >&2
        ;;
      MarkLookThumbnail.appex)
        cat "$MARKLOOK_DEVID_DETAILS_DIR/thumbnail.txt" >&2
        ;;
      *)
        echo "unexpected details target: $target" >&2
        exit 2
        ;;
    esac
    exit 0
    ;;
  -d)
    if [ "${2:-}" = "--entitlements" ] && [ "${3:-}" = ":-" ]; then
      target="${!#}"
      case "$(basename "$target")" in
        MarkLook.app)
          cat "$MARKLOOK_DEVID_ENTITLEMENTS_DIR/app.plist"
          ;;
        MarkLookPreview.appex)
          cat "$MARKLOOK_DEVID_ENTITLEMENTS_DIR/preview.plist"
          ;;
        MarkLookThumbnail.appex)
          cat "$MARKLOOK_DEVID_ENTITLEMENTS_DIR/thumbnail.plist"
          ;;
        *)
          echo "unexpected entitlement target: $target" >&2
          exit 2
          ;;
      esac
      exit 0
    fi
    ;;
esac
echo "unexpected codesign invocation: $*" >&2
exit 2
STUB

cat >"$stub_bin/validate-release-candidate" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
printf 'validate-release-candidate %s\n' "$*" >>"$root/stub.log"
if [ "$#" -ne 1 ] || [ "$1" != --ci ]; then
  echo "unexpected nested gate arguments" >&2
  exit 1
fi
while IFS= read -r name; do
  case "$name" in
    PATH|LC_ALL|HOME|USER|TMPDIR|PWD|SHLVL|_) ;;
    *)
      echo "unexpected nested environment variable: $name" >&2
      exit 1
      ;;
  esac
done < <(compgen -e)
test "$PATH" = /opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
test "$LC_ALL" = en_US.UTF-8
test "$HOME" = "$(cat "$root/expected-home")"
test "$USER" = "$(cat "$root/expected-user")"
test "$TMPDIR" = "$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)"
STUB

for tool in \
  xcodegen \
  xcrun \
  spctl \
  validate-artifact \
  validate-built-bundle \
  validate-preview-contract \
  validate-thumbnail-boundaries; do
  ln -s pass "$stub_bin/$tool"
done

chmod +x \
  "$stub_bin/security" \
  "$stub_bin/pass" \
  "$stub_bin/xcodebuild" \
  "$stub_bin/codesign" \
  "$stub_bin/validate-release-candidate"

cat >"$fixture_root/apple-development-only.txt" <<'FIXTURE'
  1) ABCDEF0123456789 "Apple Development: Local Validation (TEAMTEST01)"
     1 valid identities found
FIXTURE

assert_status 1 "$fixture_root/doctor-no-developer-id.out" \
  env MARKLOOK_RELEASE_SECURITY="$stub_bin/security" \
    MARKLOOK_RELEASE_IDENTITY_FIXTURE="$fixture_root/apple-development-only.txt" \
    "$doctor"
grep -q '^Apple Development identity: FOUND' "$fixture_root/doctor-no-developer-id.out"
grep -q '^Developer ID Application identity: NOT FOUND' "$fixture_root/doctor-no-developer-id.out"
grep -q '^Public binary release lane cannot proceed\.' "$fixture_root/doctor-no-developer-id.out"
grep -q '^Source/local-validation remains available\.' "$fixture_root/doctor-no-developer-id.out"
assert_no_fixture_identity_details "$fixture_root/doctor-no-developer-id.out"

cat >"$fixture_root/developer-id.txt" <<'FIXTURE'
  1) ABCDEF0123456789 "Apple Development: Local Validation (TEAMTEST01)"
  2) FEDCBA9876543210 "Developer ID Application: Example Developer (TEAMTEST01)"
     2 valid identities found
FIXTURE

assert_status 0 "$fixture_root/doctor-developer-id.out" \
  env MARKLOOK_RELEASE_SECURITY="$stub_bin/security" \
    MARKLOOK_RELEASE_IDENTITY_FIXTURE="$fixture_root/developer-id.txt" \
    "$doctor"
grep -q '^Developer ID Application identity: FOUND' "$fixture_root/doctor-developer-id.out"
grep -q '^Next: Scripts/package-developer-id.sh --developer-id' "$fixture_root/doctor-developer-id.out"
assert_no_fixture_identity_details "$fixture_root/doctor-developer-id.out"

MARKLOOK_DEVID_TEST_LOG="$stub_log" \
MARKLOOK_DEVID_XCODEGEN="$stub_bin/xcodegen" \
MARKLOOK_DEVID_XCODEBUILD="$stub_bin/xcodebuild" \
MARKLOOK_DEVID_CODESIGN="$stub_bin/codesign" \
MARKLOOK_DEVID_DITTO=/usr/bin/ditto \
MARKLOOK_DEVID_SHASUM=/usr/bin/shasum \
MARKLOOK_DEVID_XCRUN="$stub_bin/xcrun" \
MARKLOOK_DEVID_SPCTL="$stub_bin/spctl" \
MARKLOOK_DEVID_VALIDATE_RELEASE_CANDIDATE="$stub_bin/validate-release-candidate" \
MARKLOOK_DEVID_VALIDATE_ARTIFACT="$stub_bin/validate-artifact" \
  "$packager" --dry-run >"$fixture_root/package-dry-run.out" 2>&1
grep -q '^DRY RUN: Developer ID package lane' "$fixture_root/package-dry-run.out"
grep -q '^No signing or notarization attempted\.' "$fixture_root/package-dry-run.out"
if [ -s "$stub_log" ]; then
  echo "error: package-developer-id --dry-run invoked a release tool" >&2
  cat "$stub_log" >&2
  exit 1
fi
assert_no_fixture_identity_details "$fixture_root/package-dry-run.out"

assert_status 64 "$fixture_root/package-no-developer-id.out" \
  env -u DEVELOPER_ID_APPLICATION "$packager" --developer-id
grep -q 'DEVELOPER_ID_APPLICATION is required' "$fixture_root/package-no-developer-id.out"

assert_status 64 "$fixture_root/package-no-notary-profile.out" \
  env -u NOTARYTOOL_PROFILE \
    DEVELOPER_ID_APPLICATION='Developer ID Application: Example Developer (TEAMTEST01)' \
    "$packager" --developer-id --notarize
grep -q 'NOTARYTOOL_PROFILE is required' "$fixture_root/package-no-notary-profile.out"

assert_status 1 "$fixture_root/validator-missing-artifact.out" \
  "$validator" --signed-only "$fixture_root/missing.app"
grep -q 'artifact not found' "$fixture_root/validator-missing-artifact.out"
assert_no_fixture_identity_details "$fixture_root/validator-missing-artifact.out"

artifact_app="$fixture_root/artifact/MarkLook.app"
mkdir -p \
  "$artifact_app/Contents/PlugIns/MarkLookPreview.appex" \
  "$artifact_app/Contents/PlugIns/MarkLookThumbnail.appex"
entitlements_dir="$fixture_root/entitlements"
mkdir -p "$entitlements_dir"
details_dir="$fixture_root/details"
mkdir -p "$details_dir"

write_app_entitlements() {
  cat >"$entitlements_dir/app.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.files.user-selected.read-only</key><true/>
</dict></plist>
PLIST
}

write_extension_entitlements() {
  local path="$1"
  cat >"$path" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><true/>
</dict></plist>
PLIST
}

write_empty_entitlements() {
  local path="$1"
  cat >"$path" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
PLIST
}

restore_entitlements() {
  write_app_entitlements
  write_extension_entitlements "$entitlements_dir/preview.plist"
  write_extension_entitlements "$entitlements_dir/thumbnail.plist"
}

write_valid_codesign_details() {
  local path="$1"
  cat >"$path" <<'DETAILS'
Authority=Developer ID Application: Fixture Signer (TEAMID1234)
TeamIdentifier=TEAMID1234
Timestamp=Jul 24, 2026 at 12:00:00
flags=0x10000(runtime)
DETAILS
}

restore_codesign_details() {
  write_valid_codesign_details "$details_dir/app.txt"
  write_valid_codesign_details "$details_dir/preview.txt"
  write_valid_codesign_details "$details_dir/thumbnail.txt"
}

remove_secure_timestamp() {
  local path="$1"
  grep -v '^Timestamp=' "$path" >"$path.tmp"
  mv "$path.tmp" "$path"
}

run_validator() {
  env MARKLOOK_DEVID_TEST_LOG="$stub_log" \
    MARKLOOK_DEVID_ENTITLEMENTS_DIR="$entitlements_dir" \
    MARKLOOK_DEVID_DETAILS_DIR="$details_dir" \
    MARKLOOK_DEVID_CODESIGN="$stub_bin/codesign" \
    MARKLOOK_DEVID_VALIDATE_BUILT_BUNDLE="$stub_bin/validate-built-bundle" \
    MARKLOOK_DEVID_VALIDATE_PREVIEW_CONTRACT="$stub_bin/validate-preview-contract" \
    MARKLOOK_DEVID_VALIDATE_THUMBNAIL_BOUNDARIES="$stub_bin/validate-thumbnail-boundaries" \
    "$validator" --signed-only "$artifact_app"
}

restore_entitlements
restore_codesign_details
: >"$stub_log"
assert_status 0 "$fixture_root/validator-valid.out" run_validator
grep -q '^Developer ID artifact OK:' "$fixture_root/validator-valid.out"

remove_secure_timestamp "$details_dir/app.txt"
assert_status 1 "$fixture_root/validator-app-timestamp.out" run_validator
grep -q 'MarkLook.app is missing a secure timestamp' "$fixture_root/validator-app-timestamp.out"

restore_codesign_details
remove_secure_timestamp "$details_dir/preview.txt"
assert_status 1 "$fixture_root/validator-preview-timestamp.out" run_validator
grep -q 'MarkLookPreview.appex is missing a secure timestamp' "$fixture_root/validator-preview-timestamp.out"

restore_codesign_details
remove_secure_timestamp "$details_dir/thumbnail.txt"
assert_status 1 "$fixture_root/validator-thumbnail-timestamp.out" run_validator
grep -q 'MarkLookThumbnail.appex is missing a secure timestamp' "$fixture_root/validator-thumbnail-timestamp.out"

restore_codesign_details
sed 's/TeamIdentifier=TEAMID1234/TeamIdentifier=TEST/' \
  "$details_dir/app.txt" >"$details_dir/app.txt.tmp"
mv "$details_dir/app.txt.tmp" "$details_dir/app.txt"
assert_status 1 "$fixture_root/validator-team-identifier.out" run_validator
grep -q 'MarkLook.app is missing a valid 10-character TeamIdentifier' \
  "$fixture_root/validator-team-identifier.out"

restore_codesign_details
write_empty_entitlements "$entitlements_dir/app.plist"
write_empty_entitlements "$entitlements_dir/preview.plist"
write_empty_entitlements "$entitlements_dir/thumbnail.plist"
assert_status 1 "$fixture_root/validator-empty-entitlements.out" run_validator
grep -q 'MarkLook.app entitlements differ' "$fixture_root/validator-empty-entitlements.out"

restore_entitlements
write_empty_entitlements "$entitlements_dir/preview.plist"
assert_status 1 "$fixture_root/validator-preview-entitlements.out" run_validator
grep -q 'MarkLookPreview.appex entitlements differ' "$fixture_root/validator-preview-entitlements.out"

restore_entitlements
write_empty_entitlements "$entitlements_dir/thumbnail.plist"
assert_status 1 "$fixture_root/validator-thumbnail-entitlements.out" run_validator
grep -q 'MarkLookThumbnail.appex entitlements differ' "$fixture_root/validator-thumbnail-entitlements.out"

restore_entitlements
/usr/libexec/PlistBuddy -c 'Add :com.apple.security.network.client bool true' "$entitlements_dir/thumbnail.plist"
assert_status 1 "$fixture_root/validator-network-entitlement.out" run_validator
grep -q 'MarkLookThumbnail.appex entitlements differ' "$fixture_root/validator-network-entitlement.out"

assert_derived_data_status() {
  local expected_status="$1"
  shift
  local label="$1"
  local value="$2"
  local caller_tmpdir="${3:-${TMPDIR:-/tmp}}"
  local packager_under_test="${4:-$packager}"
  local output_file="$fixture_root/derived-$label.out"
  : >"$stub_log"
  assert_status "$expected_status" "$output_file" \
    env MARKLOOK_DEVID_TEST_LOG="$stub_log" \
      TMPDIR="$caller_tmpdir" \
      MARKLOOK_DEVID_DERIVED_DATA="$value" \
      MARKLOOK_DEVID_XCODEGEN="$stub_bin/xcodegen" \
      MARKLOOK_DEVID_XCODEBUILD="$stub_bin/xcodebuild" \
      MARKLOOK_DEVID_CODESIGN="$stub_bin/codesign" \
      MARKLOOK_DEVID_DITTO=/usr/bin/ditto \
      MARKLOOK_DEVID_SHASUM=/usr/bin/shasum \
      MARKLOOK_DEVID_XCRUN="$stub_bin/xcrun" \
      MARKLOOK_DEVID_SPCTL="$stub_bin/spctl" \
      MARKLOOK_DEVID_VALIDATE_RELEASE_CANDIDATE="$stub_bin/validate-release-candidate" \
      MARKLOOK_DEVID_VALIDATE_ARTIFACT="$stub_bin/validate-artifact" \
      "$packager_under_test" --dry-run
  if [ "$expected_status" -eq 0 ]; then
    grep -q '^DRY RUN: Developer ID package lane' "$output_file"
  else
    grep -q 'unsafe MARKLOOK_DEVID_DERIVED_DATA' "$output_file"
  fi
  if [ -s "$stub_log" ]; then
    echo "error: DerivedData preflight invoked a release tool: $label" >&2
    cat "$stub_log" >&2
    exit 1
  fi
}

assert_unsafe_derived_data() {
  assert_derived_data_status 1 "$@"
}

assert_accepted_derived_data() {
  assert_derived_data_status 0 "$@"
}

assert_unsafe_derived_data filesystem-root /
assert_unsafe_derived_data user-home "$HOME"
assert_unsafe_derived_data repository-root "$repo_root"
assert_unsafe_derived_data repository-build-root "$repo_root/.build"
assert_unsafe_derived_data poisoned-home-tmpdir "$HOME/Documents" "$HOME"
assert_unsafe_derived_data poisoned-repo-tmpdir "$repo_root/Docs" "$repo_root"
assert_unsafe_derived_data repository-parent "$(dirname "$repo_root")"

assert_accepted_derived_data relative-build-child .build/path-policy-characterization/missing
assert_accepted_derived_data nested-missing-child "$fixture_root/missing/nested/Derived Data"
assert_accepted_derived_data normalized-child "$fixture_root/unused/../normalized"
mkdir -p "$fixture_root/allowed target"
ln -s "$fixture_root/allowed target" "$fixture_root/allowed-link"
assert_accepted_derived_data symlink-to-temp "$fixture_root/allowed-link/nested/Derived Data"
ln -s "$repo_root/Docs" "$fixture_root/repository-link"
assert_unsafe_derived_data symlink-to-repository "$fixture_root/repository-link/missing/nested"
ln -s "$HOME" "$fixture_root/home-link"
assert_unsafe_derived_data symlink-to-home "$fixture_root/home-link/missing/nested"
test ! -e "$fixture_root/missing"
test ! -e "$fixture_root/allowed target/nested"

temporary_checkout="$fixture_root/temporary-checkout"
mkdir -p "$temporary_checkout/Scripts" "$temporary_checkout/Docs"
cp "$packager" "$temporary_checkout/Scripts/package-developer-id.sh"
cp "$repo_root/Scripts/release-path-policy.sh" "$temporary_checkout/Scripts/release-path-policy.sh"
chmod +x "$temporary_checkout/Scripts/package-developer-id.sh"
assert_unsafe_derived_data \
  temporary-checkout-root \
  "$temporary_checkout" \
  "${TMPDIR:-/tmp}" \
  "$temporary_checkout/Scripts/package-developer-id.sh"
assert_unsafe_derived_data \
  temporary-checkout-child \
  "$temporary_checkout/Docs" \
  "${TMPDIR:-/tmp}" \
  "$temporary_checkout/Scripts/package-developer-id.sh"

dirty_checkout="$fixture_root/dirty-checkout"
mkdir -p "$dirty_checkout/Scripts" "$dirty_checkout/Docs"
cp "$packager" "$dirty_checkout/Scripts/package-developer-id.sh"
cp "$repo_root/Scripts/release-path-policy.sh" "$dirty_checkout/Scripts/release-path-policy.sh"
chmod +x "$dirty_checkout/Scripts/package-developer-id.sh"
printf 'clean\n' >"$dirty_checkout/Docs/source.txt"
/usr/bin/git -C "$dirty_checkout" init -q
/usr/bin/git -C "$dirty_checkout" add Scripts/package-developer-id.sh Scripts/release-path-policy.sh Docs/source.txt
/usr/bin/git -C "$dirty_checkout" \
  -c user.name='MarkLook Tests' \
  -c user.email='tests@example.invalid' \
  commit -q -m 'fixture'
printf 'dirty\n' >>"$dirty_checkout/Docs/source.txt"
dirty_derived_data="$fixture_root/dirty-derived-data"
mkdir -p "$dirty_derived_data"
touch "$dirty_derived_data/sentinel"
: >"$stub_log"
assert_status 1 "$fixture_root/package-dirty-worktree.out" \
  env MARKLOOK_DEVID_TEST_LOG="$stub_log" \
    MARKLOOK_DEVID_DERIVED_DATA="$dirty_derived_data" \
    MARKLOOK_DEVID_DIST_DIR="$fixture_root/dirty-dist" \
    MARKLOOK_DEVID_XCODEGEN="$stub_bin/xcodegen" \
    MARKLOOK_DEVID_XCODEBUILD="$stub_bin/xcodebuild" \
    MARKLOOK_DEVID_CODESIGN="$stub_bin/codesign" \
    MARKLOOK_DEVID_DITTO=/usr/bin/ditto \
    MARKLOOK_DEVID_SHASUM=/usr/bin/shasum \
    MARKLOOK_DEVID_XCRUN="$stub_bin/xcrun" \
    MARKLOOK_DEVID_SPCTL="$stub_bin/spctl" \
    MARKLOOK_DEVID_VALIDATE_RELEASE_CANDIDATE="$stub_bin/validate-release-candidate" \
    MARKLOOK_DEVID_VALIDATE_ARTIFACT="$stub_bin/validate-artifact" \
    DEVELOPER_ID_APPLICATION='Developer ID Application: Fixture Signer (TEAMTEST01)' \
    "$dirty_checkout/Scripts/package-developer-id.sh" --developer-id
grep -q 'Developer ID packaging requires a clean Git worktree' \
  "$fixture_root/package-dirty-worktree.out"
test -f "$dirty_derived_data/sentinel"
if [ -s "$stub_log" ]; then
  echo "error: dirty worktree invoked a release tool" >&2
  cat "$stub_log" >&2
  exit 1
fi

: >"$stub_log"
absolute_derived_data="$fixture_root/absolute-derived-data"
resolved_absolute_derived_data="$(ruby -e 'puts File.join(File.realpath(File.dirname(ARGV.fetch(0))), File.basename(ARGV.fetch(0)))' "$absolute_derived_data")"
dist_dir="$fixture_root/dist"
assert_status 0 "$fixture_root/package-absolute-derived.out" \
env -i HOME="$HOME" USER="$USER" \
MARKLOOK_DEVID_TEST_LOG="$stub_log" \
MARKLOOK_DEVID_DERIVED_DATA="$absolute_derived_data" \
MARKLOOK_DEVID_DIST_DIR="$dist_dir" \
MARKLOOK_RC_DERIVED_DATA="$fixture_root/poisoned-rc-derived-data" \
MARKLOOK_RC_DIST_DIR="$fixture_root/poisoned-rc-dist" \
MARKLOOK_RC_PROJECT_DUMP="$fixture_root/poisoned-project-dump" \
MARKLOOK_RC_RENDERER_FIXTURE="$fixture_root/poisoned-renderer-fixture" \
MARKLOOK_PACKAGE_XCODEBUILD="$stub_bin/pass" \
MARKLOOK_UNKNOWN_TEST_HOOK=must-not-inherit \
DEVELOPMENT_TEAM=TEAMTEST01 \
NOTARYTOOL_PROFILE=fixture-must-not-inherit \
G1B_CALLER_MARKER=must-not-inherit \
PATH="$stub_bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
TMPDIR="$fixture_root" \
MARKLOOK_DEVID_XCODEGEN="$stub_bin/xcodegen" \
MARKLOOK_DEVID_XCODEBUILD="$stub_bin/xcodebuild" \
MARKLOOK_DEVID_CODESIGN="$stub_bin/codesign" \
MARKLOOK_DEVID_DITTO=/usr/bin/ditto \
MARKLOOK_DEVID_SHASUM=/usr/bin/shasum \
MARKLOOK_DEVID_XCRUN="$stub_bin/xcrun" \
MARKLOOK_DEVID_SPCTL="$stub_bin/spctl" \
MARKLOOK_DEVID_VALIDATE_RELEASE_CANDIDATE="$stub_bin/validate-release-candidate" \
MARKLOOK_DEVID_VALIDATE_ARTIFACT="$stub_bin/validate-artifact" \
DEVELOPER_ID_APPLICATION='Developer ID Application: Fixture Signer (TEAMTEST01)' \
  "$packager" --developer-id

grep -Fq "xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Release -derivedDataPath $resolved_absolute_derived_data" "$stub_log"
grep -q 'OTHER_CODE_SIGN_FLAGS=--timestamp' "$stub_log"
if grep -q '^codesign ' "$stub_log"; then
  echo "error: package lane manually re-signed the Xcode build product" >&2
  cat "$stub_log" >&2
  exit 1
fi

manifest="$(/usr/bin/find "$dist_dir" -name MANIFEST.txt -type f -print -quit)"
test -n "$manifest"
if grep -Eq '/Users/|/home/' "$manifest" || grep -Fq "$fixture_root" "$manifest"; then
  echo "error: Developer ID manifest contains an absolute local path" >&2
  cat "$manifest" >&2
  exit 1
fi
grep -Eq '^Package directory: MarkLook-.+-developer-id-.+$' "$manifest"
grep -Eq '^Package path: MarkLook-.+-developer-id-.+/MarkLook-.+-developer-id-.+\.zip$' "$manifest"

# A clean scratch checkout exercises the real caller and RC consumer without signing.
environment_ascii_checkout="$fixture_root/environment-checkout"
environment_unicode_checkout="$environment_ascii_checkout-$(printf '\344\270\255\346\226\207')"
environment_checkout="$environment_unicode_checkout"
printf '%s\n' "$environment_checkout" >"$fixture_root/environment-checkout-path"
mkdir -p "$environment_checkout/Scripts" "$environment_checkout/MarkLookApp"
for script in package-developer-id.sh release-path-policy.sh validate-release-candidate.sh; do
  cp "$repo_root/Scripts/$script" "$environment_checkout/Scripts/$script"
done
cp "$repo_root/project.yml" "$environment_checkout/project.yml"
cp "$repo_root/MarkLookApp/Info.plist" "$environment_checkout/MarkLookApp/Info.plist"
/usr/bin/git -C "$environment_checkout" init -q
/usr/bin/git -C "$environment_checkout" add .
/usr/bin/git -C "$environment_checkout" -c core.hooksPath=/dev/null \
  -c user.name='MarkLook Tests' -c user.email='tests@example.invalid' \
  commit -q -m 'environment fixture'
cp -R "$environment_unicode_checkout" "$environment_ascii_checkout"

run_environment_packager() {
  local launcher="$1"
  shift
  env "$@" \
    MARKLOOK_DEVID_TEST_LOG="$stub_log" \
    MARKLOOK_DEVID_DERIVED_DATA="$fixture_root/environment-derived" \
    MARKLOOK_DEVID_DIST_DIR="$fixture_root/environment-dist" \
    MARKLOOK_DEVID_XCODEGEN="$stub_bin/xcodegen" \
    MARKLOOK_DEVID_XCODEBUILD="$stub_bin/xcodebuild" \
    MARKLOOK_DEVID_CODESIGN="$stub_bin/codesign" \
    MARKLOOK_DEVID_DITTO=/usr/bin/ditto \
    MARKLOOK_DEVID_SHASUM=/usr/bin/shasum \
    MARKLOOK_DEVID_XCRUN="$stub_bin/xcrun" \
    MARKLOOK_DEVID_SPCTL="$stub_bin/spctl" \
    MARKLOOK_DEVID_VALIDATE_RELEASE_CANDIDATE="$launcher" \
    MARKLOOK_DEVID_VALIDATE_ARTIFACT="$stub_bin/validate-artifact" \
    DEVELOPER_ID_APPLICATION='Developer ID Application: Fixture Signer (TEAMTEST01)' \
    "$environment_checkout/Scripts/package-developer-id.sh" --developer-id
}

environment_sha="$(/usr/bin/git -C "$environment_checkout" rev-parse --short HEAD)"
environment_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$environment_checkout/MarkLookApp/Info.plist")"
environment_output="$fixture_root/environment-dist/MarkLook-$environment_version-developer-id-$environment_sha"
for required in HOME USER; do
  mkdir -p "$fixture_root/environment-derived" "$environment_output"
  printf 'keep\n' >"$fixture_root/environment-derived/sentinel"
  printf 'keep\n' >"$environment_output/sentinel"
  : >"$stub_log"
  assert_status 1 "$fixture_root/environment-missing-$required.out" \
    run_environment_packager "$stub_bin/validate-release-candidate" -u "$required" LC_ALL=en_US.UTF-8
  grep -q 'nested RC environment requires HOME and USER' "$fixture_root/environment-missing-$required.out"
  test ! -s "$stub_log"
  test "$(cat "$fixture_root/environment-derived/sentinel")" = keep
  test "$(cat "$environment_output/sentinel")" = keep
done

cat >"$stub_bin/stop-rc" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
printf 'RC stop\n' >>"$root/stub.log"
exit 97
STUB
cat >"$stub_bin/launch-rc" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
"$root/bin/validate-release-candidate" "$@"
exec /usr/bin/env MARKLOOK_RC_RUBY="$root/bin/stop-rc" \
  MARKLOOK_RC_PLUGINKIT="$root/bin/pass" MARKLOOK_RC_LSREGISTER="$root/bin/pass" \
  MARKLOOK_DEVID_TEST_LOG="$root/stub.log" \
  "$(cat "$root/environment-checkout-path")/Scripts/validate-release-candidate.sh" "$@"
STUB
chmod +x "$stub_bin/stop-rc" "$stub_bin/launch-rc"
for caller_locale in C en_US.UTF-8; do
  if [ "$caller_locale" = C ]; then
    environment_checkout="$environment_ascii_checkout"
  else
    environment_checkout="$environment_unicode_checkout"
  fi
  printf '%s\n' "$environment_checkout" >"$fixture_root/environment-checkout-path"
  : >"$stub_log"
  assert_status 97 "$fixture_root/environment-real-rc-$caller_locale.out" \
    run_environment_packager "$stub_bin/launch-rc" LC_ALL="$caller_locale" \
      MARKLOOK_RC_RUBY="$stub_bin/pass" MARKLOOK_UNKNOWN_TEST_HOOK=must-not-inherit
  test "$(grep -c '^validate-release-candidate --ci$' "$stub_log")" -eq 1
  test "$(grep -c '^RC stop$' "$stub_log")" -eq 1
  if grep -Eq '^(xcodegen|xcodebuild|codesign|xcrun|spctl) ' "$stub_log"; then
    echo "error: a failed nested RC gate continued into release tools" >&2
    cat "$stub_log" >&2
    exit 1
  fi
done

echo "Developer ID release lane tests passed"

#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
doctor="$repo_root/Scripts/doctor-release-identity.sh"
packager="$repo_root/Scripts/package-developer-id.sh"
validator="$repo_root/Scripts/validate-developer-id-artifact.sh"

real_app=""
real_zip=""
if [ "$#" -ne 0 ]; then
  if [ "$#" -ne 3 ] || [ "$1" != --real-artifacts ]; then
    echo "usage: developer-id-release-lane-test.sh [--real-artifacts MarkLook.app package.zip]" >&2
    exit 64
  fi
  real_app="$2"
  real_zip="$3"
  test -d "$real_app"
  test -f "$real_zip"
fi

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
  if [ "$expected_status" -ne 0 ] && grep -q '^Developer ID artifact OK:' "$output_file"; then
    echo "error: failed validation printed success" >&2
    cat "$output_file" >&2
    exit 1
  fi
}

assert_no_fixture_identity_details() {
  local output_file="$1"
  if grep -Eq 'TEAMTEST01|TEAMID1234|Fixture Signer|Other Signer|Example Developer|Local Validation' "$output_file"; then
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
target="${!#}"
case "$(basename "$target")" in
  MarkLook.app) key=app ;;
  MarkLookPreview.appex) key=preview ;;
  MarkLookThumbnail.appex) key=thumbnail ;;
  *) echo "unexpected signature target" >&2; exit 2 ;;
esac
architecture=default
previous=""
for argument in "$@"; do
  if [ "$previous" = --architecture ]; then architecture="$argument"; fi
  previous="$argument"
done
case "${1:-}" in
  --verify)
    if [ -f "$MARKLOOK_DEVID_DETAILS_DIR/$key.verify.status" ]; then
      exit "$(cat "$MARKLOOK_DEVID_DETAILS_DIR/$key.verify.status")"
    fi
    exit 0
    ;;
  -dv)
    if [ -f "$MARKLOOK_DEVID_DETAILS_DIR/$key.$architecture.status" ]; then
      exit "$(cat "$MARKLOOK_DEVID_DETAILS_DIR/$key.$architecture.status")"
    fi
    details="$MARKLOOK_DEVID_DETAILS_DIR/$key.txt"
    if [ -f "$MARKLOOK_DEVID_DETAILS_DIR/$key.$architecture.txt" ]; then
      details="$MARKLOOK_DEVID_DETAILS_DIR/$key.$architecture.txt"
    fi
    cat "$details" >&2
    exit 0
    ;;
  -d)
    if [ "${2:-}" = "--entitlements" ] && [ "${3:-}" = ":-" ]; then
      if [ -f "$MARKLOOK_DEVID_ENTITLEMENTS_DIR/$key.$architecture.status" ]; then
        exit "$(cat "$MARKLOOK_DEVID_ENTITLEMENTS_DIR/$key.$architecture.status")"
      fi
      entitlements="$MARKLOOK_DEVID_ENTITLEMENTS_DIR/$key.plist"
      if [ -f "$MARKLOOK_DEVID_ENTITLEMENTS_DIR/$key.$architecture.plist" ]; then
        entitlements="$MARKLOOK_DEVID_ENTITLEMENTS_DIR/$key.$architecture.plist"
      fi
      cat "$entitlements"
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
for architecture in arm64 x86_64; do
  printf 'int main(void) { return 0; }\n' | /usr/bin/xcrun clang \
    -arch "$architecture" -x c - -o "$fixture_root/$architecture"
done
/usr/bin/lipo -create "$fixture_root/arm64" "$fixture_root/x86_64" -output "$fixture_root/universal"
native_arch="$(/usr/bin/uname -m)"
other_arch=arm64
if [ "$native_arch" = arm64 ]; then other_arch=x86_64; fi
/usr/bin/lipo "$fixture_root/universal" -thin "$native_arch" -output "$fixture_root/thin"

restore_artifact() {
  local binary="${1:-$fixture_root/universal}" bundle executable
  rm -rf "$artifact_app"
  for executable in MarkLook MarkLookPreview MarkLookThumbnail; do
    bundle="$artifact_app"
    if [ "$executable" != MarkLook ]; then bundle="$artifact_app/Contents/PlugIns/$executable.appex"; fi
    mkdir -p "$bundle/Contents/MacOS"
    cp "$binary" "$bundle/Contents/MacOS/$executable"
    chmod 755 "$bundle/Contents/MacOS/$executable"
    cat >"$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>$executable</string></dict></plist>
PLIST
  done
}
restore_artifact
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
Authority=Developer ID Certification Authority
Authority=Apple Root CA
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
    MARKLOOK_DEVID_DITTO=/usr/bin/ditto \
    MARKLOOK_DEVID_XCRUN="$stub_bin/xcrun" \
    MARKLOOK_DEVID_SPCTL="$stub_bin/spctl" \
    MARKLOOK_DEVID_VALIDATE_BUILT_BUNDLE="${built_bundle_check:-$stub_bin/validate-built-bundle}" \
    MARKLOOK_DEVID_VALIDATE_PREVIEW_CONTRACT="${preview_contract_check:-$stub_bin/validate-preview-contract}" \
    MARKLOOK_DEVID_VALIDATE_THUMBNAIL_BOUNDARIES="${thumbnail_boundaries_check:-$stub_bin/validate-thumbnail-boundaries}" \
    "$validator" "${1:---signed-only}" "${2:-$artifact_app}"
}

restore_entitlements
restore_codesign_details
: >"$stub_log"
assert_status 0 "$fixture_root/validator-valid.out" run_validator
grep -q '^Developer ID artifact OK:' "$fixture_root/validator-valid.out"

# Aggregate new causal negatives so the unchanged parent exposes both families.
closure_cases=0
closure_failures=0
assert_closure_rejected() {
  local name="$1" stage="$2" expected="${3:-1}" artifact="${4:-$artifact_app}" status output
  output="$fixture_root/closure-$name.out"
  : >"$stub_log"
  set +e
  run_validator --notarized "$artifact" >"$output" 2>&1
  status="$?"
  set -e
  closure_cases=$((closure_cases + 1))
  if [ "$status" -ne "$expected" ] || grep -q '^Developer ID artifact OK:' "$output" || \
      grep -Eq '^(xcrun|spctl) ' "$stub_log" || \
      { [ "$stage" = structural ] && grep -q '^codesign ' "$stub_log"; } || \
      grep -Eq 'TEAMID1234|TEAMTEST01|Fixture Signer|Other Signer' "$output"; then
    echo "error: closure $name expected $expected before $stage hooks, got $status" >&2
    cat "$output" "$stub_log" >&2
    closure_failures=$((closure_failures + 1))
  else
    echo "closure rejection: $name (exit $status, $stage ordering)"
  fi
}

for key in preview thumbnail; do
  restore_codesign_details
  sed 's/TEAMID1234/TEAMTEST01/g' "$details_dir/$key.txt" >"$details_dir/$key.tmp"
  mv "$details_dir/$key.tmp" "$details_dir/$key.txt"
  assert_closure_rejected "$key-other-team" identity
  restore_codesign_details
  sed 's/Fixture Signer/Other Signer/' "$details_dir/$key.txt" >"$details_dir/$key.tmp"
  mv "$details_dir/$key.tmp" "$details_dir/$key.txt"
  assert_closure_rejected "$key-same-team-other-leaf" identity
done
restore_codesign_details
for defect in duplicate-team duplicate-leaf leaf-team-mismatch; do
  restore_codesign_details
  case "$defect" in
    duplicate-team) printf 'TeamIdentifier=TEAMID1234\n' >>"$details_dir/app.txt" ;;
    duplicate-leaf) printf 'Authority=Developer ID Application: Fixture Signer (TEAMID1234)\n' >>"$details_dir/app.txt" ;;
    leaf-team-mismatch)
      sed 's/(TEAMID1234)/(TEAMTEST01)/' "$details_dir/app.txt" >"$details_dir/app.tmp"
      mv "$details_dir/app.tmp" "$details_dir/app.txt"
      ;;
  esac
  assert_closure_rejected "$defect" identity
done
restore_codesign_details

for key in app preview thumbnail; do
  for defect in team leaf misplaced-authority timestamp runtime entitlements details-status entitlement-status; do
    write_valid_codesign_details "$details_dir/$key.$other_arch.txt"
    case "$defect" in
      team) sed 's/TEAMID1234/TEAMTEST01/g' "$details_dir/$key.$other_arch.txt" >"$details_dir/modified" ;;
      leaf) sed 's/Fixture Signer/Other Signer/' "$details_dir/$key.$other_arch.txt" >"$details_dir/modified" ;;
      misplaced-authority)
        printf 'Authority=Apple Development: Other Signer (TEAMID1234)\n' >"$details_dir/modified"
        cat "$details_dir/$key.$other_arch.txt" >>"$details_dir/modified"
        ;;
      timestamp) grep -v '^Timestamp=' "$details_dir/$key.$other_arch.txt" >"$details_dir/modified" ;;
      runtime) grep -v '^flags=' "$details_dir/$key.$other_arch.txt" >"$details_dir/modified" ;;
      entitlements) write_empty_entitlements "$entitlements_dir/$key.$other_arch.plist" ;;
      details-status) printf '73\n' >"$details_dir/$key.$other_arch.status" ;;
      entitlement-status) printf '74\n' >"$entitlements_dir/$key.$other_arch.status" ;;
    esac
    if [ -f "$details_dir/modified" ]; then mv "$details_dir/modified" "$details_dir/$key.$other_arch.txt"; fi
    expected=1
    if [ "$defect" = details-status ]; then expected=73; fi
    if [ "$defect" = entitlement-status ]; then expected=74; fi
    assert_closure_rejected "$key-$other_arch-$defect" identity "$expected"
    rm -f "$details_dir/$key.$other_arch.txt" "$details_dir/$key.$other_arch.status" \
      "$entitlements_dir/$key.$other_arch.plist" "$entitlements_dir/$key.$other_arch.status"
  done
  printf '75\n' >"$details_dir/$key.verify.status"
  assert_closure_rejected "$key-verify-status" identity 75
  rm "$details_dir/$key.verify.status"
done

for defect in missing renamed malformed plist-name plist-invalid unreadable symlink fifo \
  extra-native resource-native dot-native script app appex xpc framework loginbundle; do
  restore_artifact
  executable="$artifact_app/Contents/MacOS/MarkLook"
  case "$defect" in
    missing) rm "$executable" ;;
    renamed) mv "$executable" "$executable-renamed" ;;
    malformed) printf '\317\372\355\376broken' >"$executable" ;;
    plist-name) /usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Wrong' "$artifact_app/Contents/Info.plist" ;;
    plist-invalid) printf 'not a plist\n' >"$artifact_app/Contents/Info.plist" ;;
    unreadable) chmod 000 "$artifact_app/Contents/Info.plist" ;;
    symlink) ln -s "$fixture_root/thin" "$artifact_app/Contents/linked" ;;
    fifo) mkfifo "$artifact_app/Contents/pipe" ;;
    extra-native) cp "$fixture_root/thin" "$artifact_app/Contents/extra" ;;
    resource-native|dot-native)
      mkdir -p "$artifact_app/Contents/Resources"
      name=extra.dat
      if [ "$defect" = dot-native ]; then name=._extra.dat; fi
      cp "$fixture_root/thin" "$artifact_app/Contents/Resources/$name"
      chmod 644 "$artifact_app/Contents/Resources/$name"
      ;;
    script) printf '#!/bin/sh\nexit 0\n' >"$artifact_app/Contents/helper"; chmod 755 "$artifact_app/Contents/helper" ;;
    app|appex|xpc|framework|loginbundle) mkdir "$artifact_app/Contents/Extra.$defect" ;;
  esac
  assert_closure_rejected "$defect" structural
done
restore_artifact
for defect in empty-architectures malformed-architectures duplicate-architectures; do
  ruby - "$fixture_root/thin" "$artifact_app/Contents/MacOS/MarkLook" "$defect" <<'RUBY'
source, output, defect = ARGV
bytes = File.binread(source)
case defect
when 'empty-architectures'
  bytes = [0xcafebabe, 0].pack('N2')
when 'malformed-architectures'
  bytes[4, 4] = [0x12345678].pack('V')
when 'duplicate-architectures'
  cpu, subtype = bytes[4, 8].unpack('V2')
  first = 4096
  second = ((first + bytes.bytesize + 4095) / 4096) * 4096
  header = [0xcafebabe, 2, cpu, subtype, first, bytes.bytesize, 12,
            cpu, subtype, second, bytes.bytesize, 12].pack('N*')
  bytes = header.ljust(first, "\0") + bytes + "\0" * (second - first - bytes.bytesize) + bytes
end
File.binwrite(output, bytes)
RUBY
  assert_closure_rejected "$defect" structural
  restore_artifact
done
mkdir -p "$fixture_root/zip-siblings"
/usr/bin/ditto "$artifact_app" "$fixture_root/zip-siblings/MarkLook.app"
printf 'sibling\n' >"$fixture_root/zip-siblings/extra.txt"
/usr/bin/ditto -c -k "$fixture_root/zip-siblings" "$fixture_root/siblings.zip"
assert_closure_rejected zip-siblings structural 1 "$fixture_root/siblings.zip"

echo "closure negatives: $closure_cases cases, $closure_failures failures"
if [ "$closure_failures" -ne 0 ]; then exit 1; fi

for binary in "$fixture_root/thin" "$fixture_root/universal"; do
  restore_artifact "$binary"
  : >"$stub_log"
  assert_status 0 "$fixture_root/validator-positive.out" run_validator --notarized
  architectures="$(/usr/bin/lipo -archs "$binary")"
  for architecture in $architectures; do
    test "$(grep -c "^codesign -dv .*--architecture $architecture " "$stub_log")" -eq 3
    test "$(grep -c "^codesign -d .*--architecture $architecture " "$stub_log")" -eq 3
  done
  test "$(grep -c '^codesign --verify --deep --strict' "$stub_log")" -eq 3
  test "$(grep -c '^xcrun stapler validate' "$stub_log")" -eq 1
  test "$(grep -c '^spctl --assess' "$stub_log")" -eq 1
done
restore_artifact

if [ -n "$real_app" ]; then
  built_bundle_check="$repo_root/Scripts/validate-built-bundle.sh"
  preview_contract_check="$repo_root/Scripts/validate-quicklook-preview-contract.sh"
  thumbnail_boundaries_check="$repo_root/Scripts/validate-thumbnail-boundaries.sh"
  for artifact in "$real_app" "$real_zip"; do
    assert_status 0 "$fixture_root/validator-real.out" run_validator --notarized "$artifact"
    grep -q '^Developer ID artifact OK:' "$fixture_root/validator-real.out"
    assert_no_fixture_identity_details "$fixture_root/validator-real.out"
    echo "real Release inventory accepted with synthetic signatures: $(basename "$artifact")"
  done
  assert_status 1 "$fixture_root/validator-real-unsigned.out" \
    env MARKLOOK_DEVID_CODESIGN=/usr/bin/codesign "$validator" --signed-only "$real_app"
  assert_no_fixture_identity_details "$fixture_root/validator-real-unsigned.out"
  echo "real unsigned Release artifact refused by real codesign"
  unset built_bundle_check preview_contract_check thumbnail_boundaries_check
fi

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

# Keep the packaging positive independent of the construction worktree's dirtiness.
mkdir -p "$temporary_checkout/MarkLookApp"
cp "$repo_root/MarkLookApp/Info.plist" "$temporary_checkout/MarkLookApp/Info.plist"
printf '.build/\ndist/\n' >"$temporary_checkout/.gitignore"
/usr/bin/git -C "$temporary_checkout" init -q
/usr/bin/git -C "$temporary_checkout" add .
/usr/bin/git -C "$temporary_checkout" -c core.hooksPath=/dev/null \
  -c user.name='MarkLook Tests' -c user.email='tests@example.invalid' \
  commit -q -m 'packaging fixture'

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
  "$temporary_checkout/Scripts/package-developer-id.sh" --developer-id

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

output_guard="$fixture_root/output-admission"
mutation_log="$fixture_root/output-mutations.log"
output_packager="$temporary_checkout/Scripts/package-developer-id.sh"
output_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$temporary_checkout/MarkLookApp/Info.plist")"
output_sha="$(/usr/bin/git -C "$temporary_checkout" rev-parse --short HEAD)"
output_stem="MarkLook-$output_version-developer-id-$output_sha"
mkdir -p "$output_guard/derived" "$output_guard/dist" "$output_guard/escaped" \
  "$output_guard/linked-dist" "$output_guard/inside-dist/target" \
  "$temporary_checkout/dist/$output_stem"
sentinels=("$output_guard/derived/sentinel" "$output_guard/dist/sentinel" \
  "$output_guard/escaped/sentinel" "$temporary_checkout/dist/$output_stem/sentinel")
for sentinel in "${sentinels[@]}"; do printf 'keep\n' >"$sentinel"; done
ln -s "$HOME" "$output_guard/missing-parent-link"
ln -s "$output_guard/escaped" "$output_guard/linked-dist/$output_stem"
ln -s "$output_guard/inside-dist/target" "$output_guard/inside-dist/$output_stem"

# These nonmutating spies exist only in denied packager subprocesses. Setup and
# cleanup use the ordinary commands, and real positives use owned fixture paths.
cat >"$fixture_root/output-spy.bash" <<'SPY'
rm() {
  if [ "${BASH_SOURCE[1]:-}" = "$MARKLOOK_DEVID_TEST_PACKAGER" ]; then
    printf 'rm %s\n' "$*" >>"$MARKLOOK_DEVID_TEST_MUTATIONS"
    return 97
  fi
  command rm "$@"
}
mkdir() {
  if [ "${BASH_SOURCE[1]:-}" = "$MARKLOOK_DEVID_TEST_PACKAGER" ]; then
    printf 'mkdir %s\n' "$*" >>"$MARKLOOK_DEVID_TEST_MUTATIONS"
    return 97
  fi
  command mkdir "$@"
}
SPY

run_output_packager() {
  local mode="$1"
  shift
  env -u MARKLOOK_DEVID_DIST_DIR \
    BASH_ENV="$fixture_root/output-spy.bash" \
    MARKLOOK_DEVID_TEST_PACKAGER="$output_packager" \
    MARKLOOK_DEVID_TEST_MUTATIONS="$mutation_log" \
    MARKLOOK_DEVID_TEST_LOG="$stub_log" \
    MARKLOOK_DEVID_DERIVED_DATA="$output_guard/derived" \
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
    "$@" "$output_packager" "$mode"
}

output_cases=0
output_failures=0
assert_output_denied() {
  local label="$1" mode output status sentinel sentinel_changed
  shift
  for mode in --dry-run --developer-id; do
    output="$fixture_root/output-$label-$mode.out"
    : >"$mutation_log"
    : >"$stub_log"
    set +e
    run_output_packager "$mode" "$@" >"$output" 2>&1
    status="$?"
    set -e
    sentinel_changed=0
    for sentinel in "${sentinels[@]}"; do
      if [ ! -f "$sentinel" ] || [ "$(cat "$sentinel")" != keep ]; then sentinel_changed=1; fi
    done
    output_cases=$((output_cases + 1))
    if [ "$status" -ne 1 ] || [ -s "$mutation_log" ] || [ -s "$stub_log" ] || \
        [ "$sentinel_changed" -ne 0 ] || ! grep -q '^error: unsafe ' "$output"; then
      echo "error: output admission $label $mode expected refusal before mutations/tools, got $status" >&2
      cat "$output" "$mutation_log" "$stub_log" >&2
      output_failures=$((output_failures + 1))
    else
      echo "output admission rejection: $label $mode (no mutations/tools, sentinels intact)"
    fi
  done
}

assert_output_denied empty MARKLOOK_DEVID_DIST_DIR=
assert_output_denied filesystem-root MARKLOOK_DEVID_DIST_DIR=/
assert_output_denied home MARKLOOK_DEVID_DIST_DIR="$HOME"
assert_output_denied repository MARKLOOK_DEVID_DIST_DIR="$temporary_checkout"
assert_output_denied ancestor MARKLOOK_DEVID_DIST_DIR="$fixture_root"
assert_output_denied file MARKLOOK_DEVID_DIST_DIR="$output_guard/dist/sentinel"
assert_output_denied system-temp-root MARKLOOK_DEVID_DIST_DIR="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)"
assert_output_denied private-tmp-root MARKLOOK_DEVID_DIST_DIR=/private/tmp
assert_output_denied poisoned-home TMPDIR="$HOME" MARKLOOK_DEVID_DIST_DIR="$HOME/Documents/new-developer-id-dist"
assert_output_denied poisoned-repository TMPDIR="$temporary_checkout" MARKLOOK_DEVID_DIST_DIR="$temporary_checkout/Docs/new-dist"
assert_output_denied missing-parent-escape MARKLOOK_DEVID_DIST_DIR="$output_guard/missing-parent-link/missing/dist"
assert_output_denied linked-child-outside MARKLOOK_DEVID_DIST_DIR="$output_guard/linked-dist"
assert_output_denied linked-child-inside MARKLOOK_DEVID_DIST_DIR="$output_guard/inside-dist"
assert_output_denied output-contains-derived MARKLOOK_DEVID_DIST_DIR="$output_guard/dist" \
  MARKLOOK_DEVID_DERIVED_DATA="$output_guard/dist/$output_stem/DerivedData"
assert_output_denied derived-contains-output MARKLOOK_DEVID_DIST_DIR="$output_guard/dist" \
  MARKLOOK_DEVID_DERIVED_DATA="$output_guard/dist"
assert_output_denied equal-output-derived MARKLOOK_DEVID_DIST_DIR="$output_guard/dist" \
  MARKLOOK_DEVID_DERIVED_DATA="$output_guard/dist/$output_stem"
echo "output admission negatives: $output_cases cases, $output_failures failures"
if [ "$output_failures" -ne 0 ]; then exit 1; fi

resolved_output_guard="$(cd "$output_guard" && pwd -P)"
resolved_checkout="$(cd "$temporary_checkout" && pwd -P)"
output_positives=0
assert_output_accepted() {
  local label="$1" expected_dist="$2" mode output spy_file
  shift 2
  for mode in --dry-run --developer-id; do
    output="$fixture_root/output-positive-$label-$mode.out"
    : >"$mutation_log"
    : >"$stub_log"
    spy_file="$fixture_root/output-spy.bash"
    if [ "$mode" = --developer-id ]; then spy_file=""; fi
    assert_status 0 "$output" run_output_packager "$mode" BASH_ENV="$spy_file" LC_ALL=C "$@"
    test ! -s "$mutation_log"
    if [ "$mode" = --dry-run ]; then
      grep -q '^DRY RUN: Developer ID package lane' "$output"
      test ! -s "$stub_log"
    else
      grep -Fxq "Package directory: $expected_dist/$output_stem" "$output"
      test -f "$expected_dist/$output_stem/$output_stem.zip"
      test -f "$expected_dist/$output_stem/$output_stem.zip.sha256"
      test -f "$expected_dist/$output_stem/MANIFEST.txt"
      grep -Fq -- "-derivedDataPath $resolved_output_guard/derived" "$stub_log"
      test "$(grep -c '^validate-release-candidate --ci$' "$stub_log")" -eq 1
    fi
    assert_no_fixture_identity_details "$output"
    output_positives=$((output_positives + 1))
    echo "output admission positive: $label $mode (caller LC_ALL=C)"
  done
}

assert_output_accepted unset-default "$resolved_checkout/dist"
assert_output_accepted absolute "$resolved_output_guard/absolute" MARKLOOK_DEVID_DIST_DIR="$output_guard/absolute"
assert_output_accepted nested-missing "$resolved_output_guard/missing/deep/dist" \
  MARKLOOK_DEVID_DIST_DIR="$output_guard/missing/deep/dist"
assert_output_accepted relative "$resolved_checkout/dist/output-path-fixture" MARKLOOK_DEVID_DIST_DIR=dist/output-path-fixture
unicode_dist="dist-$(printf '\344\270\255\346\226\207')"
assert_output_accepted unicode "$resolved_output_guard/$unicode_dist" MARKLOOK_DEVID_DIST_DIR="$output_guard/$unicode_dist"
ln -s "$output_guard/absolute" "$output_guard/allowed-dist-link"
assert_output_accepted linked-dist "$resolved_output_guard/absolute" MARKLOOK_DEVID_DIST_DIR="$output_guard/allowed-dist-link"
echo "output admission positives: $output_positives cases"

echo "Developer ID release lane tests passed"

#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
gate="${MARKLOOK_RC_GATE:-$repo_root/Scripts/validate-release-candidate.sh}"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

assert_exit_64() {
  local output_file="$1"
  shift
  set +e
  "$@" >"$output_file" 2>&1
  local command_status="$?"
  set -e
  if [ "$command_status" -ne 64 ]; then
    echo "error: expected exit 64, got $command_status for: $*" >&2
    cat "$output_file" >&2
    exit 1
  fi
  grep -q 'usage:' "$output_file"
}

assert_exit_64 "$fixture_root/no-mode.out" "$gate"
assert_exit_64 "$fixture_root/unknown-mode.out" "$gate" --bogus
assert_exit_64 "$fixture_root/no-team.out" env -u DEVELOPMENT_TEAM "$gate" --local

stub_bin="$fixture_root/bin"
stub_log="$fixture_root/stub.log"
dist_dir="$fixture_root/dist"
mkdir -p "$stub_bin"
touch "$stub_log"

cat >"$stub_bin/pass" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >>"$MARKLOOK_RC_TEST_LOG"
STUB

cat >"$stub_bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'xcodebuild %s\n' "$*" >>"$MARKLOOK_RC_TEST_LOG"
derived=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -derivedDataPath)
      shift
      derived="$1"
      ;;
  esac
  shift || true
done
if [ -z "$derived" ]; then
  echo "missing derived data path" >&2
  exit 1
fi
mkdir -p "$derived/Build/Products/Debug/MarkLook.app"
for bundle in MarkLookAppTests MarkLookPreviewTests MarkLookThumbnailTests; do
  mkdir -p "$derived/Build/Products/Debug/$bundle.xctest/Contents/MacOS"
  cat >"$derived/Build/Products/Debug/$bundle.xctest/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$bundle</string>
</dict></plist>
PLIST
  touch "$derived/Build/Products/Debug/$bundle.xctest/Contents/MacOS/$bundle"
  chmod +x "$derived/Build/Products/Debug/$bundle.xctest/Contents/MacOS/$bundle"
done
STUB

cat >"$stub_bin/xcrun" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'xcrun %s\n' "$*" >>"$MARKLOOK_RC_TEST_LOG"
STUB

cat >"$stub_bin/package-debug" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'package-debug %s\n' "$*" >>"$MARKLOOK_RC_TEST_LOG"
short_sha="$(git rev-parse --short HEAD)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' MarkLookApp/Info.plist)"
artifact_stem="MarkLook-$version-debug-$short_sha"
output_dir="$MARKLOOK_PACKAGE_DIST_DIR/$artifact_stem"
mkdir -p "$output_dir"
echo "zip" >"$output_dir/$artifact_stem.zip"
shasum -a 256 "$output_dir/$artifact_stem.zip" >"$output_dir/$artifact_stem.zip.sha256"
cat >"$output_dir/MANIFEST.txt" <<MANIFEST
Build mode: unsigned-ci
MANIFEST
STUB

cat >"$stub_bin/validate-package-artifact" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'validate-package-artifact %s\n' "$*" >>"$MARKLOOK_RC_TEST_LOG"
test -f "$1"
STUB

cat >"$stub_bin/swift" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'swift %s\n' "$*" >>"$MARKLOOK_RC_TEST_LOG"
if [ -n "${MARKLOOK_RENDERER_SECURITY_FIXTURE:-}" ]; then
  echo '<html></html>' >"$MARKLOOK_RENDERER_SECURITY_FIXTURE"
fi
STUB

chmod +x "$stub_bin"/*

# Stop at the first release tool even when exercising the unfixed parent. The
# refusal must precede both this tool and the EXIT registration cleanup.
cat >"$stub_bin/stop" <<'STUB'
#!/usr/bin/env bash
printf 'unexpected release tool\n' >>"$MARKLOOK_RC_TEST_LOG"
exit 97
STUB
chmod +x "$stub_bin/stop"

guard_root="$fixture_root/admission"
mkdir -p "$guard_root/derived" "$guard_root/dist"
printf 'keep\n' >"$guard_root/derived/sentinel"
printf 'keep\n' >"$guard_root/dist/sentinel"
probe_gate="$gate"
assert_rejected_before_tools() {
  local name="$1" result
  shift
  : >"$stub_log"
  set +e
  env MARKLOOK_RC_TEST_LOG="$stub_log" \
    MARKLOOK_RC_RUBY="$stub_bin/stop" \
    MARKLOOK_RC_PLUGINKIT="$stub_bin/pass" \
    MARKLOOK_RC_LSREGISTER="$stub_bin/pass" \
    MARKLOOK_RC_DERIVED_DATA="$guard_root/derived" \
    MARKLOOK_RC_DIST_DIR="$guard_root/dist" \
    MARKLOOK_RC_PROJECT_DUMP="$guard_root/uncreated/project.yml" \
    MARKLOOK_RC_RENDERER_FIXTURE="$guard_root/uncreated/renderer.html" \
    "$@" "$probe_gate" --ci >"$fixture_root/$name.out" 2>&1
  result="$?"
  set -e
  if [ "$result" -ne 1 ] || ! grep -q 'error: unsafe' "$fixture_root/$name.out" || [ -s "$stub_log" ]; then
    echo "error: $name did not fail before release tools/cleanup (exit $result)" >&2
    cat "$fixture_root/$name.out" "$stub_log" >&2
    exit 1
  fi
  test ! -e "$guard_root/uncreated"
  test "$(cat "$guard_root/derived/sentinel")" = keep
  test "$(cat "$guard_root/dist/sentinel")" = keep
}

assert_rejected_before_tools derived-root MARKLOOK_RC_DERIVED_DATA=/
assert_rejected_before_tools derived-repo MARKLOOK_RC_DERIVED_DATA="$repo_root"
assert_rejected_before_tools derived-ancestor MARKLOOK_RC_DERIVED_DATA="$(dirname "$repo_root")"
assert_rejected_before_tools derived-build-root MARKLOOK_RC_DERIVED_DATA="$repo_root/.build"
assert_rejected_before_tools derived-home MARKLOOK_RC_DERIVED_DATA="$HOME"
assert_rejected_before_tools poisoned-tmp-home TMPDIR="$HOME" MARKLOOK_RC_DERIVED_DATA="$HOME/Documents"
assert_rejected_before_tools poisoned-tmp-repo TMPDIR="$repo_root" MARKLOOK_RC_DERIVED_DATA="$repo_root/Docs"
assert_rejected_before_tools derived-temp-root MARKLOOK_RC_DERIVED_DATA="$(getconf DARWIN_USER_TEMP_DIR)"
assert_rejected_before_tools derived-private-tmp MARKLOOK_RC_DERIVED_DATA=/private/tmp
assert_rejected_before_tools dist-repo MARKLOOK_RC_DIST_DIR="$repo_root"
assert_rejected_before_tools dist-build MARKLOOK_RC_DIST_DIR="$repo_root/.build/dist"
assert_rejected_before_tools dist-private-tmp MARKLOOK_RC_DIST_DIR=/private/tmp
assert_rejected_before_tools project-source MARKLOOK_RC_PROJECT_DUMP="$repo_root/project.yml"
assert_rejected_before_tools renderer-source MARKLOOK_RC_RENDERER_FIXTURE="$repo_root/README.md"
assert_rejected_before_tools project-directory MARKLOOK_RC_PROJECT_DUMP="$guard_root"
assert_rejected_before_tools output-missing-parent MARKLOOK_RC_PROJECT_DUMP="$guard_root/derived/sentinel/missing.yml"
assert_rejected_before_tools derived-file MARKLOOK_RC_DERIVED_DATA="$guard_root/derived/sentinel"
assert_rejected_before_tools dist-file MARKLOOK_RC_DIST_DIR="$guard_root/dist/sentinel"
assert_rejected_before_tools overlap-directories MARKLOOK_RC_DIST_DIR="$guard_root/derived/nested"
assert_rejected_before_tools output-in-derived MARKLOOK_RC_PROJECT_DUMP="$guard_root/derived/project.yml"
assert_rejected_before_tools output-in-dist MARKLOOK_RC_RENDERER_FIXTURE="$guard_root/dist/renderer.html"
assert_rejected_before_tools outputs-equal MARKLOOK_RC_PROJECT_DUMP="$guard_root/uncreated/renderer.html"
assert_rejected_before_tools outputs-case-alias MARKLOOK_RC_PROJECT_DUMP="$guard_root/uncreated/RENDERER.html"
assert_rejected_before_tools install-root MARKLOOK_RC_INSTALL_APP=/Applications
assert_rejected_before_tools install-temporary MARKLOOK_RC_INSTALL_APP="$fixture_root/MarkLook.app"
for key in DERIVED_DATA DIST_DIR PROJECT_DUMP RENDERER_FIXTURE INSTALL_APP; do
  assert_rejected_before_tools "empty-$key" "MARKLOOK_RC_$key="
done

ln -s "$repo_root/Docs" "$guard_root/source-link"
ln -s "$guard_root/derived/sentinel" "$guard_root/output-link"
ln "$guard_root/dist/sentinel" "$guard_root/hardlink"
mkfifo "$guard_root/fifo"
for key in DERIVED_DATA DIST_DIR PROJECT_DUMP RENDERER_FIXTURE; do
  assert_rejected_before_tools "escape-$key" "MARKLOOK_RC_$key=$guard_root/source-link/missing/target"
done
assert_rejected_before_tools output-link MARKLOOK_RC_PROJECT_DUMP="$guard_root/output-link"
assert_rejected_before_tools output-hardlink MARKLOOK_RC_RENDERER_FIXTURE="$guard_root/hardlink"
assert_rejected_before_tools output-fifo MARKLOOK_RC_PROJECT_DUMP="$guard_root/fifo"

# A temporary checkout must not become deletable merely because it is in /tmp.
temporary_repo="$fixture_root/temporary-repo"
mkdir -p "$temporary_repo/Scripts" "$temporary_repo/MarkLookApp" "$temporary_repo/.build/ReleaseCandidateReports"
cp "$repo_root/Scripts/validate-release-candidate.sh" "$repo_root/Scripts/release-path-policy.sh" "$temporary_repo/Scripts/"
cp "$repo_root/MarkLookApp/Info.plist" "$temporary_repo/MarkLookApp/"
cp "$repo_root/project.yml" "$temporary_repo/"
/usr/bin/git -C "$temporary_repo" init -q
/usr/bin/git -C "$temporary_repo" -c user.name='MarkLook Tests' -c user.email='tests@example.invalid' \
  -c core.hooksPath=/dev/null commit --allow-empty -qm fixture
probe_gate="$temporary_repo/Scripts/validate-release-candidate.sh"
assert_rejected_before_tools temporary-repo-root MARKLOOK_RC_DERIVED_DATA="$temporary_repo"
assert_rejected_before_tools temporary-repo-case-alias MARKLOOK_RC_DERIVED_DATA="$fixture_root/TEMPORARY-REPO"
assert_rejected_before_tools temporary-repo-source MARKLOOK_RC_DIST_DIR="$temporary_repo/MarkLookApp"
assert_rejected_before_tools internal-log-overlap MARKLOOK_RC_DERIVED_DATA="$temporary_repo/.build/ReleaseCandidateReports"

# The input has no newline, but realpath follows a link to a multiline name.
# Command substitution must never turn an admitted child into its parent.
source "$repo_root/Scripts/release-path-policy.sh"
printf 'keep\n' >"$temporary_repo/.build/sentinel"
for control_name in lf cr; do
  case "$control_name" in
    lf) control=$'\n' ;;
    cr) control=$'\r' ;;
  esac
  multiline_dir="$temporary_repo/.build/$control"
  mkdir -p "$multiline_dir"
  resolved_alias="$temporary_repo/resolved-$control_name"
  ln -s "$multiline_dir" "$resolved_alias"
  assert_rejected_before_tools "resolved-derived-$control_name" MARKLOOK_RC_DERIVED_DATA="$resolved_alias"
  assert_rejected_before_tools "resolved-output-$control_name" MARKLOOK_RC_PROJECT_DUMP="$resolved_alias/missing/report.yml"

  set +e
  canonicalize_disposable_derived_data "$resolved_alias" "$temporary_repo" /usr/bin/ruby /usr/bin/getconf \
    >"$fixture_root/resolved-$control_name.stdout" 2>"$fixture_root/resolved-$control_name.stderr"
  helper_status="$?"
  set -e
  test "$helper_status" -eq 1
  test ! -s "$fixture_root/resolved-$control_name.stdout"
  grep -q 'multiline resolved path' "$fixture_root/resolved-$control_name.stderr"
  test ! -e "$multiline_dir/missing"
  test "$(cat "$temporary_repo/.build/sentinel")" = keep
done

ln -s "$guard_root/derived/sentinel" "$temporary_repo/.build/ReleaseCandidateReports/MarkLookAppTests-xctest.log"
assert_rejected_before_tools internal-log-link
probe_gate="$gate"

expected_id="$(/usr/bin/ruby -ryaml -e 'puts YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false).fetch("targets").fetch("MarkLook").fetch("settings").fetch("base").fetch("PRODUCT_BUNDLE_IDENTIFIER")' "$repo_root/project.yml")"
test_app="$fixture_root/identity/MarkLook.app"
validate_installed_app_identity "$test_app" "$expected_id"
mkdir -p "$test_app/Contents"
cp "$repo_root/MarkLookApp/Info.plist" "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $expected_id" "$test_app/Contents/Info.plist"
validate_installed_app_identity "$test_app" "$expected_id"
assert_bad_identity() {
  if validate_installed_app_identity "$1" "$expected_id" >"$fixture_root/identity.out" 2>&1; then
    echo 'error: invalid installed bundle identity accepted' >&2
    exit 1
  fi
  grep -q 'unsafe installed app identity' "$fixture_root/identity.out"
}
ln -s "$test_app" "$fixture_root/identity-link.app"
assert_bad_identity "$fixture_root/identity-link.app"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.example.unrelated' "$test_app/Contents/Info.plist"
assert_bad_identity "$test_app"
printf 'broken plist\n' >"$test_app/Contents/Info.plist"
assert_bad_identity "$test_app"
mkdir -p "$fixture_root/missing-plist.app/Contents"
assert_bad_identity "$fixture_root/missing-plist.app"
mkdir -p "$fixture_root/linked-plist.app/Contents"
ln -s "$repo_root/MarkLookApp/Info.plist" "$fixture_root/linked-plist.app/Contents/Info.plist"
assert_bad_identity "$fixture_root/linked-plist.app"

# Positive admission uses the same helper and original G0 entrypoint, with no IO.
resolved_fixture="$(cd "$fixture_root" && pwd -P)"
test "$(canonicalize_release_path dist TEST dist "$repo_root")" = "$repo_root/dist"
test "$(canonicalize_release_path output TEST '.build/missing reports/deep/file.yml' "$repo_root")" = "$repo_root/.build/missing reports/deep/file.yml"
test "$(canonicalize_disposable_derived_data "$fixture_root/missing derived/deep" "$repo_root" /usr/bin/ruby /usr/bin/getconf)" = "$resolved_fixture/missing derived/deep"
test ! -e "$fixture_root/missing derived"
test ! -e "$repo_root/.build/missing reports"
: >"$stub_log"

MARKLOOK_RC_TEST_LOG="$stub_log" \
MARKLOOK_RC_RUBY="$stub_bin/pass" \
MARKLOOK_RC_XCODEGEN="$stub_bin/pass" \
MARKLOOK_RC_XCODEBUILD="$stub_bin/xcodebuild" \
MARKLOOK_RC_XCRUN="$stub_bin/xcrun" \
MARKLOOK_RC_SWIFT="$stub_bin/swift" \
MARKLOOK_RC_LSREGISTER="$stub_bin/pass" \
MARKLOOK_RC_PLUGINKIT="$stub_bin/pass" \
MARKLOOK_RC_PACKAGE_DEBUG="$stub_bin/package-debug" \
MARKLOOK_RC_PACKAGE_DEVELOPER_ID="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_PACKAGE_ARTIFACT="$stub_bin/validate-package-artifact" \
MARKLOOK_RC_VALIDATE_DEVELOPER_ID_ARTIFACT="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_BUILT_BUNDLE="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_PREVIEW_CONTRACT="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_RENDERER_SECURITY="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_DIAGNOSTICS_BOUNDARIES="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_THUMBNAIL_BOUNDARIES="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_SUPPORTED_TYPES="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_VERSION_CONSISTENCY="$stub_bin/pass" \
MARKLOOK_RC_PACKAGE_DEBUG_TEST="$stub_bin/pass" \
MARKLOOK_RC_DEVELOPER_ID_LANE_TEST="$stub_bin/pass" \
MARKLOOK_RC_QUICKLOOK_PREVIEW_CONTRACT_TEST="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_SIGNED_MODE_TEST="$stub_bin/pass" \
MARKLOOK_RC_DOCTOR_SIGNING_TEST="$stub_bin/pass" \
MARKLOOK_RC_VERSION_CONSISTENCY_TEST="$stub_bin/pass" \
MARKLOOK_RC_DOCTOR_RELEASE_IDENTITY="$stub_bin/pass" \
MARKLOOK_RC_DIST_DIR="$dist_dir" \
MARKLOOK_RC_DERIVED_DATA="$fixture_root/DerivedData" \
MARKLOOK_RC_PROJECT_DUMP="$fixture_root/reports/project.yml" \
MARKLOOK_RC_RENDERER_FIXTURE="$fixture_root/reports/renderer.html" \
  "$gate" --ci >"$fixture_root/ci.out" 2>&1 || {
    cat "$fixture_root/ci.out" >&2
    exit 1
  }

grep -q 'MarkLook release candidate validation: PASS' "$fixture_root/ci.out"
grep -q '^Version: 0.1.1$' "$fixture_root/ci.out"
grep -q '^Mode: ci$' "$fixture_root/ci.out"
grep -q '^Package path:' "$fixture_root/ci.out"
grep -q '^Checksum:' "$fixture_root/ci.out"
grep -q 'MarkLook-0.1.1-debug-' "$fixture_root/ci.out"
grep -Fq "pass -u $resolved_fixture/DerivedData/Build/Products/Debug/MarkLook.app" "$stub_log"
grep -Fq "pass -u $resolved_fixture/dist/MarkLook-0.1.1-debug-$(git -C "$repo_root" rev-parse --short HEAD)/MarkLook.app" "$stub_log"
test -f "$fixture_root/reports/project.yml"
test -f "$fixture_root/reports/renderer.html"

if grep -Eq 'build-local|validate-signed|diagnose-thumbnail|apple-development|/Applications/MarkLook.app' "$stub_log"; then
  echo "error: --ci invoked signing-required or local runtime commands" >&2
  cat "$stub_log" >&2
  exit 1
fi

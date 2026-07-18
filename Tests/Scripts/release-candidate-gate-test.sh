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

MARKLOOK_RC_TEST_LOG="$stub_log" \
MARKLOOK_RC_RUBY="$stub_bin/pass" \
MARKLOOK_RC_XCODEGEN="$stub_bin/pass" \
MARKLOOK_RC_XCODEBUILD="$stub_bin/xcodebuild" \
MARKLOOK_RC_XCRUN="$stub_bin/xcrun" \
MARKLOOK_RC_SWIFT="$stub_bin/swift" \
MARKLOOK_RC_PACKAGE_DEBUG="$stub_bin/package-debug" \
MARKLOOK_RC_VALIDATE_PACKAGE_ARTIFACT="$stub_bin/validate-package-artifact" \
MARKLOOK_RC_VALIDATE_BUILT_BUNDLE="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_PREVIEW_CONTRACT="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_RENDERER_SECURITY="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_DIAGNOSTICS_BOUNDARIES="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_THUMBNAIL_BOUNDARIES="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_SUPPORTED_TYPES="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_VERSION_CONSISTENCY="$stub_bin/pass" \
MARKLOOK_RC_PACKAGE_DEBUG_TEST="$stub_bin/pass" \
MARKLOOK_RC_QUICKLOOK_PREVIEW_CONTRACT_TEST="$stub_bin/pass" \
MARKLOOK_RC_VALIDATE_SIGNED_MODE_TEST="$stub_bin/pass" \
MARKLOOK_RC_DOCTOR_SIGNING_TEST="$stub_bin/pass" \
MARKLOOK_RC_VERSION_CONSISTENCY_TEST="$stub_bin/pass" \
MARKLOOK_RC_DIST_DIR="$dist_dir" \
MARKLOOK_RC_DERIVED_DATA="$fixture_root/DerivedData" \
  "$gate" --ci >"$fixture_root/ci.out" 2>&1

grep -q 'MarkLook release candidate validation: PASS' "$fixture_root/ci.out"
grep -q '^Version: 0.1.1$' "$fixture_root/ci.out"
grep -q '^Mode: ci$' "$fixture_root/ci.out"
grep -q '^Package path:' "$fixture_root/ci.out"
grep -q '^Checksum:' "$fixture_root/ci.out"
grep -q 'MarkLook-0.1.1-debug-' "$fixture_root/ci.out"

if grep -Eq 'build-local|validate-signed|diagnose-thumbnail|apple-development|/Applications/MarkLook.app' "$stub_log"; then
  echo "error: --ci invoked signing-required or local runtime commands" >&2
  cat "$stub_log" >&2
  exit 1
fi

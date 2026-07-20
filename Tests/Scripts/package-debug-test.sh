#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
packager="$repo_root/Scripts/package-debug.sh"
validator="$repo_root/Scripts/validate-package-artifact.sh"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

assert_exit_64() {
  local output_file="$1"
  shift
  set +e
  "$@" >"$output_file" 2>&1
  local status="$?"
  set -e
  if [ "$status" -ne 64 ]; then
    echo "error: expected exit 64, got $status for: $*" >&2
    cat "$output_file" >&2
    exit 1
  fi
  grep -q 'usage:' "$output_file"
}

assert_exit_64 "$fixture_root/no-mode.out" "$packager"
assert_exit_64 "$fixture_root/unknown-mode.out" "$packager" --bogus
assert_exit_64 "$fixture_root/no-team.out" env -u DEVELOPMENT_TEAM "$packager" --apple-development

stub_bin="$fixture_root/bin"
stub_log="$fixture_root/stub.log"
mkdir -p "$stub_bin"
touch "$stub_log"

cat >"$stub_bin/xcodegen" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'xcodegen %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_LOG"
STUB

cat >"$stub_bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'xcodebuild %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_LOG"
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
app="$derived/Build/Products/Debug/MarkLook.app"
mkdir -p "$app/Contents/PlugIns/MarkLookPreview.appex/Contents" \
  "$app/Contents/PlugIns/MarkLookThumbnail.appex/Contents" \
  "$app/Contents/Resources"
touch "$app/Contents/Resources/Assets.car"
cat >"$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.91wan.MarkLook</string>
<key>CFBundleIconName</key><string>AppIcon</string>
</dict></plist>
PLIST
STUB

cat >"$stub_bin/validator" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'validator %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_LOG"
STUB

cat >"$stub_bin/cleanup" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'cleanup %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_LOG"
STUB

chmod +x "$stub_bin"/*

dist_dir="$fixture_root/dist"
MARKLOOK_PACKAGE_TEST_LOG="$stub_log" \
MARKLOOK_PACKAGE_XCODEGEN="$stub_bin/xcodegen" \
MARKLOOK_PACKAGE_XCODEBUILD="$stub_bin/xcodebuild" \
MARKLOOK_PACKAGE_VALIDATE_BUILT_BUNDLE="$stub_bin/validator" \
MARKLOOK_PACKAGE_VALIDATE_PREVIEW_CONTRACT="$stub_bin/validator" \
MARKLOOK_PACKAGE_VALIDATE_THUMBNAIL_BOUNDARIES="$stub_bin/validator" \
MARKLOOK_PACKAGE_VALIDATE_DIAGNOSTICS_BOUNDARIES="$stub_bin/validator" \
MARKLOOK_PACKAGE_LSREGISTER="$stub_bin/cleanup" \
MARKLOOK_PACKAGE_PLUGINKIT="$stub_bin/cleanup" \
MARKLOOK_PACKAGE_DIST_DIR="$dist_dir" \
  "$packager" --unsigned-ci >"$fixture_root/package.out" 2>&1

manifest="$(/usr/bin/find "$dist_dir" -name MANIFEST.txt -type f -print | head -n 1)"
if [ -z "$manifest" ]; then
  echo "error: package test did not produce MANIFEST.txt" >&2
  cat "$fixture_root/package.out" >&2
  exit 1
fi

grep -q 'Public release caveat:' "$manifest"
grep -q 'Developer ID Application signing, hardened runtime, notarization, and stapling are still required' "$manifest"
grep -q '^Build mode: unsigned-ci' "$manifest"
grep -q '^AppIcon status: committed; Assets.car present' "$manifest"
grep -Fq "cleanup -u $repo_root/.build/PackageUnsignedDerivedData/Build/Products/Debug/MarkLook.app" "$stub_log"
grep -Fq "cleanup -u $dist_dir/MarkLook-0.1.1-debug-$(git -C "$repo_root" rev-parse --short HEAD)/MarkLook.app" "$stub_log"

bad_dir="$fixture_root/bad"
mkdir -p "$bad_dir/empty"
echo "not an app" >"$bad_dir/empty/README.txt"
bad_zip="$bad_dir/MarkLook-bad.zip"
ditto -c -k "$bad_dir/empty" "$bad_zip"
(
  cd "$bad_dir"
  shasum -a 256 "$(basename "$bad_zip")" >"$(basename "$bad_zip").sha256"
)
cat >"$bad_dir/MANIFEST.txt" <<'MANIFEST'
Build mode: unsigned-ci
MANIFEST

set +e
"$validator" "$bad_zip" >"$fixture_root/bad-validator.out" 2>&1
bad_status="$?"
set -e
if [ "$bad_status" -eq 0 ]; then
  echo "error: validate-package-artifact accepted a zip without MarkLook.app" >&2
  exit 1
fi
grep -q 'MarkLook.app' "$fixture_root/bad-validator.out"

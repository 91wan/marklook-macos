#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
diagnostic="$repo_root/Scripts/diagnose-thumbnail-selection.sh"

fixture_root="$(mktemp -d)"
diagnostic_output="$fixture_root/diagnostic.out"
stub_bin="$fixture_root/bin"
stub_log="$fixture_root/codesign.log"
sentinel="$fixture_root/injected-sentinel"
output_dir=""
unique_sample=""

cleanup() {
  if [[ "$output_dir" == /tmp/marklook-thumbnail-diagnostics-* ]]; then
    rm -rf "$output_dir"
  fi
  if [[ "$unique_sample" == /tmp/marklook-thumbnail-* ]]; then
    rm -f "$unique_sample"
  fi
  rm -rf "$fixture_root"
}
trap cleanup EXIT

mkdir -p "$stub_bin"

cat >"$stub_bin/codesign" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -eq 4 ] &&
  [ "$1" = "-d" ] &&
  [ "$2" = "--entitlements" ] &&
  [ "$3" = "-" ]; then
  printf 'entitlements-argc=%s\n' "$#" >>"$MARKLOOK_DIAGNOSTIC_TEST_LOG"
  printf 'entitlements-path=%s\n' "$4" >>"$MARKLOOK_DIAGNOSTIC_TEST_LOG"
fi
STUB

cat >"$stub_bin/pass" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
STUB

chmod +x "$stub_bin/codesign" "$stub_bin/pass"
for command in file mdls pluginkit qlmanage; do
  ln -s pass "$stub_bin/$command"
done

dangerous_name="MarkLook ';touch\${IFS}\${MARKLOOK_DIAGNOSTIC_SENTINEL};#.app"
app="$fixture_root/$dangerous_name"
preview="$app/Contents/PlugIns/MarkLookPreview.appex"
thumbnail="$app/Contents/PlugIns/MarkLookThumbnail.appex"
thumbnail_binary="$thumbnail/Contents/MacOS/MarkLookThumbnail"
mkdir -p "$app/Contents" "$preview/Contents" "$(dirname "$thumbnail_binary")"

cp "$repo_root/MarkLookApp/Info.plist" "$app/Contents/Info.plist"
cp "$repo_root/PreviewExtension/Info.plist" "$preview/Contents/Info.plist"
cp "$repo_root/ThumbnailExtension/Info.plist" "$thumbnail/Contents/Info.plist"
touch "$thumbnail_binary"

/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.91wan.MarkLook' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.91wan.MarkLook.Preview' "$preview/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.91wan.MarkLook.Thumbnail' "$thumbnail/Contents/Info.plist"

MARKLOOK_DIAGNOSTIC_SENTINEL="$sentinel" \
MARKLOOK_DIAGNOSTIC_TEST_LOG="$stub_log" \
PATH="$stub_bin:$PATH" \
  "$diagnostic" "$app" "$repo_root/Samples/basic.md" >"$diagnostic_output" 2>&1

output_dir="$(sed -n 's/^Writing thumbnail diagnostics to: //p' "$diagnostic_output" | head -n 1)"
unique_sample="$(sed -n 's/^Unique sample: //p' "$diagnostic_output" | head -n 1)"
canonical_app="$(cd "$(dirname "$app")" && pwd -P)/$(basename "$app")"
expected_thumbnail="$canonical_app/Contents/PlugIns/MarkLookThumbnail.appex"

if [ -e "$sentinel" ]; then
  echo "error: diagnostic path triggered an injected command" >&2
  cat "$diagnostic_output" >&2
  exit 1
fi

if [ "$(grep -Fxc 'entitlements-argc=4' "$stub_log")" -ne 1 ]; then
  echo "error: expected one four-argument entitlements invocation" >&2
  cat "$stub_log" >&2
  exit 1
fi

if ! grep -Fxq "entitlements-path=$expected_thumbnail" "$stub_log"; then
  echo "error: dangerous thumbnail path was not passed as one exact argv value" >&2
  cat "$stub_log" >&2
  exit 1
fi

if grep -Fq 'bash -lc' "$diagnostic"; then
  echo "error: thumbnail diagnostic must not execute shell command strings" >&2
  exit 1
fi

echo "PASS: thumbnail diagnostic preserves dangerous paths as argv without command injection"

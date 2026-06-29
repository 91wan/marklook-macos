#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
validator="$repo_root/Scripts/validate-signed-quicklook.sh"

if [ ! -x "$validator" ]; then
  echo "error: validator is missing or not executable: $validator" >&2
  exit 1
fi

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

app="$fixture_root/MarkLook.app"
samples_dir="$fixture_root/Samples"
stub_bin="$fixture_root/bin"
call_log="$fixture_root/calls.log"

mkdir -p "$app/Contents" "$samples_dir" "$stub_bin"
touch "$call_log"
touch "$samples_dir/basic.md"
touch "$samples_dir/gfm-table-task-list.md"
touch "$samples_dir/long-ai-review.md"
touch "$samples_dir/unsafe-html.md"
touch "$samples_dir/large-fast-mode.md"

cat >"$stub_bin/validate-built-bundle" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'validate-built-bundle %s\n' "$*" >>"$MARKLOOK_STUB_LOG"
STUB

cat >"$stub_bin/codesign" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'codesign %s\n' "$*" >>"$MARKLOOK_STUB_LOG"
if [ "${1:-}" = "-dv" ]; then
  cat >&2 <<'EOF'
Executable=/tmp/MarkLook.app/Contents/MacOS/MarkLook
Identifier=com.91wan.MarkLook
Format=app bundle with Mach-O thin (arm64)
Signature size=4800
TeamIdentifier=W2SP34K4MR
EOF
fi
STUB

cat >"$stub_bin/spctl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'spctl %s\n' "$*" >>"$MARKLOOK_STUB_LOG"
STUB

cat >"$stub_bin/open" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'open %s\n' "$*" >>"$MARKLOOK_STUB_LOG"
STUB

cat >"$stub_bin/qlmanage" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'qlmanage %s\n' "$*" >>"$MARKLOOK_STUB_LOG"
STUB

cat >"$stub_bin/killall" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'killall %s\n' "$*" >>"$MARKLOOK_STUB_LOG"
STUB

cat >"$stub_bin/pluginkit" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'pluginkit %s\n' "$*" >>"$MARKLOOK_STUB_LOG"
cat <<'EOF'
+ com.91wan.MarkLook.Preview(1.0) MarkLookPreview
+ com.91wan.MarkLook.Thumbnail(1.0) MarkLookThumbnail
EOF
STUB

cat >"$stub_bin/mdls" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'mdls %s\n' "$*" >>"$MARKLOOK_STUB_LOG"
echo 'kMDItemContentType = "net.daringfireball.markdown"'
STUB

chmod +x "$stub_bin"/*

run_validator() {
  MARKLOOK_STUB_LOG="$call_log" \
    MARKLOOK_VALIDATE_SIGNED_BUNDLE_COMMAND="$stub_bin/validate-built-bundle" \
    MARKLOOK_VALIDATE_SIGNED_SAMPLES_DIR="$samples_dir" \
    MARKLOOK_VALIDATE_SIGNED_SLEEP_SECONDS=0 \
    PATH="$stub_bin:$PATH" \
    "$validator" "$@"
}

if run_validator --development "$app" >"$fixture_root/no-mode.out" 2>&1; then
  echo "error: validator accepted signed validation without an explicit interaction mode" >&2
  exit 1
fi
grep -q -- '--noninteractive' "$fixture_root/no-mode.out"
grep -q -- '--interactive-preview' "$fixture_root/no-mode.out"

: >"$call_log"
run_validator --development --noninteractive "$app" >"$fixture_root/noninteractive.out" 2>&1
if grep -q -- 'qlmanage -p ' "$call_log"; then
  echo "error: --noninteractive must not run qlmanage -p" >&2
  cat "$call_log" >&2
  exit 1
fi
grep -F -q -- "qlmanage -t -s 512 -o /tmp $samples_dir/basic.md" "$call_log"
grep -q -- 'interactive preview checks: skipped' "$fixture_root/noninteractive.out"

: >"$call_log"
run_validator --development --interactive-preview "$app" >"$fixture_root/interactive.out" 2>&1
grep -q -- 'Close each Quick Look preview window manually' "$fixture_root/interactive.out"
grep -F -q -- "qlmanage -p $samples_dir/basic.md" "$call_log"
grep -F -q -- "qlmanage -p $samples_dir/gfm-table-task-list.md" "$call_log"
grep -F -q -- "qlmanage -p $samples_dir/long-ai-review.md" "$call_log"
grep -F -q -- "qlmanage -p $samples_dir/unsafe-html.md" "$call_log"
grep -F -q -- "qlmanage -p $samples_dir/large-fast-mode.md" "$call_log"
grep -F -q -- "qlmanage -t -s 512 -o /tmp $samples_dir/basic.md" "$call_log"

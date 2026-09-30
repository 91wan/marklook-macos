#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
packager_source="$repo_root/Scripts/package-debug.sh"
validator="$repo_root/Scripts/validate-package-artifact.sh"

fixture_root="$(/usr/bin/mktemp -d "$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)marklook-package-test.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

# Keep source-build fixtures and parent-retention regression output off the checkout.
fixture_repo="$fixture_root/repo"
mkdir -p "$fixture_repo/Scripts" "$fixture_repo/MarkLookApp/Assets.xcassets/AppIcon.appiconset"
cp "$packager_source" "$repo_root/Scripts/release-path-policy.sh" "$fixture_repo/Scripts/"
cp "$repo_root/MarkLookApp/Info.plist" "$fixture_repo/MarkLookApp/"
packager="$fixture_repo/Scripts/package-debug.sh"

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
assert_exit_64 "$fixture_root/keep-app.out" "$packager" --unsigned-ci --keep-app
assert_exit_64 "$fixture_root/keep-only.out" "$packager" --keep-app

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

cat >"$stub_bin/writer" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
app="$1"
# The leader may fail or receive a signal while a descendant still owns writes.
(
  sleep 0.4
  mkdir -p "$app/Contents"
  touch "$app/Contents/late-write"
  printf 'late-write\n' >>"$MARKLOOK_PACKAGE_TEST_LOG"
) &
printf 'writer-ready\n' >>"$MARKLOOK_PACKAGE_TEST_LOG"
if [ "$MARKLOOK_PACKAGE_TEST_CASE" = tool-failure ] || [ "$MARKLOOK_PACKAGE_TEST_CASE" = unsettled-failure ]; then
  exit 23
fi
if [ "$MARKLOOK_PACKAGE_TEST_CASE" = launch-signal ] || [ "$MARKLOOK_PACKAGE_TEST_CASE" = unsettled-signal ] ||
   [ "$MARKLOOK_PACKAGE_TEST_CASE" = rm-signal ]; then
  kill -TERM "$PPID"
fi
wait
STUB

# Inject partial-output failure/signal after the ordinary build fixture exists.
cat >>"$stub_bin/xcodebuild" <<'STUB'
case "${MARKLOOK_PACKAGE_TEST_CASE:-}" in
  tool-failure|signal-*|launch-signal|unsettled-failure|unsettled-signal)
    exec "$MARKLOOK_PACKAGE_TEST_BIN/writer" "$app"
    ;;
esac
STUB

cat >"$stub_bin/validator" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'validator %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_LOG"
if [ "${MARKLOOK_PACKAGE_TEST_CASE:-}" = validator-failure ] || [ "${MARKLOOK_PACKAGE_TEST_CASE:-}" = rm-failure ]; then
  exit 29
fi
if { [ "${MARKLOOK_PACKAGE_TEST_CASE:-}" = copy-signal ] || [ "${MARKLOOK_PACKAGE_TEST_CASE:-}" = rm-signal ]; } &&
   [ "$#" -eq 1 ]; then
  exec "$MARKLOOK_PACKAGE_TEST_BIN/writer" "$1"
fi
STUB

cat >"$stub_bin/cleanup" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'cleanup %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_LOG"
STUB

cat >"$stub_bin/source-builder" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'source-builder\n' >>"$MARKLOOK_PACKAGE_TEST_LOG"
app="$PWD/.build/LocalDerivedData/Build/Products/Debug/MarkLook.app"
test -f "$app/Contents/source-sentinel"
printf 'synthetic private source-build output\n'
STUB

cat >"$stub_bin/codesign" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'codesign %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_LOG"
printf 'Executable=%s/Contents/MacOS/MarkLook\n' "${!#}" >&2
case "$1" in
  --verify) exit "${MARKLOOK_PACKAGE_TEST_VERIFY_STATUS:-0}" ;;
  -dv)
    printf 'Authority=Apple Development: Synthetic Private Subject (TEAMID1234)\n' >&2
    if [ "${MARKLOOK_PACKAGE_TEST_CASE:-}" = no-team ]; then
      printf 'TeamIdentifier=not set\n' >&2
    else
      printf 'TeamIdentifier=TEAMID1234\n' >&2
    fi
    case "${MARKLOOK_PACKAGE_TEST_CASE:-}" in
      adhoc) printf 'Signature=adhoc\n' >&2 ;;
    esac
    ;;
  *) exit 2 ;;
esac
STUB

# Bash-only instrumentation belongs to tests, including fixed-path mktemp.
cat >"$fixture_root/spy.bash" <<'SPY'
rm() {
  printf 'rm %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_MUTATIONS"
  case "${MARKLOOK_PACKAGE_TEST_CASE:-}" in
    rm-*)
      if [ "${BASH_SOURCE[1]:-}" = "$MARKLOOK_PACKAGE_TEST_PACKAGER" ] && [ "$#" -eq 2 ] &&
         [ "$1" = -rf ] && [ -n "${run_root:-}" ] && [ "$2" = "$run_root" ]; then
        printf 'run-root-rm-failure %s\n' "$run_root" >>"$MARKLOOK_PACKAGE_TEST_LOG"
        return 73
      fi ;;
  esac
  command rm "$@"
}
mkdir() { printf 'mkdir %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_MUTATIONS"; command mkdir "$@"; }
mktemp() { printf 'mktemp %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_MUTATIONS"; command mktemp "$@"; }
function /usr/bin/mktemp() {
  local root
  printf 'mktemp %s\n' "$*" >>"$MARKLOOK_PACKAGE_TEST_MUTATIONS"
  root="$(command /usr/bin/mktemp "$@")" || return
  printf 'allocated-run-root %s\n' "$root" >>"$MARKLOOK_PACKAGE_TEST_LOG"
  printf '%s\n' "$root"
}
kill() {
  if [ "$#" -eq 3 ] && [ "$1" = -KILL ] && [ "$2" = -- ] && [ "$3" = "-${active_tool:-}" ]; then
    printf 'owned-group-stop %s\n' "$3" >>"$MARKLOOK_PACKAGE_TEST_LOG"
  fi
  # Model an owned group that outlives the cap, without leaking real writers.
  # Release after 100 probes so this regression is also bounded on the old code.
  if [ "${force_live_group:-0}" = 1 ] && [ "$#" -eq 3 ] && [ "$1" = -0 ] &&
     [ "$2" = -- ] && [ "$3" = "-${active_tool:-}" ] && [ "${group_probes:-0}" -lt 100 ]; then
    group_probes=$((${group_probes:-0} + 1))
    printf 'owned-group-check %s\n' "$3" >>"$MARKLOOK_PACKAGE_TEST_LOG"
    return 0
  fi
  builtin kill "$@"
}
set -T
trap '
  case "$BASH_COMMAND" in
    trap*EXIT*|trap*HUP*|trap*TERM*|trap*INT*)
      printf "trap %s\n" "$BASH_COMMAND" >>"$MARKLOOK_PACKAGE_TEST_MUTATIONS" ;;
    "active_tool=\$!")
      case "${MARKLOOK_PACKAGE_TEST_CASE:-}" in
        unsettled-*)
          if [ "${1:-}" = "$MARKLOOK_PACKAGE_XCODEBUILD" ]; then force_live_group=1; fi ;;
      esac
      if [ "${MARKLOOK_PACKAGE_TEST_CASE:-}" = capture-signal ] && [ "${signal_spy_sent:-0}" = 0 ]; then
        signal_spy_sent=1
        printf "capture-signal\n" >>"$MARKLOOK_PACKAGE_TEST_LOG"
        kill -TERM "$$"
      fi ;;
  esac
' DEBUG
SPY

chmod +x "$stub_bin"/*

dist_dir="$fixture_root/dist"
mutation_log="$fixture_root/mutations.log"
export MARKLOOK_PACKAGE_TEST_LOG="$stub_log" MARKLOOK_PACKAGE_TEST_BIN="$stub_bin"
export MARKLOOK_PACKAGE_TEST_PACKAGER="$packager"
export MARKLOOK_PACKAGE_TEST_MUTATIONS="$mutation_log" BASH_ENV="$fixture_root/spy.bash"
export MARKLOOK_PACKAGE_XCODEGEN="$stub_bin/xcodegen" MARKLOOK_PACKAGE_XCODEBUILD="$stub_bin/xcodebuild"
export MARKLOOK_PACKAGE_VALIDATE_BUILT_BUNDLE="$stub_bin/validator"
export MARKLOOK_PACKAGE_VALIDATE_PREVIEW_CONTRACT="$stub_bin/validator"
export MARKLOOK_PACKAGE_VALIDATE_THUMBNAIL_BOUNDARIES="$stub_bin/validator"
export MARKLOOK_PACKAGE_VALIDATE_DIAGNOSTICS_BOUNDARIES="$stub_bin/validator"
export MARKLOOK_PACKAGE_LSREGISTER="$stub_bin/cleanup" MARKLOOK_PACKAGE_PLUGINKIT="$stub_bin/cleanup"
export MARKLOOK_PACKAGE_BUILD_APPLE_DEVELOPMENT="$stub_bin/source-builder"
export MARKLOOK_PACKAGE_CODESIGN="$stub_bin/codesign" MARKLOOK_PACKAGE_DITTO=/usr/bin/ditto
export MARKLOOK_PACKAGE_DIST_DIR="$dist_dir"

fail() { echo "error: $*" >&2; exit 1; }

assert_status() {
  local expected="$1" actual
  shift
  set +e
  "$@" >"$fixture_root/package.out" 2>&1
  actual="$?"
  set -e
  if [ "$actual" -ne "$expected" ]; then
    cat "$fixture_root/package.out" >&2
    fail "expected exit $expected, got $actual for: $*"
  fi
}

reset_logs() { : >"$stub_log"; : >"$mutation_log"; }

assert_run_cleanup() {
  local built stage root target expected_cleanups=3
  built="$(sed -n 's/^cleanup -u \(.*\/DerivedData\/Build\/Products\/Debug\/MarkLook.app\)$/\1/p' "$stub_log")"
  stage="$(sed -n 's/^cleanup -u \(.*\/package\/MarkLook.app\)$/\1/p' "$stub_log")"
  test -n "$stage" || fail 'missing staged App cleanup target'
  root="${stage%/package/MarkLook.app}"
  case "$root" in
    "$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)"marklook-debug.*) ;;
    *) fail "stage did not use fixed OS temp root: $root" ;;
  esac
  test ! -e "$root" || fail "run root retained: $root"
  if [ "${1:-unsigned}" = unsigned ]; then
    test "$built" = "$root/DerivedData/Build/Products/Debug/MarkLook.app" || fail 'wrong unsigned source cleanup target'
    expected_cleanups=6
  else
    ! grep -Eq '^cleanup .*LocalDerivedData' "$stub_log" || fail 'signed source was unregistered'
  fi
  for target in "$stage" ${built:+"$built"}; do
    grep -Fqx "cleanup -r $target/Contents/PlugIns/MarkLookPreview.appex" "$stub_log"
    grep -Fqx "cleanup -r $target/Contents/PlugIns/MarkLookThumbnail.appex" "$stub_log"
    grep -Fqx "cleanup -u $target" "$stub_log"
  done
  test "$(grep -c '^cleanup ' "$stub_log")" -eq "$expected_cleanups" || fail 'unexpected extra App cleanup targets'
  ! grep -q '/Applications' "$stub_log" "$mutation_log" || fail 'touched /Applications'
  ! grep -q 'late-write' "$stub_log" || fail 'descendant writer survived cleanup'
}

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$fixture_repo/MarkLookApp/Info.plist")"
stem="MarkLook-$version-debug-unknown"
assert_artifacts() {
  local artifact="$MARKLOOK_PACKAGE_DIST_DIR/$stem" zip="$stem.zip" entries stage
  entries="$(ls -A "$artifact" | LC_ALL=C sort)"
  test "$entries" = "$(printf '%s\n' MANIFEST.txt "$zip" "$zip.sha256" | LC_ALL=C sort)" || fail "artifact directory retained extra output: $entries"
  (cd "$artifact" && /usr/bin/shasum -a 256 -c "$zip.sha256")
  rm -rf "$fixture_root/extracted"
  /usr/bin/ditto -x -k "$artifact/$zip" "$fixture_root/extracted"
  test -f "$fixture_root/extracted/MarkLook.app/Contents/Resources/Assets.car"
  test -d "$fixture_root/extracted/MarkLook.app/Contents/PlugIns/MarkLookPreview.appex"
  test -d "$fixture_root/extracted/MarkLook.app/Contents/PlugIns/MarkLookThumbnail.appex"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$fixture_root/extracted/MarkLook.app/Contents/Info.plist" | grep -qx com.91wan.MarkLook
  ! grep -Eq '/Users/|/private/|/var/|/tmp/' "$artifact/MANIFEST.txt" || fail 'manifest leaked private paths'
  ! grep -Eq 'TEAMID1234|Synthetic Private Subject|App bundle:' "$artifact/MANIFEST.txt" "$fixture_root/package.out" || fail 'summary leaked private identity or retained App claim'
  grep -Fqx "Package path: $zip" "$artifact/MANIFEST.txt"
  stage="$(sed -n 's/^cleanup -u \(.*\/package\/MarkLook.app\)$/\1/p' "$stub_log")"
  test "$(grep -Fxc "validator $stage" "$stub_log")" -eq 2 || fail 'staged bundle/preview validators were not both called'
  test "$(grep -Fxc 'validator ' "$stub_log")" -eq 2 || fail 'thumbnail/diagnostics boundary validators were not both called'
}

reset_logs
assert_status 0 "$packager" --unsigned-ci
# Deliberately first: the exact parent fails safely here, before unsafe-path cases.
assert_artifacts
assert_run_cleanup
echo 'PASS unsigned ZIP, exact persistent contents, source/stage cleanup'

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
grep -q '^Package directory: \.$' "$manifest"

# Valid Unicode paths must not inherit the caller's non-UTF-8 locale.
export MARKLOOK_PACKAGE_DIST_DIR="$fixture_root/dist-$(printf '\346\265\213\350\257\225')"
reset_logs
assert_status 0 env LC_ALL=C TMPDIR="$HOME" "$packager" --unsigned-ci
assert_artifacts
assert_run_cleanup
echo 'PASS non-ASCII dist with caller LC_ALL=C and ignored poisoned TMPDIR'

export MARKLOOK_PACKAGE_DIST_DIR="$dist_dir"
source_app="$fixture_repo/.build/LocalDerivedData/Build/Products/Debug/MarkLook.app"
mkdir -p "$(dirname "$source_app")"
/usr/bin/ditto "$fixture_root/extracted/MarkLook.app" "$source_app"
printf 'source unchanged\n' >"$source_app/Contents/source-sentinel"
/usr/bin/ditto "$source_app" "$fixture_root/source-before"
export DEVELOPMENT_TEAM=TEAMID1234
reset_logs
assert_status 0 "$packager" --apple-development
assert_artifacts
assert_run_cleanup signed
diff -r "$source_app" "$fixture_root/extracted/MarkLook.app"
diff -r "$fixture_root/source-before" "$source_app"
grep -qx 'Signing identity summary: Apple Development local validation package; certificate subject redacted' "$dist_dir/$stem/MANIFEST.txt"
grep -qx 'TeamIdentifier: redacted' "$dist_dir/$stem/MANIFEST.txt"
grep -q 'source build lifecycle is excluded' "$dist_dir/$stem/MANIFEST.txt"
signed_stage="$(sed -n 's/^cleanup -u \(.*\/package\/MarkLook.app\)$/\1/p' "$stub_log")"
grep -Fqx "codesign --verify --deep --strict --verbose=4 $signed_stage" "$stub_log"
grep -Fqx "codesign -dv --verbose=4 $signed_stage" "$stub_log"
echo 'PASS synthetic signed packaging, redaction, signed source retained unchanged'

assert_rejected_before_mutation() {
  local label="$1"
  shift
  reset_logs
  assert_status 1 env "$@" "$packager" --unsigned-ci
  test ! -s "$stub_log" || fail "$label invoked a release tool"
  test ! -s "$mutation_log" || fail "$label registered cleanup or mutated paths: $(cat "$mutation_log")"
  grep -q 'error: unsafe' "$fixture_root/package.out"
  echo "PASS admission denial before tools/traps/mutations: $label"
}

for denied in '' / "$HOME" "$fixture_repo" "$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)" /private/tmp /Applications/MarkLook.app; do
  assert_rejected_before_mutation "protected/empty $denied" "MARKLOOK_PACKAGE_DIST_DIR=$denied"
done
assert_rejected_before_mutation multiline "MARKLOOK_PACKAGE_DIST_DIR=$fixture_root/line
break"
assert_rejected_before_mutation poisoned-tmp-home "TMPDIR=$HOME" "MARKLOOK_PACKAGE_DIST_DIR=$HOME/new-debug-dist"
assert_rejected_before_mutation poisoned-tmp-repo "TMPDIR=$fixture_repo" "MARKLOOK_PACKAGE_DIST_DIR=$fixture_repo/new-debug-dist"
ln -s "$HOME" "$fixture_root/missing-parent-link"
assert_rejected_before_mutation missing-parent-escape "MARKLOOK_PACKAGE_DIST_DIR=$fixture_root/missing-parent-link/missing/dist"
mkdir -p "$fixture_root/linked-artifact-dist" "$fixture_root/escaped-artifact"
printf 'preserve\n' >"$fixture_root/escaped-artifact/sentinel"
ln -s "$fixture_root/escaped-artifact" "$fixture_root/linked-artifact-dist/$stem"
assert_rejected_before_mutation artifact-child-escape "MARKLOOK_PACKAGE_DIST_DIR=$fixture_root/linked-artifact-dist"
grep -qx preserve "$fixture_root/escaped-artifact/sentinel"

for failure in tool-failure validator-failure; do
  reset_logs
  expected=23
  [ "$failure" != validator-failure ] || expected=29
  assert_status "$expected" env MARKLOOK_PACKAGE_TEST_CASE="$failure" "$packager" --unsigned-ci
  sleep 0.6
  assert_run_cleanup
  echo "PASS original failure status and cleanup: $failure"
done

for failure in adhoc no-team; do
  reset_logs
  assert_status 1 env MARKLOOK_PACKAGE_TEST_CASE="$failure" "$packager" --apple-development
  assert_run_cleanup signed
done
reset_logs
assert_status 31 env MARKLOOK_PACKAGE_TEST_VERIFY_STATUS=31 "$packager" --apple-development
assert_run_cleanup signed
echo 'PASS signed verification and identity rejection cleanup'
diff -r "$fixture_root/source-before" "$source_app"

assert_signal_cleanup() {
  local signal="$1" expected="$2" scenario="$3" pid status ready=0 attempt
  reset_logs
  MARKLOOK_PACKAGE_TEST_CASE="$scenario" "$packager" --unsigned-ci >"$fixture_root/package.out" 2>&1 &
  pid=$!
  for ((attempt=0; attempt<150; attempt++)); do
    if grep -q writer-ready "$stub_log"; then ready=1; break; fi
    sleep 0.02
  done
  if [ "$ready" -ne 1 ]; then
    kill -KILL "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    cat "$fixture_root/package.out" >&2
    fail 'writer did not become ready within bounded wait'
  fi
  kill -"$signal" "$pid"
  set +e
  wait "$pid"
  status=$?
  set -e
  test "$status" -eq "$expected" || fail "signal $signal returned $status, expected $expected"
  sleep 0.6
  assert_run_cleanup
  echo "PASS active writer/descendant cleanup: $scenario $signal ($status)"
}

# Monitor mode prevents a background Bash fixture from inheriting ignored INT.
set -m
assert_signal_cleanup HUP 129 signal-HUP
assert_signal_cleanup TERM 143 signal-TERM
assert_signal_cleanup INT 130 signal-INT
assert_signal_cleanup TERM 143 copy-signal
reset_logs
assert_status 143 env MARKLOOK_PACKAGE_TEST_CASE=launch-signal "$packager" --unsigned-ci
sleep 0.6
assert_run_cleanup
echo 'PASS tool-initiated launch/wait-window signal cleanup'
reset_logs
assert_status 143 env MARKLOOK_PACKAGE_TEST_CASE=capture-signal "$packager" --unsigned-ci
grep -qx capture-signal "$stub_log"
sleep 0.6
assert_run_cleanup
echo 'PASS deterministic signal before owned PID capture'
set +m

for unsettled in success failure signal; do
  reset_logs
  expected=1
  [ "$unsettled" != failure ] || expected=23
  [ "$unsettled" != signal ] || expected=143
  assert_status "$expected" env MARKLOOK_PACKAGE_TEST_CASE="unsettled-$unsettled" "$packager" --unsigned-ci
  retained_root="$(sed -n 's/^allocated-run-root //p' "$stub_log")"
  case "$retained_root" in
    "$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)"marklook-debug.*) ;;
    *) fail 'unsettled-group test did not allocate an owned run root' ;;
  esac
  test -d "$retained_root" || fail 'cleanup removed the root while the group was unsettled'
  grep -q 'error: cleanup failure:' "$fixture_root/package.out"
  grep -Fq "preserving run root: $retained_root" "$fixture_root/package.out"
  test "$(grep -c '^owned-group-check ' "$stub_log")" -le 51 || fail 'owned-group wait exceeded its fixed cap'
  ! grep -q '^cleanup ' "$stub_log" || fail 'unsettled cleanup continued to App unregistration'
  ! grep -Fq "rm -rf $retained_root" "$mutation_log" || fail 'unsettled cleanup tried to remove its root'
  owned_group="$(sed -n 's/^owned-group-check //p' "$stub_log" | head -n 1)"
  ! builtin kill -0 -- "$owned_group" 2>/dev/null || fail 'real fixture writers are still live'
  rm -rf "$retained_root"
  echo "PASS bounded unsettled-group cleanup: $unsettled ($expected), run root preserved"
done

for rm_case in success failure signal; do
  reset_logs
  expected=1
  [ "$rm_case" != failure ] || expected=29
  [ "$rm_case" != signal ] || expected=143
  set +e
  MARKLOOK_PACKAGE_TEST_CASE="rm-$rm_case" "$packager" --unsigned-ci >"$fixture_root/package.out" 2>&1
  actual=$?
  set -e
  retained_root="$(sed -n 's/^allocated-run-root //p' "$stub_log")"
  case "$retained_root" in
    "$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)"marklook-debug.*) ;;
    *) fail 'rm-failure test did not allocate an owned run root' ;;
  esac
  grep -Fqx "run-root-rm-failure $retained_root" "$stub_log"
  test -d "$retained_root/package/MarkLook.app" || fail 'rm-failure test did not retain its staged App'
  test -d "$retained_root/DerivedData/Build/Products/Debug/MarkLook.app" || fail 'rm-failure test did not retain its unsigned source App'
  rm_defect=0
  if [ "$actual" -ne "$expected" ]; then
    cat "$fixture_root/package.out" >&2
    echo "error: rm-$rm_case expected exit $expected, got $actual (injected rm exit 73)" >&2
    rm_defect=1
  fi
  if ! grep -q 'error: cleanup failure:' "$fixture_root/package.out" ||
     ! grep -Fq "retained run root: $retained_root" "$fixture_root/package.out"; then
    echo "error: rm-$rm_case did not report the retained run-root cleanup failure" >&2
    rm_defect=1
  fi
  test -n "$(sed -n 's/^owned-group-stop //p' "$stub_log")" || fail 'rm-failure test did not stop owned jobs'
  for owned_group in $(sed -n 's/^owned-group-stop //p' "$stub_log"); do
    ! builtin kill -0 -- "$owned_group" 2>/dev/null || fail 'rm-failure test still has real writers'
  done
  ! grep -q 'late-write\|/Applications' "$stub_log" "$mutation_log" || fail 'rm-failure cleanup raced a writer or touched /Applications'
  # Bypass the production-only spy after verifying that this exact root is idle.
  command rm -rf "$retained_root"
  test ! -e "$retained_root" || fail 'rm-failure fixture teardown retained its owned root'
  [ "$rm_defect" -eq 0 ] || fail "rm-$rm_case regression RED; exact owned fixture root removed"
  echo "PASS run-root rm failure: $rm_case ($actual), reported/retained then exact test cleanup"
done

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

#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
validator="$repo_root/Scripts/validate-public-repo-privacy.sh"
failures=0

if [[ ! -x "$validator" ]]; then
  echo "error: validator is missing or not executable: $validator" >&2
  exit 1
fi

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

security_stub="$fixture_root/security"
cat >"$security_stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == "find-identity -v -p codesigning" ]]; then
  printf '  1) ABCDEF0123456789 "Developer ID Application: Fixture (%s)"\n' "$MARKLOOK_TEST_TEAM_ID"
  exit 0
fi
exit 2
STUB
chmod +x "$security_stub"

create_repo() {
  local name="$1"
  local repo="$fixture_root/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.name "MarkLook Test"
  git -C "$repo" config user.email "marklook-test@example.invalid"
  printf '%s\n' "$repo"
}

commit_repo() {
  local repo="$1"
  git -C "$repo" add .
  git -C "$repo" commit -q -m "fixture"
}

assert_rejected() {
  local name="$1" expected="$2" status="$3" output="$4"
  if [[ "$status" -eq 0 ]] || grep -q 'public repo privacy validation: PASS' "$output" ||
    ! grep -q "$expected" "$output"; then
    echo "FAIL: $name (exit $status; expected rejection: $expected)" >&2
    cat "$output" >&2
    failures=$((failures + 1))
  else
    echo "PASS: $name rejected without PASS"
  fi
}

assert_accepted() {
  local name="$1" mode="$2" status="$3" output="$4"
  if [[ "$status" -ne 0 ]] || ! grep -q "public repo privacy validation: PASS ($mode)" "$output"; then
    echo "FAIL: $name $mode (exit $status; expected PASS)" >&2
    cat "$output" >&2
    failures=$((failures + 1))
  else
    echo "PASS: $name $mode"
  fi
}

expect_failure() {
  local name="$1"
  local expected="$2"
  local repo
  repo="$(create_repo "$name-current")"
  "$name" "$repo"
  commit_repo "$repo"

  local status=0
  (cd "$repo" && "$validator") >"$repo/out" 2>&1 || status=$?
  assert_rejected "$name current" "$expected" "$status" "$repo/out"
}

expect_archive_failure() {
  local name="$1"
  local expected="$2"
  local repo
  repo="$(create_repo "$name-archive")"
  "$name" "$repo"
  commit_repo "$repo"

  local status=0
  (cd "$repo" && "$validator" --archive) >"$repo/out" 2>&1 || status=$?
  assert_rejected "$name archive" "$expected" "$status" "$repo/out"
}

expect_success() {
  local name="$1"
  local repo
  repo="$(create_repo "$name")"
  "$name" "$repo"
  commit_repo "$repo"

  local status=0
  (cd "$repo" && "$validator") >"$repo/current.out" 2>&1 || status=$?
  assert_accepted "$name" current "$status" "$repo/current.out"
  status=0
  (cd "$repo" && "$validator" --archive) >"$repo/archive.out" 2>&1 || status=$?
  assert_accepted "$name" archive "$status" "$repo/archive.out"
  if [[ "$name" == allows_synthetic_placeholders_and_appicon ]]; then
    grep -q 'privacy binary exception: approved AppIcon PNG' "$repo/current.out"
    grep -q 'privacy binary exception: approved AppIcon PNG' "$repo/archive.out"
  fi
}

expect_local_identity_failure() {
  local repo
  local team_id="ABCDE""12345"
  repo="$(create_repo local-identity)"
  printf '%s\n' "allowed_signers = [\"$team_id\"]" >"$repo/README.md"
  commit_repo "$repo"

  local status=0
  (cd "$repo" && env \
    MARKLOOK_PRIVACY_SECURITY="$security_stub" \
    MARKLOOK_TEST_TEAM_ID="$team_id" \
    "$validator") >"$repo/out" 2>&1 || status=$?
  assert_rejected 'local identity current' 'local signing TeamIdentifier' "$status" "$repo/out"
}

rejects_docs_evidence_png() {
  local repo="$1"
  mkdir -p "$repo/Docs/evidence"
  touch "$repo/Docs/evidence/foo.png"
}

rejects_newline_docs_evidence_png() {
  local repo="$1"
  mkdir -p "$repo/Docs/evidence"
  touch "$repo/Docs/evidence/"$'probe\n.png'
}

rejects_private_user_images_url() {
  local repo="$1"
  local host="private-user-images.github""usercontent.com"
  printf '%s\n' "![evidence](https://$host/example.png)" >"$repo/README.md"
}

rejects_raw_github_evidence_png_url() {
  local repo="$1"
  local host="raw.github""usercontent.com"
  local path="Docs/evidence/foo"".png"
  printf '%s\n' "https://$host/91wan/marklook-macos/main/$path" >"$repo/README.md"
}

rejects_github_blob_evidence_png_url() {
  local repo="$1"
  local path="Docs/evidence/foo"".png"
  printf '%s\n' "https://github.com/91wan/marklook-macos/blob/main/$path" >"$repo/README.md"
}

rejects_users_path() {
  local repo="$1"
  local path="/Users""/example/private/path.md"
  printf '%s\n' "Could not read $path" >"$repo/README.md"
}

rejects_ruby_users_path() {
  local repo="$1"
  local path="/Users""/example/private/path.md"
  printf '%s\n' "source_path = '$path'" >"$repo/leak.rb"
}

rejects_json_users_path() {
  local repo="$1" path="/Users""/example/private/path.md"
  printf '{"path":"%s"}\n' "$path" >"$repo/config.json"
}

rejects_extensionless_users_path() {
  local repo="$1" path="/Users""/example/private/path.md"
  printf '%s\n' "$path" >"$repo/CONFIG"
}

rejects_space_chinese_users_path() {
  local repo="$1" path="/Users""/example/private/path.md"
  local name=$'notes \xE6\xB5\x8B\xE8\xAF\x95.json'
  printf '%s\n' "$path" >"$repo/$name"
}

rejects_newline_users_path() {
  local repo="$1" path="/Users""/example/private/path.md"
  printf '%s\n' "$path" >"$repo/"$'notes\nfile'
}

rejects_utf8_bom_leak() {
  local repo="$1" path="/Users""/example/private/path.md"
  printf '\357\273\277%s\n' "$path" >"$repo/bom"
}

rejects_utf16le() { printf '\377\376a\000' >"$1/encoding.txt"; }
rejects_utf16be() { printf '\376\377\000a' >"$1/encoding.txt"; }
rejects_utf32le() { printf '\377\376\000\000a\000\000\000' >"$1/encoding.txt"; }
rejects_utf32be() { printf '\000\000\376\377\000\000\000a' >"$1/encoding.txt"; }
rejects_invalid_utf8() { printf '\377bad' >"$1/encoding.txt"; }
rejects_nul() { printf 'safe\000hidden' >"$1/encoding.txt"; }

rejects_unapproved_png() {
  cp "$repo_root/MarkLookApp/Assets.xcassets/AppIcon.appiconset/icon_16x16.png" "$1/other.png"
}

rejects_fake_appicon_text() {
  local repo="$1" path="/Users""/example/private/path.md"
  mkdir -p "$repo/MarkLookApp/Assets.xcassets/AppIcon.appiconset"
  printf '%s\n' "$path" >"$repo/MarkLookApp/Assets.xcassets/AppIcon.appiconset/icon_16x16.png"
}

rejects_fake_appicon_binary() {
  local repo="$1"
  mkdir -p "$repo/MarkLookApp/Assets.xcassets/AppIcon.appiconset"
  printf '\211PNG\015\012\032\012' >"$repo/MarkLookApp/Assets.xcassets/AppIcon.appiconset/icon_16x16.png"
}

rejects_symlink_mode() {
  printf 'safe\n' >"$1/target"
  ln -s target "$1/README.md"
}

rejects_gitlink_mode() {
  printf 'safe\n' >"$1/README.md"
  commit_repo "$1"
  git clone -q --no-hardlinks "$1" "$1/vendor"
  git -C "$1" update-index --add --cacheinfo "160000,$(git -C "$1" rev-parse HEAD),vendor"
}

rejects_archive_missing_export() {
  printf 'safe\n' >"$1/hidden"
  printf 'hidden export-ignore\n' >"$1/.gitattributes"
}

allows_all_utf8_names() {
  local repo="$1" name=$'space \xE6\xB5\x8B\xE8\xAF\x95'
  printf 'safe\n' >"$repo/example.rb"
  printf '{"safe":true}\n' >"$repo/example.json"
  printf 'safe\n' >"$repo/CONFIG"
  printf 'safe\n' >"$repo/$name"
  printf 'safe\n' >"$repo/"$'notes\nfile'
  printf '\357\273\277safe\n' >"$repo/bom"
  touch "$repo/empty" "$repo/empty.png"
}

expect_working_state_rejection() {
  local name="$1" expected="$2" repo status=0
  repo="$(create_repo "$name")"
  mkdir -p "$repo/dir"
  printf 'safe\n' >"$repo/dir/README.md"
  commit_repo "$repo"
  "$name" "$repo"
  (cd "$repo" && "$validator") >"$repo/out" 2>&1 || status=$?
  assert_rejected "$name current" "$expected" "$status" "$repo/out"
  chmod -R u+rwX "$repo"
  status=0
  (cd "$repo" && "$validator" --archive) >"$repo/archive.out" 2>&1 || status=$?
  assert_accepted "$name" archive "$status" "$repo/archive.out"
}

missing_working_file() { rm "$1/dir/README.md"; }
unreadable_working_file() { chmod 000 "$1/dir/README.md"; }
nonregular_working_file() { rm "$1/dir/README.md"; mkdir "$1/dir/README.md"; }
symlink_working_file() { mv "$1/dir/README.md" "$1/target"; ln -s ../target "$1/dir/README.md"; }
symlink_working_ancestor() { mv "$1/dir" "$1/target"; ln -s target "$1/dir"; }
untracked_evidence_png() { mkdir -p "$1/Docs/evidence"; touch "$1/Docs/evidence/untracked.png"; }

unmerged_working_index() {
  local repo="$1" oid
  oid="$(git -C "$repo" rev-parse HEAD:dir/README.md)"
  printf '0 %s\tdir/README.md\n100644 %s 1\tdir/README.md\n100644 %s 2\tdir/README.md\n' \
    "$oid" "$oid" "$oid" | git -C "$repo" update-index --index-info
}

expect_distinct_current_and_head_bytes() {
  local repo status=0 path="/Users""/example/private/path.md"
  repo="$(create_repo distinct-bytes)"
  printf 'safe\n' >"$repo/content.rb"
  commit_repo "$repo"
  printf '%s\n' "$path" >"$repo/content.rb"
  (cd "$repo" && "$validator") >"$repo/current.out" 2>&1 || status=$?
  assert_rejected 'working leak' 'raw local home path' "$status" "$repo/current.out"
  status=0
  (cd "$repo" && "$validator" --archive) >"$repo/archive.out" 2>&1 || status=$?
  assert_accepted 'HEAD safe despite working leak' archive "$status" "$repo/archive.out"
  commit_repo "$repo"
  printf 'safe\n' >"$repo/content.rb"
  status=0
  (cd "$repo" && "$validator") >"$repo/current-safe.out" 2>&1 || status=$?
  assert_accepted 'working safe despite HEAD leak' current "$status" "$repo/current-safe.out"
  status=0
  (cd "$repo" && "$validator" --archive) >"$repo/archive-leak.out" 2>&1 || status=$?
  assert_rejected 'HEAD leak' 'raw local home path' "$status" "$repo/archive-leak.out"
}

# Fault commands are PATH-scoped to validator invocations, never test assertions.
fault_bin="$fixture_root/fault-bin"
mkdir "$fault_bin"
real_git="$(command -v git)"
real_grep="$(command -v grep)"
cat >"$fault_bin/git" <<'STUB'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    ls-files|ls-tree)
      case "$MARKLOOK_TEST_FAULT" in
        inventory-error) echo 'injected inventory error' >&2; exit 74 ;;
        inventory-malformed) printf 'malformed\000'; exit 0 ;;
        inventory-empty-record) printf '\000'; exit 0 ;;
      esac
      ;;
  esac
done
exec "$MARKLOOK_TEST_REAL_GIT" "$@"
STUB
cat >"$fault_bin/grep" <<'STUB'
#!/usr/bin/env bash
case "$MARKLOOK_TEST_FAULT:$1:$2" in
  scan-error:*) exit 2 ;;
  context-probe:-Ei:*) exit 2 ;;
  context-tokens:-nE:'(^|[^A-Z0-9])[A-Z0-9]{10}([^A-Z0-9]|$)') exit 2 ;;
  token-boundaries:-Eo:'(^|[^A-Z0-9])[A-Z0-9]{10}([^A-Z0-9]|$)') exit 2 ;;
  token-extraction:-Eo:'[A-Z0-9]{10}') exit 2 ;;
  identity-extraction:-Eo:'\([A-Z0-9]{10}\)') exit 2 ;;
  identity-scan:-nF:*) exit 2 ;;
esac
exec "$MARKLOOK_TEST_REAL_GREP" "$@"
STUB
cat >"$fault_bin/tar" <<'STUB'
#!/usr/bin/env bash
echo invoked >"$MARKLOOK_TEST_TAR_LOG"
exit 75
STUB
chmod +x "$fault_bin/git" "$fault_bin/grep" "$fault_bin/tar"
bash -n "$fault_bin/git" "$fault_bin/grep" "$fault_bin/tar"

expect_command_error() {
  local fault="$1" mode="$2" expected="$3" repo status=0
  repo="$(create_repo "$fault-$mode")"
  printf 'TeamIdentifier=TEAMID1234\n' >"$repo/README.md"
  commit_repo "$repo"
  set --
  [[ "$mode" == archive ]] && set -- --archive
  # Only mode-admission cases use the tar spy; normal archive extraction is real.
  local bin="$fixture_root/$fault-$mode-bin"
  mkdir "$bin"
  cp "$fault_bin/git" "$fault_bin/grep" "$bin/"
  (cd "$repo" && env PATH="$bin:$PATH" MARKLOOK_TEST_FAULT="$fault" \
    MARKLOOK_TEST_REAL_GIT="$real_git" MARKLOOK_TEST_REAL_GREP="$real_grep" \
    MARKLOOK_PRIVACY_SECURITY="$security_stub" MARKLOOK_TEST_TEAM_ID=0000000000 \
    "$validator" "$@") >"$repo/out" 2>&1 || status=$?
  assert_rejected "$fault $mode" "$expected" "$status" "$repo/out"
}

expect_mode_rejected_before_extraction() {
  local fixture="$1" repo status=0
  repo="$(create_repo "$fixture-before-extraction")"
  "$fixture" "$repo"
  commit_repo "$repo"
  (cd "$repo" && env PATH="$fault_bin:$PATH" MARKLOOK_TEST_FAULT=mode \
    MARKLOOK_TEST_REAL_GIT="$real_git" MARKLOOK_TEST_REAL_GREP="$real_grep" \
    MARKLOOK_TEST_TAR_LOG="$repo/tar.log" "$validator" --archive) >"$repo/out" 2>&1 || status=$?
  assert_rejected "$fixture before extraction" 'unsupported tracked mode' "$status" "$repo/out"
  test ! -e "$repo/tar.log"
}

rejects_teamidentifier() {
  local repo="$1"
  local team_id="ABCDE""12345"
  printf '%s\n' "TeamIdentifier: $team_id" >"$repo/README.md"
}

rejects_contextual_teamidentifier_token() {
  local repo="$1"
  local team_id="ABCDE""12345"
  cat >"$repo/check.sh" <<EOF
assert_no_local_team_ids() {
  grep -Eq '$team_id' output.txt
}
EOF
}

rejects_apple_development_subject() {
  local repo="$1"
  local subject_id="12345""67890"
  local team_id="ABCDE""12345"
  printf '%s\n' "subject=UID=$team_id, CN=Apple Development: $subject_id ($team_id), OU=$team_id, O=Example, C=US" >"$repo/README.md"
}

allows_synthetic_placeholders_and_appicon() {
  local repo="$1"
  mkdir -p "$repo/MarkLookApp/Assets.xcassets/AppIcon.appiconset"
  cp "$repo_root/MarkLookApp/Assets.xcassets/AppIcon.appiconset/icon_16x16.png" \
    "$repo/MarkLookApp/Assets.xcassets/AppIcon.appiconset/icon_16x16.png"
  cat >"$repo/README.md" <<'EOF'
TeamIdentifier: redacted
TeamIdentifier redacted
DEVELOPMENT_TEAM=<TEAM_ID>
TeamIdentifier=TEAMID1234
subject=UID=USERID1234, CN=Apple Development: 0000000000 (CNID123456), OU=TEAMID1234, O=Example Developer, C=US
/tmp/marklook-private/example.md
/tmp/marklook-output/example.md
EOF
}

expect_failure rejects_docs_evidence_png 'Docs/evidence/foo.png'
expect_failure rejects_newline_docs_evidence_png 'runtime evidence image is not allowed'
expect_failure rejects_private_user_images_url 'private GitHub user-content image URL'
expect_failure rejects_raw_github_evidence_png_url 'raw GitHub Docs/evidence image link'
expect_failure rejects_github_blob_evidence_png_url 'GitHub blob Docs/evidence image link'
expect_failure rejects_users_path 'raw local home path'
expect_failure rejects_teamidentifier 'real-looking TeamIdentifier declaration'
expect_failure rejects_contextual_teamidentifier_token 'contextual TeamIdentifier token'
expect_failure rejects_apple_development_subject 'real-looking Apple Development subject'
expect_archive_failure rejects_docs_evidence_png 'Docs/evidence/foo.png'
expect_archive_failure rejects_newline_docs_evidence_png 'runtime evidence image is not allowed'
expect_archive_failure rejects_contextual_teamidentifier_token 'contextual TeamIdentifier token'
expect_local_identity_failure
expect_success allows_synthetic_placeholders_and_appicon
expect_failure rejects_ruby_users_path 'raw local home path'
expect_archive_failure rejects_ruby_users_path 'raw local home path'

for fixture in rejects_json_users_path rejects_extensionless_users_path rejects_space_chinese_users_path \
  rejects_newline_users_path rejects_utf8_bom_leak rejects_fake_appicon_text; do
  expect_failure "$fixture" 'raw local home path'
  expect_archive_failure "$fixture" 'raw local home path'
done
for fixture in rejects_utf16le rejects_utf16be rejects_utf32le rejects_utf32be; do
  expect_failure "$fixture" 'unsupported UTF-16/32 BOM'
  expect_archive_failure "$fixture" 'unsupported UTF-16/32 BOM'
done
for fixture in rejects_invalid_utf8 rejects_nul rejects_unapproved_png rejects_fake_appicon_binary; do
  expect_failure "$fixture" 'unsupported binary or invalid UTF-8'
  expect_archive_failure "$fixture" 'unsupported binary or invalid UTF-8'
done
for fixture in rejects_symlink_mode rejects_gitlink_mode; do
  expect_failure "$fixture" 'unsupported tracked mode'
  expect_archive_failure "$fixture" 'unsupported tracked mode'
  expect_mode_rejected_before_extraction "$fixture"
done
expect_archive_failure rejects_archive_missing_export 'privacy content error'
expect_success allows_all_utf8_names
expect_distinct_current_and_head_bytes
expect_working_state_rejection missing_working_file 'privacy content error'
expect_working_state_rejection unreadable_working_file 'privacy content error'
expect_working_state_rejection nonregular_working_file 'non-regular tracked path'
expect_working_state_rejection symlink_working_file 'symlink traversal'
expect_working_state_rejection symlink_working_ancestor 'symlink traversal'
expect_working_state_rejection unmerged_working_index 'unmerged tracked path'
expect_working_state_rejection untracked_evidence_png 'Docs/evidence/untracked.png'
for mode in current archive; do
  expect_command_error inventory-error "$mode" 'injected inventory error'
  expect_command_error inventory-malformed "$mode" 'privacy inventory error'
  expect_command_error inventory-empty-record "$mode" 'privacy inventory error'
  for fault in scan-error context-probe context-tokens token-boundaries token-extraction identity-extraction identity-scan; do
    expect_command_error "$fault" "$mode" 'privacy scan error'
  done
done

if [[ "$failures" -ne 0 ]]; then
  echo "public repo privacy tests: FAIL ($failures cases)" >&2
  exit 1
fi

echo "public repo privacy tests: PASS"

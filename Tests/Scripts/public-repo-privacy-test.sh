#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
validator="$repo_root/Scripts/validate-public-repo-privacy.sh"

if [[ ! -x "$validator" ]]; then
  echo "error: validator is missing or not executable: $validator" >&2
  exit 1
fi

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

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

expect_failure() {
  local name="$1"
  local expected="$2"
  local repo
  repo="$(create_repo "$name")"
  "$name" "$repo"
  commit_repo "$repo"

  if (cd "$repo" && "$validator") >"$repo/out" 2>&1; then
    echo "error: expected failure for $name" >&2
    exit 1
  fi
  grep -q "$expected" "$repo/out"
}

expect_archive_failure() {
  local name="$1"
  local expected="$2"
  local repo
  repo="$(create_repo "$name")"
  "$name" "$repo"
  commit_repo "$repo"

  if (cd "$repo" && "$validator" --archive) >"$repo/out" 2>&1; then
    echo "error: expected archive failure for $name" >&2
    exit 1
  fi
  grep -q "$expected" "$repo/out"
}

expect_success() {
  local name="$1"
  local repo
  repo="$(create_repo "$name")"
  "$name" "$repo"
  commit_repo "$repo"

  (cd "$repo" && "$validator") >"$repo/current.out" 2>&1
  grep -q 'public repo privacy validation: PASS (current)' "$repo/current.out"
  (cd "$repo" && "$validator" --archive) >"$repo/archive.out" 2>&1
  grep -q 'public repo privacy validation: PASS (archive)' "$repo/archive.out"
}

rejects_docs_evidence_png() {
  local repo="$1"
  mkdir -p "$repo/Docs/evidence"
  touch "$repo/Docs/evidence/foo.png"
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

rejects_teamidentifier() {
  local repo="$1"
  local team_id="ABCDE""12345"
  printf '%s\n' "TeamIdentifier: $team_id" >"$repo/README.md"
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
  touch "$repo/MarkLookApp/Assets.xcassets/AppIcon.appiconset/icon_16x16.png"
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
expect_failure rejects_private_user_images_url 'private GitHub user-content image URL'
expect_failure rejects_raw_github_evidence_png_url 'raw GitHub Docs/evidence image link'
expect_failure rejects_github_blob_evidence_png_url 'GitHub blob Docs/evidence image link'
expect_failure rejects_users_path 'raw local home path'
expect_failure rejects_teamidentifier 'real-looking TeamIdentifier declaration'
expect_failure rejects_apple_development_subject 'real-looking Apple Development subject'
expect_archive_failure rejects_docs_evidence_png 'Docs/evidence/foo.png'
expect_success allows_synthetic_placeholders_and_appicon

echo "public repo privacy tests: PASS"

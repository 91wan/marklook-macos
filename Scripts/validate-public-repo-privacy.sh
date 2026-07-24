#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
usage: Scripts/validate-public-repo-privacy.sh [--archive]

Validate the public repository snapshot for privacy-sensitive evidence.

Options:
  --archive  scan a git archive of HEAD instead of the working tree
USAGE
}

mode="current"
case "${1:-}" in
  "")
    ;;
  --archive)
    mode="archive"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

repo_root="$(git rev-parse --show-toplevel)"
scan_root="$repo_root"
tmpdir=""
list_tmp="$(mktemp -d)"
security_cmd="${MARKLOOK_PRIVACY_SECURITY:-security}"
local_team_ids_file="$list_tmp/local-team-identifiers"

cleanup() {
  if [[ -n "$tmpdir" ]]; then
    rm -rf "$tmpdir"
  fi
  rm -rf "$list_tmp"
}
trap cleanup EXIT

if [[ "$mode" == "archive" ]]; then
  tmpdir="$(mktemp -d)"
  git -C "$repo_root" archive HEAD | tar -x -C "$tmpdir"
  scan_root="$tmpdir"
fi

failures=0

report_violation() {
  local reason="$1"
  local location="$2"
  printf 'privacy violation: %s: %s\n' "$reason" "$location" >&2
  failures=1
}

relative_path() {
  local path="$1"
  printf '%s\n' "${path#"$scan_root"/}"
}

scan_evidence_images() {
  local evidence_dir="$scan_root/Docs/evidence"
  local list_file="$list_tmp/evidence-images"
  if [[ ! -d "$evidence_dir" ]]; then
    return
  fi

  find "$evidence_dir" -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
    -print0 >"$list_file"

  while IFS= read -r -d '' path; do
    report_violation "runtime evidence image is not allowed in Docs/evidence" "$(relative_path "$path")"
  done <"$list_file"
}

is_allowed_teamidentifier_line() {
  local line="$1"
  [[ "$line" == *"TeamIdentifier: redacted"* ]] && return 0
  [[ "$line" == *"TeamIdentifier redacted"* ]] && return 0
  [[ "$line" == *"TeamIdentifier=TEAMID1234"* ]] && return 0
  return 1
}

is_allowed_apple_development_line() {
  local line="$1"
  [[ "$line" == *"CNID123456"* ]] && return 0
  [[ "$line" == *"TEAMID1234"* ]] && return 0
  [[ "$line" == *"USERID1234"* ]] && return 0
  return 1
}

is_allowed_teamidentifier_token() {
  case "$1" in
    TEAMID1234|TEAMTEST01|USERID1234|CNID123456|0000000000)
      return 0
      ;;
  esac
  return 1
}

collect_local_team_identifiers() {
  local identities_file="$list_tmp/signing-identities"
  : >"$local_team_ids_file"

  if ! command -v "$security_cmd" >/dev/null 2>&1; then
    return
  fi
  if ! "$security_cmd" find-identity -v -p codesigning >"$identities_file" 2>/dev/null; then
    return
  fi

  grep -Eo '\([A-Z0-9]{10}\)' "$identities_file" |
    tr -d '()' |
    sort -u >"$local_team_ids_file" || true
}

scan_match() {
  local rel="$1"
  local file="$2"
  local pattern="$3"
  local reason="$4"
  local allow_function="${5:-}"

  local matches
  matches="$(grep -nE "$pattern" "$file" || true)"
  if [[ -z "$matches" ]]; then
    return
  fi

  local match line_no line
  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    line_no="${match%%:*}"
    line="${match#*:}"
    if [[ -n "$allow_function" ]] && "$allow_function" "$line"; then
      continue
    fi
    report_violation "$reason" "$rel:$line_no"
  done <<< "$matches"
}

scan_local_team_identifiers() {
  local rel="$1"
  local file="$2"
  local team_id
  local matches
  local match
  local line_no

  while IFS= read -r team_id; do
    [[ -z "$team_id" ]] && continue
    matches="$(grep -nF "$team_id" "$file" || true)"
    while IFS= read -r match; do
      [[ -z "$match" ]] && continue
      line_no="${match%%:*}"
      report_violation "local signing TeamIdentifier" "$rel:$line_no"
    done <<< "$matches"
  done <"$local_team_ids_file"
}

scan_contextual_teamidentifier_tokens() {
  local rel="$1"
  local file="$2"
  local matches
  local match
  local line_no
  local line
  local tokens
  local token

  if ! grep -Eiq 'TeamIdentifier|team[_ -]?id|local[_ -]?team' "$file"; then
    return
  fi

  matches="$(grep -nE '(^|[^A-Z0-9])[A-Z0-9]{10}([^A-Z0-9]|$)' "$file" || true)"
  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    line_no="${match%%:*}"
    line="${match#*:}"
    tokens="$(printf '%s\n' "$line" |
      grep -Eo '(^|[^A-Z0-9])[A-Z0-9]{10}([^A-Z0-9]|$)' |
      grep -Eo '[A-Z0-9]{10}' || true)"
    while IFS= read -r token; do
      [[ -z "$token" ]] && continue
      if [[ ! "$token" =~ [A-Z] ]] || [[ ! "$token" =~ [0-9] ]]; then
        continue
      fi
      if is_allowed_teamidentifier_token "$token"; then
        continue
      fi
      report_violation "contextual TeamIdentifier token" "$rel:$line_no"
    done <<< "$tokens"
  done <<< "$matches"
}

scan_text_file() {
  local rel="$1"
  local file="$2"

  scan_match "$rel" "$file" '/Users/[A-Za-z0-9._-]+' "raw local home path"
  scan_match "$rel" "$file" 'private-user-images\.githubusercontent\.com' "private GitHub user-content image URL"
  scan_match "$rel" "$file" 'user-images\.githubusercontent\.com' "GitHub user-content image URL"
  scan_match "$rel" "$file" 'github\.com/user-attachments/assets/' "GitHub user attachment image URL"
  scan_match "$rel" "$file" 'raw\.githubusercontent\.com/.*/Docs/evidence/.*\.(png|jpg|jpeg)' "raw GitHub Docs/evidence image link"
  scan_match "$rel" "$file" 'github\.com/.*/blob/.*/Docs/evidence/.*\.(png|jpg|jpeg)' "GitHub blob Docs/evidence image link"
  scan_match "$rel" "$file" 'TeamIdentifier: [A-Z0-9]{10}' "real-looking TeamIdentifier declaration" is_allowed_teamidentifier_line
  scan_match "$rel" "$file" 'TeamIdentifier=[A-Z0-9]{10}' "real-looking TeamIdentifier declaration" is_allowed_teamidentifier_line
  scan_match "$rel" "$file" 'Apple Development: [0-9]{6,}' "real-looking Apple Development subject" is_allowed_apple_development_line
  scan_local_team_identifiers "$rel" "$file"
  scan_contextual_teamidentifier_tokens "$rel" "$file"
}

scan_current_tree_text() {
  local rel file
  local list_file="$list_tmp/current-text-files"
  git -C "$repo_root" ls-files -z -- \
    '*.md' '*.txt' '*.sh' '*.swift' '*.yml' '*.yaml' '*.plist' >"$list_file"

  while IFS= read -r -d '' rel; do
    file="$repo_root/$rel"
    [[ -f "$file" ]] || continue
    scan_text_file "$rel" "$file"
  done <"$list_file"
}

scan_archive_text() {
  local path rel
  local list_file="$list_tmp/archive-text-files"
  find "$scan_root" -type f \
    \( -iname '*.md' -o -iname '*.txt' -o -iname '*.sh' -o -iname '*.swift' -o -iname '*.yml' -o -iname '*.yaml' -o -iname '*.plist' \) \
    -print0 >"$list_file"

  while IFS= read -r -d '' path; do
    rel="$(relative_path "$path")"
    scan_text_file "$rel" "$path"
  done <"$list_file"
}

collect_local_team_identifiers
scan_evidence_images
if [[ "$mode" == "archive" ]]; then
  scan_archive_text
else
  scan_current_tree_text
fi

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi

printf 'public repo privacy validation: PASS (%s)\n' "$mode"

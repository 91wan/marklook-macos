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

inventory="$list_tmp/inventory"
tracked_paths="$list_tmp/tracked-paths"
if [[ "$mode" == "archive" ]]; then
  git -C "$repo_root" ls-tree -rz --full-tree HEAD >"$inventory"
else
  git -C "$repo_root" ls-files --stage -z >"$inventory"
fi

# Admit the entire tracked inventory before archive extraction or content reads.
LC_ALL=en_US.UTF-8 /usr/bin/ruby - "$mode" "$inventory" "$tracked_paths" <<'RUBY'
mode, inventory, output = ARGV
begin
  raw = File.binread(inventory)
  raise "unterminated inventory" unless raw.empty? || raw.end_with?("\0")
  seen = {}
  records = raw.empty? ? [] : raw.split("\0", -1)[0...-1]
  paths = records.map do |record|
    header, path = record.split("\t", 2)
    fields = header.split(" ")
    raise "malformed inventory record" unless path && fields.length == 3 && fields[1..2].all? { |s| !s.empty? }
    file_mode = fields[0]
    object_id = mode == "archive" ? fields[2] : fields[1]
    raise "invalid object ID" unless object_id.match?(/\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/)
    raise "unmerged tracked path: #{path.inspect}" if mode == "current" && fields[2] != "0"
    unless %w[100644 100755].include?(file_mode) && (mode != "archive" || fields[1] == "blob")
      raise "unsupported tracked mode #{file_mode}: #{path.inspect}"
    end
    components = path.split("/", -1)
    if components.any? { |part| part.empty? || part == "." || part == ".." } || seen[path]
      raise "invalid or duplicate tracked path: #{path.inspect}"
    end
    seen[path] = true
    path
  end
  File.binwrite(output, paths.map { |path| path + "\0" }.join)
rescue StandardError => error
  warn "privacy inventory error: #{error.message}"
  exit 1
end
RUBY

if [[ "$mode" == "archive" ]]; then
  tmpdir="$(mktemp -d)"
  git -C "$repo_root" archive HEAD | tar -x -C "$tmpdir"
  scan_root="$tmpdir"
fi

text_files="$list_tmp/text-files"
LC_ALL=en_US.UTF-8 /usr/bin/ruby - "$scan_root" "$tracked_paths" "$list_tmp" "$text_files" <<'RUBY'
require "open3"
root, inventory, staging, output = ARGV
begin
  records = []
  File.binread(inventory).split("\0").each_with_index do |path, index|
    file = root
    parts = path.split("/")
    parts.each_with_index do |part, position|
      file = File.join(file, part)
      stat = File.lstat(file)
      raise "symlink traversal: #{path.inspect}" if stat.symlink?
      expected_type = position == parts.length - 1 ? stat.file? : stat.directory?
      raise "non-regular tracked path: #{path.inspect}" unless expected_type
    end
    if path.match?(%r{\ADocs/evidence/.*\.(png|jpg|jpeg)\z}im)
      raise "runtime evidence image is not allowed in Docs/evidence: #{path.inspect}"
    end
    bytes = File.binread(file)
    if ["\xFF\xFE", "\xFE\xFF", "\x00\x00\xFE\xFF"].any? { |bom| bytes.start_with?(bom.b) }
      raise "unsupported UTF-16/32 BOM: #{path.inspect}"
    end
    appicon = path.match?(%r{\AMarkLookApp/Assets\.xcassets/AppIcon\.appiconset/icon_(16x16|32x32|128x128|256x256|512x512)(@2x)?\.png\z})
    if appicon && bytes.start_with?("\x89PNG\r\n\x1A\n".b)
      mime, _, status = Open3.capture3("/usr/bin/file", "-b", "--mime-type", "-", stdin_data: bytes)
      raise "PNG classification failed: #{path.inspect}" unless status.success?
      if mime.strip == "image/png"
        warn "privacy binary exception: approved AppIcon PNG: #{path.inspect}"
        next
      end
    end
    unless bytes.dup.force_encoding(Encoding::UTF_8).valid_encoding? && !bytes.include?("\0")
      raise "unsupported binary or invalid UTF-8: #{path.inspect}"
    end
    copy = File.join(staging, "text-#{index}")
    File.binwrite(copy, bytes)
    records << path << copy
  end
  File.binwrite(output, records.map { |record| record + "\0" }.join)
rescue StandardError => error
  warn "privacy content error: #{error.message}"
  exit 1
end
RUBY

failures=0

report_violation() {
  local reason="$1"
  local location="$2"
  printf 'privacy violation: %s: %s\n' "$reason" "$location" >&2
  failures=1
}

scan_evidence_images() {
  local evidence_dir="$repo_root/Docs/evidence"
  local list_file="$list_tmp/evidence-images"
  if [[ ! -d "$evidence_dir" ]]; then
    return 0
  fi
  find "$evidence_dir" -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
    -print0 >"$list_file"
  while IFS= read -r -d '' path; do
    report_violation "runtime evidence image is not allowed in Docs/evidence" "${path#"$repo_root"/}"
  done <"$list_file"
}

# A grep no-match is normal; errors must remain visible to the final verdict.
privacy_grep() {
  local location="$1" status=0
  shift
  LC_ALL=C grep "$@" >"$list_tmp/grep-matches" || status=$?
  case "$status" in
    0|1) return "$status" ;;
    *)
      report_violation "privacy scan error (grep exit $status)" "$location"
      return 2
      ;;
  esac
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

  if privacy_grep 'signing identity token extraction' -Eo '\([A-Z0-9]{10}\)' "$identities_file"; then
    tr -d '()' <"$list_tmp/grep-matches" | sort -u >"$local_team_ids_file"
  fi
}

scan_match() {
  local rel="$1"
  local file="$2"
  local pattern="$3"
  local reason="$4"
  local allow_function="${5:-}"

  local matches
  if privacy_grep "$rel" -nE "$pattern" "$file"; then
    matches="$(<"$list_tmp/grep-matches")"
  else
    return 0
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
    if privacy_grep "$rel" -nF "$team_id" "$file"; then
      matches="$(<"$list_tmp/grep-matches")"
    else
      continue
    fi
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

  if ! privacy_grep "$rel" -Ei 'TeamIdentifier|team[_ -]?id|local[_ -]?team' "$file"; then
    return 0
  fi

  if privacy_grep "$rel" -nE '(^|[^A-Z0-9])[A-Z0-9]{10}([^A-Z0-9]|$)' "$file"; then
    matches="$(<"$list_tmp/grep-matches")"
  else
    return 0
  fi
  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    line_no="${match%%:*}"
    line="${match#*:}"
    if privacy_grep "$rel:$line_no" -Eo '(^|[^A-Z0-9])[A-Z0-9]{10}([^A-Z0-9]|$)' <<<"$line"; then
      tokens="$(<"$list_tmp/grep-matches")"
    else
      continue
    fi
    if privacy_grep "$rel:$line_no" -Eo '[A-Z0-9]{10}' <<<"$tokens"; then
      tokens="$(<"$list_tmp/grep-matches")"
    else
      continue
    fi
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

collect_local_team_identifiers
if [[ "$mode" == "current" ]]; then
  scan_evidence_images
fi
while IFS= read -r -d '' rel; do
  IFS= read -r -d '' file
  scan_text_file "$rel" "$file"
done <"$text_files"

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi

printf 'public repo privacy validation: PASS (%s)\n' "$mode"

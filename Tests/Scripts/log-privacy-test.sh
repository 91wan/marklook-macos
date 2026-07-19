#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
validator="$repo_root/Scripts/validate-log-privacy.sh"

"$validator"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

make_fixture() {
  local root="$1"
  local preview_privacy="$2"
  local thumbnail_privacy="$3"

  mkdir -p "$root/PreviewExtension" "$root/ThumbnailExtension"
  printf 'logger.info("file=\\(fileName, privacy: .%s)")\n' "$preview_privacy" \
    >"$root/PreviewExtension/PreviewViewController.swift"
  printf 'logger.info("file=\\(fileName, privacy: .%s)")\n' "$thumbnail_privacy" \
    >"$root/ThumbnailExtension/ThumbnailProvider.swift"
}

valid_fixture="$fixture_root/valid"
make_fixture "$valid_fixture" private private
MARKLOOK_LOG_PRIVACY_REPO_ROOT="$valid_fixture" "$validator"

public_fixture="$fixture_root/public"
make_fixture "$public_fixture" public private
if MARKLOOK_LOG_PRIVACY_REPO_ROOT="$public_fixture" "$validator" >"$fixture_root/public.out" 2>&1; then
  echo "error: validator accepted a public filename log" >&2
  exit 1
fi
grep -q 'must not use public privacy' "$fixture_root/public.out"

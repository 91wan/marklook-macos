#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="${MARKLOOK_LOG_PRIVACY_REPO_ROOT:-$(cd "$script_dir/.." && pwd -P)}"
public_pattern='fileName,[[:space:]]*privacy:[[:space:]]*\.public'
private_pattern='fileName,[[:space:]]*privacy:[[:space:]]*\.private'

sources=(
  "$repo_root/PreviewExtension/PreviewViewController.swift"
  "$repo_root/ThumbnailExtension/ThumbnailProvider.swift"
)

for source in "${sources[@]}"; do
  test -f "$source"

  if matches="$(grep -nE "$public_pattern" "$source" || true)" && [[ -n "$matches" ]]; then
    printf '%s\n' "$matches" >&2
    echo "error: filename OSLog interpolation must not use public privacy: $source" >&2
    exit 1
  fi

  if ! grep -qE "$private_pattern" "$source"; then
    echo "error: expected private filename OSLog interpolation: $source" >&2
    exit 1
  fi
done

echo "OSLog filename privacy validation: PASS"

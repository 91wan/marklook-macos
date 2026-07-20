#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
cd "$repo_root"

security_cmd="${MARKLOOK_RELEASE_SECURITY:-security}"
identities_file="$(mktemp)"
trap 'rm -f "$identities_file"' EXIT

if ! "$security_cmd" find-identity -p codesigning -v >"$identities_file"; then
  echo "error: failed to inspect code signing identities" >&2
  exit 1
fi

apple_development_line="$(grep '"Apple Development:' "$identities_file" | head -n 1 || true)"
developer_id_line="$(grep '"Developer ID Application:' "$identities_file" | head -n 1 || true)"

if [ -n "$apple_development_line" ]; then
  echo "Apple Development identity: FOUND"
else
  echo "Apple Development identity: NOT FOUND"
fi

if [ -n "$developer_id_line" ]; then
  echo "Developer ID Application identity: FOUND"
  echo "Developer ID Application identity summary: Developer ID Application: <redacted>"
  echo "Next: Scripts/package-developer-id.sh --developer-id"
else
  echo "Developer ID Application identity: NOT FOUND"
  echo "Public binary release lane cannot proceed."
  echo "Source/local-validation remains available."
  exit 1
fi

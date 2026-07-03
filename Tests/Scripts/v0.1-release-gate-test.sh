#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
legacy_gate="$repo_root/Scripts/validate-v0.1.0-release-candidate.sh"

if [ ! -x "$legacy_gate" ]; then
  echo "error: legacy release candidate wrapper is not executable: $legacy_gate" >&2
  exit 1
fi

MARKLOOK_RC_GATE="$legacy_gate" exec "$script_dir/release-candidate-gate-test.sh" "$@"

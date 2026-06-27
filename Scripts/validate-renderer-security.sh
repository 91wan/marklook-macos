#!/usr/bin/env bash
set -euo pipefail

fixture="${1:-}"
if [ -z "$fixture" ]; then
  echo "usage: Scripts/validate-renderer-security.sh path/to/rendered.html" >&2
  exit 64
fi

! grep -i '<script' "$fixture"
! grep -i '<iframe' "$fixture"
! grep -i '<object' "$fixture"
! grep -i '<embed' "$fixture"
! grep -i 'onerror=' "$fixture"
! grep -i 'onclick=' "$fixture"
! grep -i 'onload=' "$fixture"
! grep -i 'javascript:' "$fixture"
! grep -i 'src="https://' "$fixture"
! grep -i "src='https://" "$fixture"
! grep -i 'src="http://' "$fixture"
! grep -i "src='http://" "$fixture"

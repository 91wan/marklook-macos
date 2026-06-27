#!/usr/bin/env bash
set -euo pipefail

fixture="${1:-}"
if [ -z "$fixture" ]; then
  echo "usage: Scripts/validate-renderer-security.sh path/to/rendered.html" >&2
  exit 64
fi

! grep -qi '<script' "$fixture"
! grep -qi '<iframe' "$fixture"
! grep -qi '<object' "$fixture"
! grep -qi '<embed' "$fixture"
! grep -qi 'onerror=' "$fixture"
! grep -qi 'onclick=' "$fixture"
! grep -qi 'onload=' "$fixture"
! grep -qi 'javascript:' "$fixture"
! grep -qi 'vbscript:' "$fixture"
! grep -qi 'data:text/html' "$fixture"
! grep -qi 'data:image' "$fixture"
! grep -qi '<a[[:space:]]' "$fixture"
! grep -qi 'href=' "$fixture"
! grep -qi 'href="http://' "$fixture"
! grep -qi 'href="https://' "$fixture"
! grep -qi 'href="file://' "$fixture"
! grep -qi 'href="x-apple' "$fixture"
! grep -qi 'href="itms-services' "$fixture"
! grep -qi 'src="http://' "$fixture"
! grep -qi 'src="https://' "$fixture"
! grep -qi 'src="file://' "$fixture"

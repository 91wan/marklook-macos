#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: Scripts/diagnose-file.sh path/to/file.md" >&2
  exit 64
fi

mdls -name kMDItemContentType "$1"
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook || true

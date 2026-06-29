#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
  echo "usage: DEVELOPMENT_TEAM=<TEAM_ID> Scripts/build-local-apple-development.sh" >&2
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
cd "$repo_root"

security find-identity -p codesigning -v

rm -rf .build/LocalDerivedData

xcodegen generate

xcodebuild \
  -project MarkLook.xcodeproj \
  -scheme MarkLook \
  -configuration Debug \
  -derivedDataPath .build/LocalDerivedData \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  clean build

codesign -dv --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
codesign --verify --deep --strict --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app

#!/usr/bin/env bash
set -euo pipefail

identities="$(mktemp)"
trap 'rm -f "$identities"' EXIT

security find-identity -p codesigning -v | tee "$identities"

if grep -q '0 valid identities found' "$identities"; then
  echo
  echo "No valid signing identities found."
  echo "Open Xcode -> Settings -> Accounts -> Add Apple ID -> Manage Certificates -> Apple Development."
  exit 1
fi

apple_development_line="$(grep '"Apple Development:' "$identities" | head -n 1 || true)"
developer_id_line="$(grep '"Developer ID Application:' "$identities" | head -n 1 || true)"

if [ -n "$apple_development_line" ]; then
  team_id="$(printf '%s\n' "$apple_development_line" | sed -n 's/.*(\([A-Z0-9][A-Z0-9]*\)).*/\1/p')"
  echo
  echo "Found Apple Development identity."
  echo "Use:"
  if [ -n "$team_id" ]; then
    echo "DEVELOPMENT_TEAM=$team_id Scripts/build-local-apple-development.sh"
  else
    echo "DEVELOPMENT_TEAM=<TEAM_ID> Scripts/build-local-apple-development.sh"
  fi
  echo "Scripts/validate-signed-quicklook.sh --development .build/LocalDerivedData/Build/Products/Debug/MarkLook.app"
fi

if [ -n "$developer_id_line" ]; then
  echo
  echo "Found Developer ID Application identity."
  echo "Release validation still requires hardened runtime, notarization, stapling, and --release smoke validation."
fi

if [ -z "$apple_development_line" ] && [ -z "$developer_id_line" ]; then
  echo
  echo "No Apple Development or Developer ID Application identity detected."
  echo "Open Xcode -> Settings -> Accounts -> Add Apple ID -> Manage Certificates -> Apple Development."
  exit 1
fi

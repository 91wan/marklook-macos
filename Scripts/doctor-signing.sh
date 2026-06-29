#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=Scripts/signing-team-id.sh
. "$SCRIPT_DIR/signing-team-id.sh"

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
  apple_development_identity="$(marklook_identity_name_from_identity_line "$apple_development_line")"
  cn_team_id="$(marklook_team_id_from_identity_line "$apple_development_line")"
  cert_subject=""
  team_id=""

  if [ -n "$apple_development_identity" ]; then
    cert_subject="$(
      security find-certificate -c "$apple_development_identity" -p 2>/dev/null |
        openssl x509 -noout -subject 2>/dev/null || true
    )"
    team_id="$(marklook_team_id_from_subject "$cert_subject")"
  fi

  echo
  echo "Found Apple Development identity:"
  if [ -n "$apple_development_identity" ]; then
    echo "$apple_development_identity"
  else
    echo "$apple_development_line"
  fi
  if [ -n "$team_id" ]; then
    echo
    echo "Detected certificate OU candidate:"
    echo "$team_id"
    if [ -n "$cn_team_id" ] && [ "$cn_team_id" != "$team_id" ]; then
      echo
      echo "Note: identity CN also contains '$cn_team_id', but certificate OU / TeamIdentifier candidate is '$team_id'."
    fi
  fi
  echo "Use:"
  if [ -n "$team_id" ]; then
    echo "DEVELOPMENT_TEAM=$team_id Scripts/build-local-apple-development.sh"
  else
    echo "Unable to derive Team ID safely. Get Team ID from Xcode -> Settings -> Accounts or a successful codesign TeamIdentifier."
  fi
  echo
  echo "After build, verify:"
  echo "codesign -dv --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app"
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

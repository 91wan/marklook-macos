#!/usr/bin/env bash
set -euo pipefail

reject_marklook_swift_match() {
  local pattern="$1"
  local matches
  matches="$(git grep -n "${pattern}" -- MarkLookApp/*.swift MarkLookApp/Diagnostics/*.swift || true)"
  if [[ -n "${matches}" ]]; then
    printf '%s\n' "${matches}"
    exit 1
  fi
}

# Host app remains local and diagnostic.
reject_marklook_swift_match "import WebKit"
reject_marklook_swift_match "WKWebView"
reject_marklook_swift_match "URLSession"
reject_marklook_swift_match "http://"
reject_marklook_swift_match "https://"

# No editor surface.
reject_marklook_swift_match "TextEditor("
reject_marklook_swift_match "saveDocument"
reject_marklook_swift_match "write(to:"

# Required diagnostics components.
test -f MarkLookApp/Diagnostics/DiagnosticsViewModel.swift
test -f MarkLookApp/Diagnostics/ExtensionRegistrationStatus.swift
test -f MarkLookApp/Diagnostics/FileDiagnostic.swift
test -f MarkLookApp/Diagnostics/DiagnosticReport.swift

# Entitlements.
grep -q "com.apple.security.app-sandbox" MarkLookApp/MarkLook.entitlements
grep -q "com.apple.security.files.user-selected.read-only" MarkLookApp/MarkLook.entitlements
! grep -q "com.apple.security.network.client" MarkLookApp/MarkLook.entitlements

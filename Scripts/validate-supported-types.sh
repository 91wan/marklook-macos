#!/usr/bin/env bash
set -euo pipefail

preview_types="$(mktemp)"
thumbnail_types="$(mktemp)"
swift_types="$(mktemp)"
app_types="$(mktemp)"
trap 'rm -f "$preview_types" "$thumbnail_types" "$swift_types" "$app_types"' EXIT

/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLSupportedContentTypes' PreviewExtension/Info.plist |
  awk '/^[[:space:]]+[[:alnum:].-]+$/ { gsub(/^[[:space:]]+/, ""); print }' > "$preview_types"

/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLSupportedContentTypes' ThumbnailExtension/Info.plist |
  awk '/^[[:space:]]+[[:alnum:].-]+$/ { gsub(/^[[:space:]]+/, ""); print }' > "$thumbnail_types"

sed -n '/static let contentTypes/,/]/p' Shared/SupportedTypes.swift |
  grep -Eo '"[^"]+"' |
  tr -d '"' > "$swift_types"

ruby <<'RUBY' > "$app_types"
require "yaml"

project = YAML.load_file("project.yml")
properties = project.dig("targets", "MarkLook", "info", "properties") || {}
document_types = properties["CFBundleDocumentTypes"] || []

unless document_types.length == 1
  warn "expected exactly one MarkLook CFBundleDocumentTypes entry"
  exit 1
end

document_type = document_types.first
unless document_type["CFBundleTypeRole"] == "Viewer"
  warn "expected MarkLook document role Viewer"
  exit 1
end

unless document_type["LSHandlerRank"] == "Alternate"
  warn "expected MarkLook LSHandlerRank Alternate"
  exit 1
end

Array(document_type["LSItemContentTypes"]).each { |type| puts type }
RUBY

diff "$preview_types" "$thumbnail_types"
diff "$preview_types" "$swift_types"
diff "$preview_types" "$app_types"

grep -q 'io.typora.markdown' "$preview_types"
grep -q 'com.rstudio.rmarkdown' "$preview_types"
grep -q 'org.quarto.qmarkdown' "$preview_types"

! grep -q 'public.plain-text' "$preview_types"
! grep -q 'public.plain-text' "$thumbnail_types"
! grep -q 'public.plain-text' "$swift_types"

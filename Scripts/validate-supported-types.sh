#!/usr/bin/env bash
set -euo pipefail

preview_types="$(mktemp)"
thumbnail_types="$(mktemp)"
swift_types="$(mktemp)"
trap 'rm -f "$preview_types" "$thumbnail_types" "$swift_types"' EXIT

/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLSupportedContentTypes' PreviewExtension/Info.plist |
  awk '/^[[:space:]]+[[:alnum:].-]+$/ { gsub(/^[[:space:]]+/, ""); print }' > "$preview_types"

/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLSupportedContentTypes' ThumbnailExtension/Info.plist |
  awk '/^[[:space:]]+[[:alnum:].-]+$/ { gsub(/^[[:space:]]+/, ""); print }' > "$thumbnail_types"

sed -n '/static let contentTypes/,/]/p' Shared/SupportedTypes.swift |
  grep -Eo '"[^"]+"' |
  tr -d '"' > "$swift_types"

diff "$preview_types" "$thumbnail_types"
diff "$preview_types" "$swift_types"

grep -q 'io.typora.markdown' "$preview_types"
grep -q 'com.rstudio.rmarkdown' "$preview_types"
grep -q 'org.quarto.qmarkdown' "$preview_types"

! grep -q 'public.plain-text' "$preview_types"
! grep -q 'public.plain-text' "$thumbnail_types"
! grep -q 'public.plain-text' "$swift_types"

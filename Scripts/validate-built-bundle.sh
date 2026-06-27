#!/usr/bin/env bash
set -euo pipefail

app="${1:-}"
if [ -z "$app" ]; then
  echo "usage: Scripts/validate-built-bundle.sh path/to/MarkLook.app" >&2
  exit 64
fi

preview="$app/Contents/PlugIns/MarkLookPreview.appex"
thumbnail="$app/Contents/PlugIns/MarkLookThumbnail.appex"

test -d "$app"
test -d "$preview"
test -d "$thumbnail"

plutil -lint "$app/Contents/Info.plist"
plutil -lint "$preview/Contents/Info.plist"
plutil -lint "$thumbnail/Contents/Info.plist"

/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" | grep -q '^com.91wan.MarkLook$'
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$preview/Contents/Info.plist" | grep -q '^com.91wan.MarkLook.Preview$'
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$thumbnail/Contents/Info.plist" | grep -q '^com.91wan.MarkLook.Thumbnail$'

preview_types="$(mktemp)"
thumbnail_types="$(mktemp)"
trap 'rm -f "$preview_types" "$thumbnail_types"' EXIT

/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLSupportedContentTypes' "$preview/Contents/Info.plist" |
  awk '/^[[:space:]]+[[:alnum:].-]+$/ { gsub(/^[[:space:]]+/, ""); print }' > "$preview_types"

/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLSupportedContentTypes' "$thumbnail/Contents/Info.plist" |
  awk '/^[[:space:]]+[[:alnum:].-]+$/ { gsub(/^[[:space:]]+/, ""); print }' > "$thumbnail_types"

diff "$preview_types" "$thumbnail_types"

grep -q 'io.typora.markdown' "$preview_types"
grep -q 'com.rstudio.rmarkdown' "$preview_types"
grep -q 'org.quarto.qmarkdown' "$preview_types"

! grep -q 'public.plain-text' "$preview_types"
! grep -q 'public.plain-text' "$thumbnail_types"

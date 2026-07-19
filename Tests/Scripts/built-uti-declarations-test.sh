#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
fixture_app="$fixture_root/MarkLook.app"

mkdir -p \
  "$fixture_app/Contents/PlugIns/MarkLookPreview.appex/Contents" \
  "$fixture_app/Contents/PlugIns/MarkLookThumbnail.appex/Contents"
cp "$repo_root/MarkLookApp/Info.plist" "$fixture_app/Contents/Info.plist"
cp "$repo_root/PreviewExtension/Info.plist" \
  "$fixture_app/Contents/PlugIns/MarkLookPreview.appex/Contents/Info.plist"
cp "$repo_root/ThumbnailExtension/Info.plist" \
  "$fixture_app/Contents/PlugIns/MarkLookThumbnail.appex/Contents/Info.plist"

"$repo_root/Scripts/validate-built-uti-declarations.rb" "$fixture_app" >/dev/null

ruby -rjson -ropen3 - "$fixture_app" <<'RUBY'
app = ARGV.fetch(0)
paths = [
  File.join(app, "Contents", "Info.plist"),
  File.join(app, "Contents", "PlugIns", "MarkLookPreview.appex", "Contents", "Info.plist"),
  File.join(app, "Contents", "PlugIns", "MarkLookThumbnail.appex", "Contents", "Info.plist")
]

paths.each do |path|
  output, status = Open3.capture2("/usr/bin/plutil", "-convert", "json", "-o", "-", path)
  abort "could not read fixture plist" unless status.success?
  plist = JSON.parse(output)
  Array(plist["UTExportedTypeDeclarations"]).reverse!
  Array(plist["UTImportedTypeDeclarations"]).reverse!
  Array(plist["CFBundleDocumentTypes"]).each do |entry|
    Array(entry["LSItemContentTypes"]).reverse!
  end
  Array(plist.dig("NSExtension", "NSExtensionAttributes", "QLSupportedContentTypes")).reverse!
  File.write(path, JSON.generate(plist))
  system("/usr/bin/plutil", "-convert", "xml1", path) || abort("could not write fixture plist")
end
RUBY

"$repo_root/Scripts/validate-built-uti-declarations.rb" "$fixture_app" >/dev/null

ruby -rjson -ropen3 - "$fixture_app" com.91wan.marklook.mdx <<'RUBY'
app, removed_type = ARGV
paths = [
  File.join(app, "Contents", "Info.plist"),
  File.join(app, "Contents", "PlugIns", "MarkLookPreview.appex", "Contents", "Info.plist"),
  File.join(app, "Contents", "PlugIns", "MarkLookThumbnail.appex", "Contents", "Info.plist")
]

paths.each do |path|
  output, status = Open3.capture2("/usr/bin/plutil", "-convert", "json", "-o", "-", path)
  abort "could not read fixture plist" unless status.success?
  plist = JSON.parse(output)
  Array(plist["CFBundleDocumentTypes"]).each do |entry|
    Array(entry["LSItemContentTypes"]).delete(removed_type)
  end
  Array(plist.dig("NSExtension", "NSExtensionAttributes", "QLSupportedContentTypes")).delete(removed_type)
  File.write(path, JSON.generate(plist))
  system("/usr/bin/plutil", "-convert", "xml1", path) || abort("could not write fixture plist")
end
RUBY

failure_output="$fixture_root/failure-output.txt"
if "$repo_root/Scripts/validate-built-uti-declarations.rb" \
  "$fixture_app" >"$failure_output" 2>&1; then
  echo "expected built UTI validation to reject synchronized content-type deletion" >&2
  exit 1
fi

grep -q 'built app document content types differs' "$failure_output"

echo "built UTI declaration validator tests passed"

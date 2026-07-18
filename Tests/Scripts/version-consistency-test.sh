#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
validator="${MARKLOOK_VERSION_VALIDATOR:-$repo_root/Scripts/validate-version-consistency.rb}"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

cp "$repo_root/project.yml" "$fixture_root/project.yml"
for plist_path in MarkLookApp/Info.plist PreviewExtension/Info.plist ThumbnailExtension/Info.plist; do
  mkdir -p "$fixture_root/$(dirname "$plist_path")"
  cp "$repo_root/$plist_path" "$fixture_root/$plist_path"
done

"$validator" "$fixture_root" >"$fixture_root/pass.out"
grep -Eq '^MarkLook version consistency: .+ \(.+\): PASS$' "$fixture_root/pass.out"

/usr/libexec/PlistBuddy \
  -c 'Set :CFBundleVersion 999' \
  "$fixture_root/PreviewExtension/Info.plist"

if "$validator" "$fixture_root" >"$fixture_root/plist-mismatch.out" 2>&1; then
  echo "error: expected mismatched Info.plist version to fail" >&2
  exit 1
fi
grep -q 'MarkLookPreview Info.plist version' "$fixture_root/plist-mismatch.out"

cp "$repo_root/PreviewExtension/Info.plist" "$fixture_root/PreviewExtension/Info.plist"
ruby -ryaml -e '
  path = ARGV.fetch(0)
  project = YAML.safe_load(File.read(path), aliases: false)
  project["targets"]["MarkLookThumbnail"]["info"]["properties"]["CFBundleVersion"] = "999"
  File.write(path, YAML.dump(project))
' "$fixture_root/project.yml"

if "$validator" "$fixture_root" >"$fixture_root/target-mismatch.out" 2>&1; then
  echo "error: expected mismatched production target version to fail" >&2
  exit 1
fi
grep -q 'production target versions differ' "$fixture_root/target-mismatch.out"

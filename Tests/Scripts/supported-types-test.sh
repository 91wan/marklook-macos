#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
fixture_parent="$(mktemp -d)"
trap 'rm -rf "$fixture_parent"' EXIT

make_fixture() {
  local fixture_root="$1"
  mkdir -p \
    "$fixture_root/Docs" \
    "$fixture_root/MarkLookApp" \
    "$fixture_root/PreviewExtension" \
    "$fixture_root/Shared" \
    "$fixture_root/ThumbnailExtension"

  cp "$repo_root/project.yml" "$fixture_root/project.yml"
  cp "$repo_root/Docs/architecture.md" "$fixture_root/Docs/architecture.md"
  cp "$repo_root/MarkLookApp/Info.plist" "$fixture_root/MarkLookApp/Info.plist"
  cp "$repo_root/PreviewExtension/Info.plist" "$fixture_root/PreviewExtension/Info.plist"
  cp "$repo_root/Shared/SupportedTypes.swift" "$fixture_root/Shared/SupportedTypes.swift"
  cp "$repo_root/ThumbnailExtension/Info.plist" "$fixture_root/ThumbnailExtension/Info.plist"
}

remove_imported_declaration() {
  local fixture_root="$1"
  local identifier="$2"

  ruby - "$fixture_root/project.yml" "$fixture_root/MarkLookApp/Info.plist" "$identifier" <<'RUBY'
require "json"
require "open3"
require "yaml"

project_path, plist_path, identifier = ARGV
project = YAML.load_file(project_path)
properties = project.fetch("targets").fetch("MarkLook").fetch("info").fetch("properties")
properties.fetch("UTImportedTypeDeclarations").reject! do |entry|
  entry["UTTypeIdentifier"] == identifier
end
File.write(project_path, YAML.dump(project))

output, status = Open3.capture2(
  "/usr/bin/plutil",
  "-convert",
  "json",
  "-o",
  "-",
  plist_path
)
abort "could not read fixture plist" unless status.success?
plist = JSON.parse(output)
plist.fetch("UTImportedTypeDeclarations").reject! do |entry|
  entry["UTTypeIdentifier"] == identifier
end
File.write(plist_path, JSON.generate(plist))
system("/usr/bin/plutil", "-convert", "xml1", plist_path) || abort("could not write fixture plist")
RUBY
}

qmd_fixture="$fixture_parent/qmd"
make_fixture "$qmd_fixture"

MARKLOOK_SUPPORTED_TYPES_REPO_ROOT="$qmd_fixture" \
  "$repo_root/Scripts/validate-supported-types.sh" >/dev/null

remove_imported_declaration "$qmd_fixture" "org.quarto.qmarkdown"

qmd_failure_output="$qmd_fixture/failure-output.txt"
if MARKLOOK_SUPPORTED_TYPES_REPO_ROOT="$qmd_fixture" \
  "$repo_root/Scripts/validate-supported-types.sh" >"$qmd_failure_output" 2>&1; then
  echo "expected supported-types validation to reject an unrouted .qmd extension" >&2
  exit 1
fi

grep -q 'advertised extensions without routing declarations: qmd' "$qmd_failure_output"

markdown_fixture="$fixture_parent/markdown"
make_fixture "$markdown_fixture"
remove_imported_declaration "$markdown_fixture" "net.daringfireball.markdown"

markdown_failure_output="$markdown_fixture/failure-output.txt"
if MARKLOOK_SUPPORTED_TYPES_REPO_ROOT="$markdown_fixture" \
  "$repo_root/Scripts/validate-supported-types.sh" >"$markdown_failure_output" 2>&1; then
  echo "expected supported-types validation to reject unrouted Markdown extensions" >&2
  exit 1
fi

grep -q 'advertised extensions without routing declarations: markdown, md' "$markdown_failure_output"

public_markdown_fixture="$fixture_parent/public-markdown"
make_fixture "$public_markdown_fixture"
ruby - "$public_markdown_fixture/Docs/architecture.md" <<'RUBY'
path = ARGV.fetch(0)
File.open(path, "a") { |file| file.puts("- `public.markdown`") }
RUBY

public_markdown_failure_output="$public_markdown_fixture/failure-output.txt"
if MARKLOOK_SUPPORTED_TYPES_REPO_ROOT="$public_markdown_fixture" \
  "$repo_root/Scripts/validate-supported-types.sh" >"$public_markdown_failure_output" 2>&1; then
  echo "expected supported-types validation to reject public.markdown" >&2
  exit 1
fi

grep -q 'unsupported public.markdown UTI remains in Docs/architecture.md' "$public_markdown_failure_output"

echo "supported-types validator tests passed"

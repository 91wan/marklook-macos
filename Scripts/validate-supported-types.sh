#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="${MARKLOOK_SUPPORTED_TYPES_REPO_ROOT:-$(cd "$script_dir/.." && pwd -P)}"

ruby - "$repo_root" <<'RUBY'
require "json"
require "open3"
require "set"
require "yaml"

repo_root = ARGV.fetch(0)

def fail_validation(message)
  warn "error: #{message}"
  exit 1
end

def load_plist(path)
  output, error, status = Open3.capture3(
    "/usr/bin/plutil",
    "-convert",
    "json",
    "-o",
    "-",
    path
  )
  fail_validation("could not read #{path}: #{error.strip}") unless status.success?
  JSON.parse(output)
rescue JSON::ParserError => error
  fail_validation("could not parse #{path}: #{error.message}")
end

def swift_string_array(source, name)
  match = source.match(/static let #{Regexp.escape(name)}\s*=\s*\[(.*?)\]/m)
  fail_validation("Shared/SupportedTypes.swift is missing #{name}") unless match
  match[1].scan(/"([^"]+)"/).flatten
end

def assert_equal(label, expected, actual)
  return if expected == actual
  fail_validation("#{label} differs\nexpected: #{expected.inspect}\nactual:   #{actual.inspect}")
end

def declarations_by_identifier(properties)
  declarations = {}
  {
    "exported" => Array(properties["UTExportedTypeDeclarations"]),
    "imported" => Array(properties["UTImportedTypeDeclarations"])
  }.each do |kind, entries|
    entries.each do |entry|
      identifier = entry["UTTypeIdentifier"]
      fail_validation("#{kind} UTI declaration is missing UTTypeIdentifier") if identifier.to_s.empty?
      fail_validation("duplicate UTI declaration: #{identifier}") if declarations.key?(identifier)
      declarations[identifier] = entry.merge("_kind" => kind)
    end
  end
  declarations
end

def filename_extensions(declaration)
  Array(declaration.dig("UTTypeTagSpecification", "public.filename-extension"))
end

project_path = File.join(repo_root, "project.yml")
project = YAML.load_file(project_path)
properties = project.dig("targets", "MarkLook", "info", "properties") || {}
document_types = Array(properties["CFBundleDocumentTypes"])
fail_validation("expected exactly one MarkLook CFBundleDocumentTypes entry") unless document_types.length == 1

document_type = document_types.first
assert_equal("MarkLook document role", "Viewer", document_type["CFBundleTypeRole"])
assert_equal("MarkLook handler rank", "Alternate", document_type["LSHandlerRank"])

app_plist = load_plist(File.join(repo_root, "MarkLookApp", "Info.plist"))
preview_plist = load_plist(File.join(repo_root, "PreviewExtension", "Info.plist"))
thumbnail_plist = load_plist(File.join(repo_root, "ThumbnailExtension", "Info.plist"))
swift_source = File.read(File.join(repo_root, "Shared", "SupportedTypes.swift"))

swift_types = swift_string_array(swift_source, "contentTypes")
swift_extensions = swift_string_array(swift_source, "fileExtensions")
expected_content_types = %w[
  net.daringfireball.markdown
  net.ia.markdown
  io.typora.markdown
  com.apple.dt.document.markdown
  com.rstudio.rmarkdown
  org.quarto.qmarkdown
  com.91wan.marklook.markdown-alias
  com.91wan.marklook.mdx
]
project_types = Array(document_type["LSItemContentTypes"])
app_document_types = Array(app_plist["CFBundleDocumentTypes"])
fail_validation("generated app plist must contain exactly one document type") unless app_document_types.length == 1
app_types = Array(app_document_types.first["LSItemContentTypes"])
preview_types = Array(preview_plist.dig("NSExtension", "NSExtensionAttributes", "QLSupportedContentTypes"))
thumbnail_types = Array(thumbnail_plist.dig("NSExtension", "NSExtensionAttributes", "QLSupportedContentTypes"))

assert_equal("Preview and Thumbnail supported content types", preview_types, thumbnail_types)
assert_equal("supported content types exact contract", expected_content_types, swift_types)
assert_equal("Preview plist and Shared supported content types", preview_types, swift_types)
assert_equal("Preview plist and project document content types", preview_types, project_types)
assert_equal("Preview plist and generated app document content types", preview_types, app_types)
assert_equal("generated app document role", "Viewer", app_document_types.first["CFBundleTypeRole"])
assert_equal("generated app handler rank", "Alternate", app_document_types.first["LSHandlerRank"])

%w[UTExportedTypeDeclarations UTImportedTypeDeclarations].each do |key|
  assert_equal("project and generated app #{key}", Array(properties[key]), Array(app_plist[key]))
end

fail_validation("supported content types must not claim public.plain-text") if swift_types.include?("public.plain-text")
%w[com.unknown.md net.daringfireball public.markdown].each do |placeholder|
  fail_validation("unsupported placeholder UTI remains: #{placeholder}") if swift_types.include?(placeholder)
end

publication_paths = %w[
  project.yml
  Shared/SupportedTypes.swift
  MarkLookApp/Info.plist
  PreviewExtension/Info.plist
  ThumbnailExtension/Info.plist
  Docs/architecture.md
]
publication_paths.each do |relative_path|
  path = File.join(repo_root, relative_path)
  source = File.read(path)
  fail_validation("unsupported public.markdown UTI remains in #{relative_path}") if source.include?("public.markdown")
end

declarations = declarations_by_identifier(properties)
expected_routes = {
  "net.daringfireball.markdown" => ["imported", %w[md markdown], %w[public.plain-text]],
  "com.91wan.marklook.markdown-alias" => ["exported", %w[mdown mkd mkdn], %w[net.daringfireball.markdown]],
  "com.91wan.marklook.mdx" => ["exported", %w[mdx]],
  "com.rstudio.rmarkdown" => ["imported", %w[rmd], %w[net.daringfireball.markdown]],
  "org.quarto.qmarkdown" => ["imported", %w[qmd], %w[net.daringfireball.markdown]]
}

declared_extensions = declarations.values.flat_map { |entry| filename_extensions(entry) }
duplicate_extensions = declared_extensions.group_by(&:itself).select { |_, values| values.length > 1 }.keys
fail_validation("extensions have multiple routing declarations: #{duplicate_extensions.join(', ')}") unless duplicate_extensions.empty?

routed_extensions = declared_extensions.to_set
advertised_extensions = swift_extensions.to_set
missing_routes = advertised_extensions - routed_extensions
unadvertised_routes = routed_extensions - advertised_extensions
fail_validation("advertised extensions without routing declarations: #{missing_routes.to_a.sort.join(', ')}") unless missing_routes.empty?
fail_validation("routing declarations contain unadvertised extensions: #{unadvertised_routes.to_a.sort.join(', ')}") unless unadvertised_routes.empty?

assert_equal("routing UTI identifiers", expected_routes.keys.to_set, declarations.keys.to_set)
expected_routes.each do |identifier, (kind, extensions, conformance)|
  declaration = declarations.fetch(identifier)
  assert_equal("#{identifier} declaration kind", kind, declaration["_kind"])
  assert_equal("#{identifier} filename extensions", extensions, filename_extensions(declaration))
  assert_equal(
    "#{identifier} conformance",
    conformance || %w[public.text],
    Array(declaration["UTTypeConformsTo"])
  )
  fail_validation("#{identifier} must declare UTTypeDescription") if declaration["UTTypeDescription"].to_s.empty?
  fail_validation("#{identifier} is not listed by both Quick Look extensions") unless preview_types.include?(identifier)
end

puts "PASS: supported Markdown UTIs and extension routes are synchronized"
RUBY

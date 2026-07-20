#!/usr/bin/env ruby

require "json"
require "open3"
require "set"

app_path = ARGV.fetch(0) do
  warn "usage: Scripts/validate-built-uti-declarations.rb path/to/MarkLook.app"
  exit 64
end

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

def declarations_by_identifier(entries, kind)
  declarations = {}
  Array(entries).each do |entry|
    identifier = entry["UTTypeIdentifier"]
    fail_validation("#{kind} UTI declaration is missing UTTypeIdentifier") if identifier.to_s.empty?
    fail_validation("duplicate #{kind} UTI declaration: #{identifier}") if declarations.key?(identifier)
    declarations[identifier] = entry
  end
  declarations
end

def assert_set_equal(label, expected, actual)
  fail_validation("#{label} contains duplicates: #{actual.inspect}") if actual.length != actual.uniq.length
  return if expected.to_set == actual.to_set
  fail_validation("#{label} differs\nexpected: #{expected.sort.inspect}\nactual:   #{actual.sort.inspect}")
end

expected_supported_types = %w[
  net.daringfireball.markdown
  net.ia.markdown
  io.typora.markdown
  com.apple.dt.document.markdown
  com.rstudio.rmarkdown
  org.quarto.qmarkdown
  com.91wan.marklook.markdown-alias
  com.91wan.marklook.mdx
]

expected = {
  "exported" => {
    "com.91wan.marklook.markdown-alias" => {
      "extensions" => %w[mdown mkd mkdn],
      "conformance" => %w[net.daringfireball.markdown]
    },
    "com.91wan.marklook.mdx" => {
      "extensions" => %w[mdx],
      "conformance" => %w[public.text]
    }
  },
  "imported" => {
    "net.daringfireball.markdown" => {
      "extensions" => %w[md markdown],
      "conformance" => %w[public.plain-text]
    },
    "com.rstudio.rmarkdown" => {
      "extensions" => %w[rmd],
      "conformance" => %w[net.daringfireball.markdown]
    },
    "org.quarto.qmarkdown" => {
      "extensions" => %w[qmd],
      "conformance" => %w[net.daringfireball.markdown]
    }
  }
}

app_plist = load_plist(File.join(app_path, "Contents", "Info.plist"))
preview_plist = load_plist(
  File.join(app_path, "Contents", "PlugIns", "MarkLookPreview.appex", "Contents", "Info.plist")
)
thumbnail_plist = load_plist(
  File.join(app_path, "Contents", "PlugIns", "MarkLookThumbnail.appex", "Contents", "Info.plist")
)
actual = {
  "exported" => declarations_by_identifier(app_plist["UTExportedTypeDeclarations"], "exported"),
  "imported" => declarations_by_identifier(app_plist["UTImportedTypeDeclarations"], "imported")
}

expected.each do |kind, expected_declarations|
  actual_declarations = actual.fetch(kind)
  assert_set_equal(
    "#{kind} UTI identifiers",
    expected_declarations.keys,
    actual_declarations.keys
  )

  expected_declarations.each do |identifier, specification|
    declaration = actual_declarations.fetch(identifier)
    assert_set_equal(
      "#{identifier} filename extensions",
      specification.fetch("extensions"),
      Array(declaration.dig("UTTypeTagSpecification", "public.filename-extension"))
    )
    assert_set_equal(
      "#{identifier} conformance",
      specification.fetch("conformance"),
      Array(declaration["UTTypeConformsTo"])
    )
  end
end

document_types = Array(app_plist["CFBundleDocumentTypes"]).flat_map do |entry|
  Array(entry["LSItemContentTypes"])
end
preview_types = Array(
  preview_plist.dig("NSExtension", "NSExtensionAttributes", "QLSupportedContentTypes")
)
thumbnail_types = Array(
  thumbnail_plist.dig("NSExtension", "NSExtensionAttributes", "QLSupportedContentTypes")
)

assert_set_equal("built app document content types", expected_supported_types, document_types)
assert_set_equal("built Preview supported content types", expected_supported_types, preview_types)
assert_set_equal("built Thumbnail supported content types", expected_supported_types, thumbnail_types)

puts "PASS: built UTI declarations and Quick Look exact sets match supported routes"

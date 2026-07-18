#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "yaml"

repo_root = Pathname.new(ARGV.fetch(0, File.expand_path("..", __dir__))).realpath
project_path = repo_root.join("project.yml")
target_names = %w[MarkLook MarkLookPreview MarkLookThumbnail].freeze
errors = []

begin
  project = YAML.safe_load(project_path.read, aliases: false)
rescue StandardError => error
  abort "error: could not parse #{project_path}: #{error.message}"
end

versions = {}

target_names.each do |target_name|
  target = project.dig("targets", target_name)
  unless target.is_a?(Hash)
    errors << "#{target_name} is missing from project.yml"
    next
  end

  properties = target.dig("info", "properties")
  info_path = target.dig("info", "path")
  marketing_version = properties&.fetch("CFBundleShortVersionString", nil)
  build_number = properties&.fetch("CFBundleVersion", nil)

  unless marketing_version.is_a?(String) && !marketing_version.empty?
    errors << "#{target_name} has no CFBundleShortVersionString in project.yml"
    next
  end
  unless build_number.is_a?(String) && !build_number.empty?
    errors << "#{target_name} has no CFBundleVersion in project.yml"
    next
  end
  unless info_path.is_a?(String) && !info_path.empty?
    errors << "#{target_name} has no Info.plist path in project.yml"
    next
  end

  versions[target_name] = [marketing_version, build_number]
  plist_path = repo_root.join(info_path)
  unless plist_path.file?
    errors << "#{target_name} Info.plist is missing: #{info_path}"
    next
  end

  output, error_output, status = Open3.capture3(
    "/usr/bin/plutil", "-convert", "json", "-o", "-", "--", plist_path.to_s
  )
  unless status.success?
    errors << "#{target_name} Info.plist could not be read: #{error_output.strip}"
    next
  end

  plist = JSON.parse(output)
  plist_version = [plist["CFBundleShortVersionString"], plist["CFBundleVersion"]]
  next if plist_version == versions[target_name]

  errors << "#{target_name} Info.plist version #{plist_version.join(" (")}) " \
            "does not match project.yml #{marketing_version} (#{build_number})"
rescue JSON::ParserError => error
  errors << "#{target_name} Info.plist JSON conversion failed: #{error.message}"
end

if versions.length == target_names.length && versions.values.uniq.length != 1
  rendered = versions.map { |name, value| "#{name}=#{value[0]} (#{value[1]})" }.join(", ")
  errors << "production target versions differ: #{rendered}"
end

unless errors.empty?
  warn "error: version consistency validation failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

marketing_version, build_number = versions.fetch("MarkLook")
puts "MarkLook version consistency: #{marketing_version} (#{build_number}): PASS"

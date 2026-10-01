#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  Scripts/validate-developer-id-artifact.sh --signed-only path/to/MarkLook.app-or.zip
  Scripts/validate-developer-id-artifact.sh --notarized path/to/MarkLook.app-or.zip

Modes:
  --signed-only  Require Developer ID Application signing and hardened runtime.
  --notarized    Require signed-only checks plus stapler validation and spctl assessment.
USAGE
}

die_usage() {
  usage
  exit 64
}

if [ "$#" -ne 2 ]; then
  die_usage
fi

mode="$1"
artifact_path="$2"
case "$mode" in
  --signed-only|--notarized)
    ;;
  *)
    echo "error: unknown Developer ID artifact validation mode: $mode" >&2
    die_usage
    ;;
esac

if [ ! -e "$artifact_path" ]; then
  echo "error: artifact not found: $artifact_path" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
codesign_cmd="${MARKLOOK_DEVID_CODESIGN:-codesign}"
ditto_cmd="${MARKLOOK_DEVID_DITTO:-ditto}"
xcrun_cmd="${MARKLOOK_DEVID_XCRUN:-xcrun}"
spctl_cmd="${MARKLOOK_DEVID_SPCTL:-spctl}"
ruby_cmd="${MARKLOOK_DEVID_RUBY:-ruby}"
validate_built_bundle="${MARKLOOK_DEVID_VALIDATE_BUILT_BUNDLE:-$repo_root/Scripts/validate-built-bundle.sh}"
validate_preview_contract="${MARKLOOK_DEVID_VALIDATE_PREVIEW_CONTRACT:-$repo_root/Scripts/validate-quicklook-preview-contract.sh}"
validate_thumbnail_boundaries="${MARKLOOK_DEVID_VALIDATE_THUMBNAIL_BOUNDARIES:-$repo_root/Scripts/validate-thumbnail-boundaries.sh}"

extract_root=""
entitlements_file="$(mktemp)"
entitlements_json="$(mktemp)"
details_file="$(mktemp)"
identity_file="$(mktemp)"
trap 'rm -rf "$extract_root"; rm -f "$entitlements_file" "$entitlements_json" "$details_file" "$identity_file"' EXIT

case "$artifact_path" in
  *.app)
    app="$artifact_path"
    ;;
  *.zip)
    extract_root="$(mktemp -d)"
    "$ditto_cmd" -x -k "$artifact_path" "$extract_root"
    app="$extract_root/MarkLook.app"
    ;;
  *)
    echo "error: artifact must be a .app bundle or .zip package: $artifact_path" >&2
    exit 1
    ;;
esac

# Inventory the extracted bytes before invoking any signature or notarization hook.
architecture_sets="$(LC_ALL=en_US.UTF-8 "$ruby_cmd" -rfind -rjson -ropen3 - "$app" "$extract_root" <<'RUBY'
app, extraction = ARGV
app = File.expand_path(app)
bundles = {
  '' => 'MarkLook',
  'Contents/PlugIns/MarkLookPreview.appex' => 'MarkLookPreview',
  'Contents/PlugIns/MarkLookThumbnail.appex' => 'MarkLookThumbnail'
}
executables = bundles.map { |bundle, name| [bundle, 'Contents/MacOS', name].reject(&:empty?).join('/') }
mach_magics = %w[feedface cefaedfe feedfacf cffaedfe cafebabe bebafeca cafebabf bfbafeca]

begin
  raise unless extraction.empty? || Dir.children(extraction) == ['MarkLook.app']
  raise unless File.lstat(app).directory?
  seen = []
  Find.find(app, ignore_error: false) do |path|
    stat = File.lstat(path)
    relative = path == app ? '' : path.delete_prefix(app + '/')
    raise if stat.symlink? || (!stat.directory? && !stat.file?)
    raise unless (stat.mode & 0444) != 0 && File.readable?(path)
    if stat.directory?
      raise unless (stat.mode & 0111) != 0 && File.executable?(path)
      if relative.match?(/\.(?:app|appex|xpc|framework|bundle|loginbundle)\z/i)
        raise unless bundles.key?(relative)
      end
    else
      magic = File.open(path, 'rb') { |file| (file.read(4) || '').unpack1('H*') }
      # Real ditto metadata must have been merged, not exempted by a ._* name.
      raise if magic == '00051607'
      if executables.include?(relative)
        raise unless mach_magics.include?(magic) && (stat.mode & 0111) != 0
        seen << relative
      else
        raise if mach_magics.include?(magic) || (stat.mode & 0111) != 0
      end
    end
  end
  raise unless seen.sort == executables.sort
  bundles.each do |bundle, name|
    plist = File.join(app, bundle, 'Contents/Info.plist')
    output, _, status = Open3.capture3('/usr/bin/plutil', '-convert', 'json', '-o', '-', plist)
    raise unless status.success? && JSON.parse(output).fetch('CFBundleExecutable') == name
  end
  executables.each do |relative|
    path = File.join(app, relative)
    output, _, status = Open3.capture3('/usr/bin/lipo', '-archs', path)
    raise unless status.success? && output.match?(/\A[a-z0-9_]+(?:[ \t]+[a-z0-9_]+)*\n?\z/)
    architectures = output.split
    raise if architectures.empty? || architectures.uniq != architectures
    raise unless architectures.all? { |arch| arch.match?(/\A(?:arm64(?:e|_32)?|armv[0-9]+[a-z]*|x86_64h?|i386|ppc(?:64)?)\z/) }
    architectures.each do |arch|
      header, _, status = Open3.capture3('/usr/bin/otool', '-hv', '-arch', arch, path)
      raise unless status.success? && header.match?(/^MH_(?:MAGIC|CIGAM)(?:_64)?\s+.*\bEXECUTE\b/)
    end
    puts architectures.join(' ')
  end
rescue StandardError
  warn 'error: invalid Developer ID artifact code inventory'
  exit 1
end
RUBY
)"

preview="$app/Contents/PlugIns/MarkLookPreview.appex"
thumbnail="$app/Contents/PlugIns/MarkLookThumbnail.appex"
test -d "$app"
test -d "$preview"
test -d "$thumbnail"

"$validate_built_bundle" "$app"
"$validate_preview_contract" "$app"
"$validate_thumbnail_boundaries"

verify_signature() {
  local target="$1"
  local label="$2"
  local status
  if "$codesign_cmd" --verify --deep --strict --verbose=4 "$target" >"$details_file" 2>&1; then
    return
  else
    status="$?"
    echo "error: could not verify signature for $label" >&2
    exit "$status"
  fi
}

check_codesign_details() {
  local target="$1" label="$2" architecture="$3" status
  if "$codesign_cmd" -dv --verbose=4 --architecture "$architecture" "$target" >"$details_file" 2>&1; then
    :
  else
    status="$?"
    echo "error: could not read signing details from $label" >&2
    exit "$status"
  fi
  LC_ALL=en_US.UTF-8 "$ruby_cmd" -rjson - "$details_file" "$identity_file" "$label" <<'RUBY'
details, identity, label = ARGV
def reject(label, message)
  warn "error: #{label} #{message}"
  exit 1
end
begin
  lines = File.read(details).lines.map(&:chomp)
  authorities = lines.grep(/\AAuthority=/)
  leaves = lines.grep(/\AAuthority=Developer ID Application:/)
  leaf = leaves.length == 1 && leaves.first.match(/\AAuthority=(Developer ID Application: .+ \(([A-Z0-9]{10})\))\z/)
  reject(label, 'is not signed by one valid Developer ID Application leaf') unless leaf && authorities.first == leaves.first
  teams = lines.grep(/\ATeamIdentifier=/)
  team = teams.length == 1 && teams.first.match(/\ATeamIdentifier=([A-Z0-9]{10})\z/)
  reject(label, 'is missing a valid 10-character TeamIdentifier') unless team
  reject(label, 'has inconsistent signing identity') unless leaf[2] == team[1]
  reject(label, 'is missing a secure timestamp') unless lines.any? { |line| line.start_with?('Timestamp=') }
  reject(label, 'is missing hardened runtime') unless lines.any? { |line| line.match?(/Runtime Version=|flags=.*runtime/) }
  current = [leaf[1], team[1]]
  if File.size(identity).zero?
    File.write(identity, JSON.generate(current))
  else
    reject(label, 'has inconsistent signing identity') unless JSON.parse(File.read(identity)) == current
  end
rescue StandardError
  reject(label, 'has invalid signing details')
end
RUBY
}

check_exact_entitlements() {
  local target="$1"
  local label="$2"
  local architecture="$3" status
  shift 3

  : >"$entitlements_file"
  if "$codesign_cmd" -d --entitlements :- --architecture "$architecture" "$target" >"$entitlements_file" 2>/dev/null; then
    :
  else
    status="$?"
    echo "error: could not read entitlements from $label" >&2
    exit "$status"
  fi
  if [ ! -s "$entitlements_file" ]; then
    echo "error: $label has no entitlement payload" >&2
    exit 1
  fi
  if ! /usr/bin/plutil -convert json -o "$entitlements_json" "$entitlements_file" >/dev/null 2>&1; then
    echo "error: $label has an invalid entitlement payload" >&2
    exit 1
  fi

  "$ruby_cmd" -rjson - "$entitlements_json" "$label" "$@" <<'RUBY'
path = ARGV.shift
label = ARGV.shift
expected = ARGV.sort
entitlements = JSON.parse(File.read(path))

unless entitlements.is_a?(Hash)
  warn "error: #{label} entitlement payload is not a dictionary"
  exit 1
end

actual = entitlements.keys.sort
unless actual == expected
  warn "error: #{label} entitlements differ"
  exit 1
end

invalid = expected.reject { |key| entitlements[key] == true }
unless invalid.empty?
  warn "error: #{label} required entitlements are not true: #{invalid.inspect}"
  exit 1
end
RUBY
}

index=0
for target in "$app" "$preview" "$thumbnail"; do
  index=$((index + 1))
  label="$(basename "$target")"
  verify_signature "$target" "$label"
  architectures="$(printf '%s\n' "$architecture_sets" | sed -n "${index}p")"
  for architecture in $architectures; do
    check_codesign_details "$target" "$label" "$architecture"
    if [ "$target" = "$app" ]; then
      check_exact_entitlements "$target" "$label" "$architecture" \
        com.apple.security.app-sandbox com.apple.security.files.user-selected.read-only
    else
      check_exact_entitlements "$target" "$label" "$architecture" com.apple.security.app-sandbox
    fi
  done
done

if [ "$mode" = "--notarized" ]; then
  "$xcrun_cmd" stapler validate "$app"
  "$spctl_cmd" --assess --type execute --verbose=4 "$app"
fi

echo "Developer ID artifact OK: $artifact_path"

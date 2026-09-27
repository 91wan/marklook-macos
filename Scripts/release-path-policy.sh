#!/usr/bin/env bash

# Source this helper and complete admission before registering cleanup or writing.
canonicalize_release_path() {
  local role="$1" label="$2" input="$3" repo_root="$4"
  local ruby_cmd="${5:-/usr/bin/ruby}" getconf_cmd="${6:-/usr/bin/getconf}"
  local darwin_user_temp

  if ! darwin_user_temp="$("$getconf_cmd" DARWIN_USER_TEMP_DIR 2>/dev/null)" || [ -z "$darwin_user_temp" ]; then
    echo "error: could not resolve the OS-owned user temporary directory" >&2
    return 1
  fi

  "$ruby_cmd" - "$role" "$label" "$input" "$repo_root" "$darwin_user_temp" <<'RUBY'
role, label, input, repo, user_temp = ARGV
reject = ->(reason) { abort "error: unsafe #{label}: #{reason}" }
reject.call('empty or multiline path') if input.empty? || input.match?(/[\r\n]/)

# Resolve an existing ancestor, then append only the missing components.
resolve = lambda do |path|
  cursor = path
  suffix = []
  until File.exist?(cursor) || File.symlink?(cursor)
    parent = File.dirname(cursor)
    reject.call('no existing ancestor') if parent == cursor
    suffix.unshift(File.basename(cursor))
    cursor = parent
  end
  reject.call('non-directory ancestor') if !suffix.empty? && !File.directory?(cursor)
  File.join(File.realpath(cursor), *suffix)
end
child = ->(path, root) { path.start_with?(root + '/') }
fold = ->(path) { path.unicode_normalize(:nfd).downcase }
begin
  repo = File.realpath(repo)
  expanded = File.expand_path(input, repo)
  resolved = resolve.call(expanded)
  reject.call('multiline resolved path') if resolved.match?(/[\r\n]/)
  temp_roots = [File.realpath(user_temp), File.realpath('/private/tmp')].uniq
  build_root = File.join(repo, '.build')
  dist_root = File.join(repo, 'dist')
  # realpath preserves input casing on case-insensitive APFS. Denials must not.
  reject.call('contains the repository') if resolved == '/' || fold.call(resolved) == fold.call(repo) || child.call(fold.call(repo), fold.call(resolved))
  reject.call('temporary root itself') if temp_roots.any? { |root| fold.call(root) == fold.call(resolved) }

  repo_allowed = case role
                 when 'derivedData', 'output' then child.call(resolved, build_root)
                 when 'dist' then resolved == dist_root || child.call(resolved, dist_root)
                 when 'installApp' then false
                 else reject.call('unknown role')
                 end
  reject.call('overlaps the repository') if child.call(fold.call(resolved), fold.call(repo)) && !repo_allowed
  temp_allowed = temp_roots.any? { |root| child.call(resolved, root) }

  if role == 'installApp'
    reject.call('installation requires the fixed app path') unless input == '/Applications/MarkLook.app' && resolved == input
  else
    reject.call('outside allowed roots') unless repo_allowed || temp_allowed
  end

  if role == 'output'
    reject.call('linked output') if File.symlink?(expanded)
    if File.exist?(resolved)
      stat = File.stat(resolved)
      reject.call('output must be a singly linked regular file') unless stat.file? && stat.nlink == 1
    end
  elsif File.exist?(resolved)
    reject.call('directory required') unless File.directory?(resolved)
  end
  puts resolved
rescue SystemCallError, ArgumentError => error
  reject.call("cannot resolve path (#{error.class})")
end
RUBY
}

# Keep the Developer ID caller's API and error label stable.
canonicalize_disposable_derived_data() {
  canonicalize_release_path derivedData MARKLOOK_DEVID_DERIVED_DATA "$1" "$2" "$3" "$4"
}

require_disjoint_release_paths() {
  /usr/bin/ruby - "$@" <<'RUBY'
paths = ARGV.map { |path| path.unicode_normalize(:nfd).downcase }
paths.combination(2) do |left, right|
  if left == right || left.start_with?(right + '/') || right.start_with?(left + '/')
    abort 'error: unsafe overlapping release paths'
  end
end
RUBY
}

validate_installed_app_identity() {
  local app="$1" expected_identifier="$2" identifier
  if [ ! -e "$app" ] && [ ! -L "$app" ]; then
    return 0
  fi
  if [ -L "$app" ] || [ ! -d "$app" ] || [ -L "$app/Contents" ] || [ -L "$app/Contents/Info.plist" ] ||
     ! identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null)" ||
     [ -z "$expected_identifier" ] || [ "$identifier" != "$expected_identifier" ]; then
    echo "error: unsafe installed app identity" >&2
    return 1
  fi
}

#!/usr/bin/env bash

# Source this helper and call it in a command substitution before any writes.
canonicalize_disposable_derived_data() {
  local input="$1"
  local repo_root="$2"
  local ruby_cmd="$3"
  local getconf_cmd="$4"
  local resolved
  local repo_build_root="$repo_root/.build"
  local darwin_user_temp
  local darwin_user_temp_root
  local private_tmp_root

  if ! resolved="$("$ruby_cmd" - "$input" <<'RUBY'
path = File.expand_path(ARGV.fetch(0))
cursor = path
suffix = []

until File.exist?(cursor) || File.symlink?(cursor)
  parent = File.dirname(cursor)
  abort "could not resolve path: #{path}" if parent == cursor
  suffix.unshift(File.basename(cursor))
  cursor = parent
end

puts File.join(File.realpath(cursor), *suffix)
RUBY
  )"; then
    echo "error: could not resolve MARKLOOK_DEVID_DERIVED_DATA: $input" >&2
    exit 1
  fi

  if ! darwin_user_temp="$("$getconf_cmd" DARWIN_USER_TEMP_DIR 2>/dev/null)" || [ -z "$darwin_user_temp" ]; then
    echo "error: could not resolve the OS-owned user temporary directory" >&2
    exit 1
  fi
  darwin_user_temp_root="$("$ruby_cmd" -e 'puts File.realpath(ARGV.fetch(0))' "$darwin_user_temp")"
  private_tmp_root="$("$ruby_cmd" -e 'puts File.realpath(ARGV.fetch(0))' /private/tmp)"

  case "$resolved" in
    "$repo_root"|"$repo_root"/*)
      case "$resolved" in
        "$repo_build_root"/*)
          ;;
        *)
          echo "error: unsafe MARKLOOK_DEVID_DERIVED_DATA overlaps the repository: $input" >&2
          exit 1
          ;;
      esac
      ;;
  esac

  if [ "$resolved" = "/" ] || [ "$resolved" = "$repo_root" ] || [[ "$repo_root" == "$resolved"/* ]]; then
    echo "error: unsafe MARKLOOK_DEVID_DERIVED_DATA contains the repository: $input" >&2
    exit 1
  fi

  case "$resolved" in
    "$repo_build_root"/*|"$darwin_user_temp_root"/*|"$private_tmp_root"/*)
      ;;
    *)
      echo "error: unsafe MARKLOOK_DEVID_DERIVED_DATA: $input" >&2
      echo "Use a child of $repo_build_root or a system temporary directory." >&2
      exit 1
      ;;
  esac

  printf '%s\n' "$resolved"
}

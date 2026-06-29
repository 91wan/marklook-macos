#!/usr/bin/env bash

marklook_team_id_from_subject() {
  subject="$1"

  printf '%s\n' "$subject" |
    sed 's#/#, #g' |
    awk -F', ' '
      {
        for (i = 1; i <= NF; i++) {
          field = $i
          sub(/^subject=/, "", field)
          if (field ~ /^OU[[:space:]]*=/) {
            sub(/^OU[[:space:]]*=[[:space:]]*/, "", field)
            sub(/[[:space:]]*$/, "", field)
            if (field ~ /^[A-Z0-9]+$/) {
              print field
              exit
            }
          }
        }
      }
    '
}

marklook_team_id_from_identity_line() {
  identity_line="$1"

  printf '%s\n' "$identity_line" |
    sed -n 's/.*(\([A-Z0-9][A-Z0-9]*\)).*/\1/p' |
    head -n 1
}

marklook_identity_name_from_identity_line() {
  identity_line="$1"

  printf '%s\n' "$identity_line" |
    sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' |
    head -n 1
}

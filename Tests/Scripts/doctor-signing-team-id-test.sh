#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=/dev/null
source Scripts/signing-team-id.sh

subject="$(cat test/fixtures/apple-development-subject-cn-ou.txt)"
actual="$(marklook_team_id_from_subject "$subject")"
expected="W2SP34K4MR"

if [ "$actual" != "$expected" ]; then
  echo "expected Team ID '$expected', got '$actual'" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/security" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  find-identity)
    cat <<'EOF'
  1) EF040B171F3A8D4290C529AC65145C28B0BDA408 "Apple Development: 8618912901063 (LASA9BSN8X)"
     1 valid identities found
EOF
    ;;
  find-certificate)
    cat <<'EOF'
-----BEGIN CERTIFICATE-----
fixture
-----END CERTIFICATE-----
EOF
    ;;
  *)
    echo "unexpected security invocation: $*" >&2
    exit 2
    ;;
esac
STUB

cat >"$tmpdir/openssl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
subject=UID=M73R3466UV, CN=Apple Development: 8618912901063 (LASA9BSN8X), OU=W2SP34K4MR, O=Changxi Liu, C=US
EOF
STUB

chmod +x "$tmpdir/security" "$tmpdir/openssl"

output="$(PATH="$tmpdir:$PATH" Scripts/doctor-signing.sh)"

if ! printf '%s\n' "$output" | grep -q 'DEVELOPMENT_TEAM=W2SP34K4MR Scripts/build-local-apple-development.sh'; then
  echo "expected doctor output to suggest certificate OU Team ID" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

if printf '%s\n' "$output" | grep -q 'DEVELOPMENT_TEAM=LASA9BSN8X'; then
  echo "doctor output must not suggest CN parenthetical as DEVELOPMENT_TEAM" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

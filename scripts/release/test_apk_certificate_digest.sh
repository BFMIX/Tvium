#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
parser="$root/scripts/release/apk_certificate_digest.sh"
digest='ccac1f9322e3f75965540778c16734c0e5da5508348f68321638bdb2660e1bcb'

actual="$(printf 'Signer #1 certificate SHA-256 digest: %s\n' "$digest" | bash "$parser")"
[[ "$actual" == "$digest" ]]

actual="$(printf 'Signer #1 certificate SHA-256 digest:\tCC:AC:1F:93:22:E3:F7:59:65:54:07:78:C1:67:34:C0:E5:DA:55:08:34:8F:68:32:16:38:BD:B2:66:0E:1B:CB\n' | bash "$parser")"
[[ "$actual" == "$digest" ]]

if printf 'Signer #1 certificate MD5 digest: 1234\n' | bash "$parser" >/dev/null 2>&1; then
  echo 'Accepted missing SHA-256 certificate digest.' >&2
  exit 1
fi

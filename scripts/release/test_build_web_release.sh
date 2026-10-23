#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
cat > "$scratch/flutter" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TVIUM_TEST_ARGS"
SH
chmod +x "$scratch/flutter"
export PATH="$scratch:$PATH"
export TVIUM_TEST_ARGS="$scratch/args"

TVIUM_RELEASE_TAG=v1.2.3 TVIUM_METADATA_GATEWAY= \
  bash "$root/scripts/release/build_web_release.sh"
grep -Fx -- '--dart-define=TVIUM_RELEASE_TAG=v1.2.3' "$TVIUM_TEST_ARGS"
if grep -Fq 'TVIUM_METADATA_GATEWAY' "$TVIUM_TEST_ARGS"; then
  exit 1
fi

TVIUM_RELEASE_TAG=v1.2.3 TVIUM_METADATA_GATEWAY=https://metadata.example.test \
  bash "$root/scripts/release/build_web_release.sh"
grep -Fx -- '--dart-define=TVIUM_METADATA_GATEWAY=https://metadata.example.test' "$TVIUM_TEST_ARGS"

if TVIUM_RELEASE_TAG=v1.2.3 TVIUM_METADATA_GATEWAY=http://metadata.example.test \
  bash "$root/scripts/release/build_web_release.sh" >/dev/null 2>&1; then
  exit 1
fi

if TVIUM_RELEASE_TAG=v1.2.3 TVIUM_METADATA_GATEWAY='https://user:secret@metadata.example.test' \
  bash "$root/scripts/release/build_web_release.sh" >/dev/null 2>&1; then
  exit 1
fi

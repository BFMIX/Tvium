#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
helper="$root/scripts/release/metadata_gateway_args.sh"

[[ -z "$(TVIUM_METADATA_GATEWAY= bash "$helper")" ]]
[[ "$(TVIUM_METADATA_GATEWAY=https://metadata.example.test bash "$helper")" == '--dart-define=TVIUM_METADATA_GATEWAY=https://metadata.example.test' ]]

for invalid in \
  'http://metadata.example.test' \
  'https://user:secret@metadata.example.test' \
  'https://metadata.example.test/v1/search' \
  'https://metadata.example.test?token=secret'; do
  if TVIUM_METADATA_GATEWAY="$invalid" bash "$helper" >/dev/null 2>&1; then
    exit 1
  fi
done

[[ "$(rg -c 'metadata_gateway_args.sh' "$root/.github/workflows/release.yml")" -eq 2 ]]

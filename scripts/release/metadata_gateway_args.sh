#!/usr/bin/env bash
set -euo pipefail

# Print a Flutter argument only for a public HTTPS origin. Never put a token here.
if [[ -z "${TVIUM_METADATA_GATEWAY:-}" ]]; then
  exit 0
fi

if [[ ! "$TVIUM_METADATA_GATEWAY" =~ ^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?/?$ ]]; then
  echo 'Metadata gateway must be a public HTTPS origin without credentials or a path.' >&2
  exit 64
fi

printf '%s\n' "--dart-define=TVIUM_METADATA_GATEWAY=$TVIUM_METADATA_GATEWAY"

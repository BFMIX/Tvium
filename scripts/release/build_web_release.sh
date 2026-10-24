#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TVIUM_RELEASE_TAG:-}" ]]; then
  echo 'Release tag is required.' >&2
  exit 64
fi

arguments=(
  build web
  --release
  --no-wasm-dry-run
  --base-href /Tvium/
  "--dart-define=TVIUM_RELEASE_TAG=$TVIUM_RELEASE_TAG"
)

if [[ -n "${TVIUM_METADATA_GATEWAY:-}" ]]; then
  if [[ ! "$TVIUM_METADATA_GATEWAY" =~ ^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?/?$ ]]; then
    echo 'Metadata gateway must be a public HTTPS origin without credentials or a path.' >&2
    exit 64
  fi
  arguments+=("--dart-define=TVIUM_METADATA_GATEWAY=$TVIUM_METADATA_GATEWAY")
fi

if [[ -n "${TVIUM_PAIRING_RELAY:-}" ]]; then
  if [[ ! "$TVIUM_PAIRING_RELAY" =~ ^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?/?$ ]]; then
    echo 'Pairing relay must be a public HTTPS origin without credentials or a path.' >&2
    exit 64
  fi
  arguments+=("--dart-define=TVIUM_PAIRING_RELAY=$TVIUM_PAIRING_RELAY")
fi

flutter "${arguments[@]}"

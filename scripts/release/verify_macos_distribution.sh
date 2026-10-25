#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <Tvium.app path> <notarized.dmg path>" >&2
  exit 64
fi

app_path="$1"
dmg_path="$2"

if [[ ! -d "$app_path" ]]; then
  echo "macOS application bundle is missing." >&2
  exit 66
fi

signature="$(codesign -dv --verbose=2 "$app_path" 2>&1)" || {
  echo "macOS application signature is missing or invalid." >&2
  exit 1
}
if [[ "$signature" != *"Authority=Developer ID Application:"* ]]; then
  echo "macOS distribution requires a Developer ID Application signature." >&2
  exit 1
fi

if ! codesign --verify --deep --strict "$app_path"; then
  echo "macOS application or a bundled framework has an invalid signature." >&2
  exit 1
fi

if [[ ! -f "$dmg_path" ]]; then
  echo "Notarized macOS DMG is missing." >&2
  exit 66
fi
if ! xcrun stapler validate "$dmg_path"; then
  echo "macOS DMG has no valid stapled notarization ticket." >&2
  exit 1
fi
if ! spctl --assess --type open --context context:primary-signature "$dmg_path"; then
  echo "macOS Gatekeeper rejected the DMG." >&2
  exit 1
fi

echo "macOS Developer ID signature and notarized DMG verified."

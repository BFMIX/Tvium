#!/usr/bin/env bash
set -euo pipefail

# Accept apksigner output from SDK versions that vary whitespace and casing.
certificate_line="$(grep -im1 'Signer #1 certificate SHA-256 digest:' || true)"
if [[ -z "$certificate_line" ]]; then
  echo 'The APK signer did not report a SHA-256 certificate digest.' >&2
  exit 1
fi

digest="${certificate_line#*digest:}"
digest="$(printf '%s' "$digest" | tr -d '[:space:]:' | tr '[:upper:]' '[:lower:]')"
if [[ ! "$digest" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'The APK signer returned an invalid SHA-256 certificate digest.' >&2
  exit 1
fi
printf '%s\n' "$digest"

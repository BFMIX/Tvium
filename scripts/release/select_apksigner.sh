#!/usr/bin/env bash
set -euo pipefail

# SDK 34's certificate report is covered by the release parser test. Do not
# silently switch to a newer SDK whose output has not been verified.
apksigner="${ANDROID_HOME:?ANDROID_HOME is required}/build-tools/34.0.0/apksigner"
if [[ ! -x "$apksigner" ]]; then
  echo 'Android SDK Build Tools 34.0.0 are required for release verification.' >&2
  exit 1
fi
printf '%s\n' "$apksigner"

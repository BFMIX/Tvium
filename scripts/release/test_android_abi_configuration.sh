#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for workflow in "$root/.github/workflows/ci.yml" "$root/.github/workflows/release.yml"; do
  if ! grep -q -- '--target-platform android-arm,android-arm64' "$workflow"; then
    echo "Android build must include 32-bit and 64-bit ARM: $workflow" >&2
    exit 1
  fi
done

apk="${1:-}"
if [[ -n "$apk" ]]; then
  if [[ ! -f "$apk" ]]; then
    echo "APK not found: $apk" >&2
    exit 1
  fi
  entries="$(unzip -Z1 "$apk")"
  for abi in armeabi-v7a arm64-v8a; do
    for library in libflutter.so libapp.so libmpv.so; do
      if ! grep -Fqx "lib/$abi/$library" <<< "$entries"; then
        echo "APK is missing $library for $abi" >&2
        exit 1
      fi
    done
  done
fi

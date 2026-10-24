#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_sdk="$(mktemp -d)"
trap 'rm -rf "$test_sdk"' EXIT
mkdir -p "$test_sdk/build-tools/34.0.0" "$test_sdk/build-tools/36.0.0"
touch "$test_sdk/build-tools/34.0.0/apksigner" "$test_sdk/build-tools/36.0.0/apksigner"
chmod +x "$test_sdk/build-tools/34.0.0/apksigner" "$test_sdk/build-tools/36.0.0/apksigner"

selected="$(ANDROID_HOME="$test_sdk" bash "$root/scripts/release/select_apksigner.sh")"
[[ "$selected" == "$test_sdk/build-tools/34.0.0/apksigner" ]]

rm "$test_sdk/build-tools/34.0.0/apksigner"
if ANDROID_HOME="$test_sdk" bash "$root/scripts/release/select_apksigner.sh" >/dev/null 2>&1; then
  echo 'Selected an unverified Android SDK build tool.' >&2
  exit 1
fi

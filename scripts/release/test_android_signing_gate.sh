#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
gradle="$root/apps/tvium_app/android/gradlew"
output="$(mktemp)"
trap 'rm -f "$output"' EXIT

if env -u TVIUM_ANDROID_KEYSTORE_PATH \
    -u TVIUM_ANDROID_STORE_PASSWORD \
    -u TVIUM_ANDROID_KEY_ALIAS \
    -u TVIUM_ANDROID_KEY_PASSWORD \
    TVIUM_REQUIRE_ANDROID_RELEASE_SIGNING=true \
    "$gradle" -p "$root/apps/tvium_app/android" help --quiet \
    >"$output" 2>&1; then
  echo 'Android release configuration accepted missing signing credentials.' >&2
  exit 1
fi

if ! grep -q 'Android release signing credentials are required' "$output"; then
  echo 'Android release configuration failed for an unexpected reason.' >&2
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
output="$(mktemp)"
trap 'rm -f "$output"' EXIT

if (
  cd "$root/apps/tvium_app"
  env -u TVIUM_ANDROID_KEYSTORE_PATH \
      -u TVIUM_ANDROID_STORE_PASSWORD \
      -u TVIUM_ANDROID_KEY_ALIAS \
      -u TVIUM_ANDROID_KEY_PASSWORD \
      TVIUM_REQUIRE_ANDROID_RELEASE_SIGNING=true \
      flutter build apk --release --target-platform android-arm,android-arm64 \
      >"$output" 2>&1
); then
  echo 'Android release configuration accepted missing signing credentials.' >&2
  exit 1
fi

if ! grep -q 'Android release signing credentials are required' "$output"; then
  echo 'Android release configuration failed for an unexpected reason.' >&2
  tail -n 15 "$output" >&2
  exit 1
fi

# A release build must start a fresh daemon with the signing environment.
if [[ -f "$root/apps/tvium_app/android/gradlew" ]]; then
  bash "$root/apps/tvium_app/android/gradlew" \
    -p "$root/apps/tvium_app/android" --stop >/dev/null 2>&1 || true
fi

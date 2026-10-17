#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <Tvium.app path> <output.dmg path>" >&2
  exit 64
fi

app_path="$1"
output_path="$2"

if [[ ! -d "$app_path" || ! -f "$app_path/Contents/Info.plist" ]]; then
  echo "Invalid macOS application bundle: $app_path" >&2
  exit 66
fi

if [[ "$output_path" != *.dmg ]]; then
  echo "The output path must end in .dmg: $output_path" >&2
  exit 64
fi

if [[ -e "$output_path" ]]; then
  echo "Refusing to overwrite existing output: $output_path" >&2
  exit 73
fi

mkdir -p "$(dirname "$output_path")"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/tvium-dmg.XXXXXX")"

cleanup() {
  case "$staging_dir" in
    "${TMPDIR:-/tmp}"/tvium-dmg.*) rm -rf -- "$staging_dir" ;;
    *) echo "Skipped cleanup for unexpected path: $staging_dir" >&2 ;;
  esac
}
trap cleanup EXIT

/usr/bin/ditto "$app_path" "$staging_dir/Tvium.app"
ln -s /Applications "$staging_dir/Applications"

if /usr/sbin/diskutil image create -help >/dev/null 2>&1; then
  /usr/sbin/diskutil image create from \
    --format UDZO \
    --volumeName "Tvium" \
    "$staging_dir" \
    "$output_path"
else
  /usr/bin/hdiutil create \
    -volname "Tvium" \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$output_path"
fi

echo "Created $output_path"

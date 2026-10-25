#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS distribution gate test runs only on macOS."
  exit 0
fi

root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
gate="$root_dir/scripts/release/verify_macos_distribution.sh"
[[ -x "$gate" ]] || { echo "Missing executable macOS distribution gate." >&2; exit 1; }

fixture="$(mktemp -d "${TMPDIR:-/tmp}/tvium-macos-gate.XXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT
app="$fixture/Tvium.app"
mkdir -p "$app/Contents/MacOS"
cp /usr/bin/true "$app/Contents/MacOS/Tvium"
cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.tvium.releasegate.test</string>
<key>CFBundleExecutable</key><string>Tvium</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
EOF
codesign --force --sign - "$app" >/dev/null

if "$gate" "$app" "$fixture/absent.dmg" > "$fixture/output" 2>&1; then
  echo "The gate accepted an ad-hoc signed app." >&2
  exit 1
fi
if ! grep -q 'Developer ID Application' "$fixture/output"; then
  cat "$fixture/output" >&2
  echo "The gate did not explain the missing Developer ID signature." >&2
  exit 1
fi

echo "macOS distribution gate rejected an ad-hoc signed app."

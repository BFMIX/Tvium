#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/.config/tvium" "$fixture_dir/bin"
print -r -- 'synthetic-test-token' > "$fixture_dir/.config/tvium/tmdb-read-token"
chmod 600 "$fixture_dir/.config/tvium/tmdb-read-token"

cat > "$fixture_dir/bin/node" <<'MOCK_NODE'
#!/bin/zsh
[[ -n "${TMDB_READ_ACCESS_TOKEN:-}" ]] || exit 42
while true; do sleep 1; done
MOCK_NODE
cat > "$fixture_dir/bin/flutter" <<'MOCK_FLUTTER'
#!/bin/zsh
[[ "$*" == *'--dart-define=TVIUM_METADATA_GATEWAY=http://127.0.0.1:8787'* ]] || exit 43
MOCK_FLUTTER
chmod +x "$fixture_dir/bin/node" "$fixture_dir/bin/flutter"

HOME="$fixture_dir" PATH="$fixture_dir/bin:$PATH" \
  zsh "$repo_root/scripts/run_metadata_preview_macos.zsh" </dev/null

chmod 644 "$fixture_dir/.config/tvium/tmdb-read-token"
if HOME="$fixture_dir" PATH="$fixture_dir/bin:$PATH" \
  zsh "$repo_root/scripts/run_metadata_preview_macos.zsh" </dev/null 2>/dev/null; then
  print -u2 'The launcher accepted an insecure token file.'
  exit 1
fi

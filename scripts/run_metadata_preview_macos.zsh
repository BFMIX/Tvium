#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
gateway_dir="$repo_root/services/metadata_gateway"
app_dir="$repo_root/apps/tvium_app"

if [[ ! -t 0 ]]; then
  print -u2 'Run this script in an interactive Terminal.'
  exit 1
fi

read -rs 'tmdb_token?TMDB read access token (hidden): '
print
if [[ -z "$tmdb_token" ]]; then
  print -u2 'A TMDB token is required.'
  exit 1
fi

cd "$gateway_dir"
TMDB_READ_ACCESS_TOKEN="$tmdb_token" node src/server.js &
gateway_pid=$!
unset tmdb_token
trap 'kill "$gateway_pid" 2>/dev/null || true' EXIT INT TERM

cd "$app_dir"
flutter run -d macos \
  --dart-define=TVIUM_METADATA_GATEWAY=http://127.0.0.1:8787

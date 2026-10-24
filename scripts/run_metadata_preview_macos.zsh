#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
gateway_dir="$repo_root/services/metadata_gateway"
app_dir="$repo_root/apps/tvium_app"
token_path="$HOME/.config/tvium/tmdb-read-token"

if [[ -e "$token_path" ]]; then
  if [[ ! -f "$token_path" || -L "$token_path" ]]; then
    print -u2 'The local TMDB token must be a regular file.'
    exit 1
  fi
  token_mode="$(stat -f '%Lp' "$token_path")"
  if [[ "$token_mode" != 600 && "$token_mode" != 400 ]]; then
    print -u2 'Restrict the local TMDB token file to owner access (chmod 600).'
    exit 1
  fi
  tmdb_token="$(<"$token_path")"
elif [[ -t 0 ]]; then
  read -rs 'tmdb_token?TMDB read access token (hidden): '
  print
else
  print -u2 'Save a TMDB read token in ~/.config/tvium/tmdb-read-token or run interactively.'
  exit 1
fi

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

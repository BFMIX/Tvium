#!/usr/bin/env bash
set -euo pipefail

service_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$service_root/dist/pair"
cp "$service_root/src/tvium_presentation.html" "$service_root/dist/index.html"
cp "$service_root/src/pairing_phone.html" "$service_root/dist/pair/index.html"
cp "$service_root/src/pairing-phone.js" "$service_root/dist/pairing-phone.js"

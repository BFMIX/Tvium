#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <web build directory> <output.zip path>" >&2
  exit 64
fi

build_dir="$1"
output_path="$2"

if [[ ! -d "$build_dir" || ! -f "$build_dir/index.html" ]]; then
  echo "Invalid Flutter Web build directory: $build_dir" >&2
  exit 66
fi

if [[ "$output_path" != *.zip ]]; then
  echo "The output path must end in .zip: $output_path" >&2
  exit 64
fi

if [[ -e "$output_path" ]]; then
  echo "Refusing to overwrite existing output: $output_path" >&2
  exit 73
fi

mkdir -p "$(dirname "$output_path")"
output_dir="$(cd "$(dirname "$output_path")" && pwd)"
output_name="$(basename "$output_path")"

(
  cd "$build_dir"
  zip -q -r "$output_dir/$output_name" .
)

echo "Created $output_path"

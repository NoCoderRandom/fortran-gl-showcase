#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <frames_dir> <out.gif> <fps>" >&2
  exit 1
fi

frames_dir=$1
out_file=$2
fps=$3
palette_file=$(mktemp /tmp/fgs_palette_XXXXXX.png)
trap 'rm -f "$palette_file"' EXIT

ffmpeg -y \
  -framerate "$fps" \
  -i "${frames_dir}/frame_%06d.png" \
  -vf "palettegen" \
  "$palette_file"

ffmpeg -y \
  -framerate "$fps" \
  -i "${frames_dir}/frame_%06d.png" \
  -i "$palette_file" \
  -lavfi "paletteuse" \
  "$out_file"

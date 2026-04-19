#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <frames_dir> <out.mp4> <fps>" >&2
  exit 1
fi

frames_dir=$1
out_file=$2
fps=$3

ffmpeg -y \
  -framerate "$fps" \
  -i "${frames_dir}/frame_%06d.png" \
  -c:v libx264 \
  -preset slow \
  -crf 16 \
  -pix_fmt yuv420p \
  "$out_file"

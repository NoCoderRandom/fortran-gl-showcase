#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
bin_path="${root_dir}/build/bin/fortran_gl_showcase"
out_root="${1:-/tmp/fgs-gallery}"
fps="${2:-12}"
seconds="${3:-1}"
width="${4:-320}"
height="${5:-180}"

mkdir -p "$out_root"

scenes=(
  fractal_explorer
  mandelbulb_cathedral
  particle_galaxy
  procedural_waves
  hdr_bloom_demo
  tunnel_flythrough
  color_field
  combined_showcase
)

for scene in "${scenes[@]}"; do
  scene_dir="${out_root}/${scene}"
  rm -rf "$scene_dir"
  mkdir -p "$scene_dir"
  "$bin_path" --render "$scene" --seconds "$seconds" --fps "$fps" --width "$width" --height "$height" --out "$scene_dir"
  count=$(find "$scene_dir" -maxdepth 1 -name 'frame_*.png' | wc -l)
  if [[ "$count" -lt 1 ]]; then
    echo "render failed for ${scene}" >&2
    exit 1
  fi
done

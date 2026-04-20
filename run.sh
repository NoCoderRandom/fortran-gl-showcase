#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")" && pwd)
bin_path="${BUILD_DIR:-${root_dir}/build}/bin/fortran_gl_showcase"

if [[ ! -x "$bin_path" ]]; then
  "${root_dir}/scripts/build.sh"
fi

exec "$bin_path" "$@"

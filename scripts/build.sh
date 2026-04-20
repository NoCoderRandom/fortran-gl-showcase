#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
build_dir="${BUILD_DIR:-${root_dir}/build}"
build_type="${BUILD_TYPE:-Debug}"
generator="${CMAKE_GENERATOR:-Ninja}"

cmake -S "$root_dir" -B "$build_dir" -G "$generator" -DCMAKE_BUILD_TYPE="$build_type"
cmake --build "$build_dir"

echo "Build complete: ${build_dir}/bin/fortran_gl_showcase"

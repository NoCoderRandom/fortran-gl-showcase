#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script uses apt and must be run with sudo." >&2
  echo "Usage: sudo ./install_deps.sh" >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script currently supports Debian/Ubuntu systems with apt-get." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

packages=(
  build-essential
  cmake
  ninja-build
  pkg-config
  git
  gh
  gfortran
  libglfw3-dev
  libx11-dev
  libxi-dev
  libxrandr-dev
  libxcursor-dev
  libxinerama-dev
  mesa-utils
  ffmpeg
)

apt-get update
apt-get install -y "${packages[@]}"

echo "Dependencies installed."

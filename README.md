# Fortran GL Showcase

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Cinematic fractals and shader art in modern Fortran.

## Platform

Target environment: WSL2 Ubuntu 22.04/24.04 on Windows 11 with an NVIDIA GPU.

Install the baseline packages:

```bash
sudo apt install build-essential cmake ninja-build pkg-config git gh \
                 gfortran libglfw3-dev libx11-dev libxi-dev libxrandr-dev \
                 libxcursor-dev libxinerama-dev mesa-utils ffmpeg
```

Verify WSL2 OpenGL acceleration:

```bash
glxinfo -B | grep -E "OpenGL (renderer|version)"
```

Expected renderer: NVIDIA GeForce RTX 3070 or another hardware renderer, not `llvmpipe`.

## Build

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/bin/fortran_gl_showcase
```

## Scene List

- `empty_scene`: foundation clear pass used to validate the app loop and controls.

## Controls

| Key | Action |
| --- | --- |
| `Esc` | Quit |
| `F11` | Toggle fullscreen |

## Gallery

Screenshots belong in `docs/gallery/`.


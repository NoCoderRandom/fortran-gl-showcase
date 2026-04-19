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

## Scenes

- `Fractal Explorer`: Mandelbrot / Julia / Burning Ship
- `Mandelbulb Cathedral`: 3D raymarched fractal, cinematic light
- `Particle Galaxy`: GPU-simulated particle field
- `Procedural Waves`: shader-art surface
- `HDR Bloom Demo`: bright emissive shapes with bloom
- `Tunnel Flythrough`: procedural tube with palette animation
- `Color Field`: pure shader art, ambient screensaver
- `Combined Showcase`: flagship animated piece

## Controls

| Key | Action |
| --- | --- |
| `W` / `S` or `Up` / `Down` | Navigate the main menu |
| `Enter` | Launch the selected scene |
| `Esc` | Return to the menu, or quit from the menu |
| `F11` | Toggle fullscreen |
| `F12` | Log the screenshot placeholder message |

## Gallery

Screenshots belong in `docs/gallery/`.

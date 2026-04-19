# Fortran GL Showcase
> Cinematic fractals and shader art, written in modern Fortran.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![OpenGL](https://img.shields.io/badge/OpenGL-4.6%20preferred-blue)
![Fortran](https://img.shields.io/badge/Fortran-2018%2F2023-5b4b8a)

## Gallery

The gallery below is captured from the built-in offline renderer. Only
curated stills are committed under `docs/gallery/`; bulk render dumps
stay outside the repo.

| Scene | Preview |
| --- | --- |
| Fractal Explorer | ![Fractal Explorer](docs/gallery/fractal-explorer.png) |
| Mandelbulb Cathedral | ![Mandelbulb Cathedral](docs/gallery/mandelbulb-cathedral.png) |
| Particle Galaxy | ![Particle Galaxy](docs/gallery/particle-galaxy.png) |
| Procedural Waves | ![Procedural Waves](docs/gallery/procedural-waves.png) |
| HDR Bloom Demo | ![HDR Bloom Demo](docs/gallery/hdr-bloom-demo.png) |
| Tunnel Flythrough | ![Tunnel Flythrough](docs/gallery/tunnel-flythrough.png) |
| Color Field | ![Color Field](docs/gallery/color-field.png) |
| Combined Showcase | ![Combined Showcase](docs/gallery/combined-showcase.png) |

## Why Fortran?

The project leans heavily on numeric code. Deep fractal zooms, raymarch
camera paths, and deterministic timelines all benefit from explicit
precision and predictable floating-point behavior. Modern Fortran makes
`real64` the obvious tool instead of an awkward afterthought.

This codebase is also not using a “legacy Fortran” style. It uses
modules, derived types, type-bound procedures, submodules, allocatables,
and `iso_c_binding` to talk cleanly to GLFW and OpenGL. The language is
substantially different from the Fortran 77 stereotype many developers
still picture.

Finally, novelty matters. Most shader-demo repositories are C++ or
Rust. Building the same class of visuals in modern Fortran makes the
project more interesting both technically and educationally.

## Quick Start

Target environment: WSL2 Ubuntu 22.04/24.04 on Windows 11.

```bash
sudo apt install build-essential cmake ninja-build pkg-config git gh \
                 gfortran libglfw3-dev libx11-dev libxi-dev libxrandr-dev \
                 libxcursor-dev libxinerama-dev mesa-utils ffmpeg

git clone https://github.com/NoCoderRandom/fortran-gl-showcase.git
cd fortran-gl-showcase
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/bin/fortran_gl_showcase
```

Verify the renderer before judging performance:

```bash
glxinfo -B | grep -E "OpenGL (renderer|version)"
```

Hardware rendering is preferred. `llvmpipe` will work for development,
but it is much slower, especially for the combined scene.

## Controls

### Global

| Key | Action |
| --- | --- |
| `W` / `S` or `Up` / `Down` | Navigate menu |
| `Enter` | Launch selected scene |
| `Esc` | Return to menu or quit from menu |
| `F11` | Toggle fullscreen |
| `F12` | Log screenshot placeholder |

### Fractal Explorer

| Key | Action |
| --- | --- |
| `W A S D` / Arrows | Pan |
| `Q` / `E` / Mouse wheel | Zoom |
| `[` / `]` | Change fractal |
| `PgUp` / `PgDn` | Change palette |
| `T` | Cycle orbit trap |
| `Space` | Toggle autopilot |
| `H` | Toggle HUD |
| `R` | Reset |

### Mandelbulb Cathedral

| Key | Action |
| --- | --- |
| Mouse drag | Orbit |
| Mouse wheel | Radius |
| `1` / `2` / `3` | Quality preset |
| `F` | Mandelbulb / Menger |
| `R` | Reset |
| `H` | Toggle HUD |

### Particle Galaxy

| Key | Action |
| --- | --- |
| `Space` | Pause |
| `R` | Reseed |
| `1` / `2` / `3` | Preset |
| Mouse drag | Orbit |
| Mouse wheel | Dolly |
| `H` | Toggle HUD |

### Combined Showcase

| Key | Action |
| --- | --- |
| `Left` / `Right` | Seek ±1 second |
| `Space` | Pause / resume |
| `.` | Step one frame while paused |
| `R` | Restart |
| `Esc` | Return to menu |

## Rendering Your Own Videos

Render frames:

```bash
./build/bin/fortran_gl_showcase --render combined_showcase \
  --seconds 5 --fps 30 --width 640 --height 360 --out /tmp/fgs-smoke
```

Encode to MP4:

```bash
scripts/encode.sh /tmp/fgs-smoke /tmp/fgs-smoke.mp4 30
```

Encode to GIF:

```bash
scripts/encode_gif.sh /tmp/fgs-smoke /tmp/fgs-smoke.gif 30
```

Smoke-render all currently offline-capable scenes:

```bash
scripts/render_gallery.sh /tmp/fgs-gallery 12 1 320 180
```

## Scenes

### Fractal Explorer

Escape-time fractals rendered as a fullscreen shader with Mandelbrot,
Julia, and Burning Ship modes. It includes smooth coloring, palette
cycling, orbit-trap styling, and idle autopilot.

### Mandelbulb Cathedral

A distance-estimated 3D fractal scene with a Mandelbulb/Menger toggle,
soft shadows, ambient occlusion, fog, and orbit controls. This is the
main raymarching reference in the project.

### Particle Galaxy

A compute-driven particle field rendered with additive point sprites and
scene presets. It is designed as both a standalone scene and one act of
the combined showcase.

### Procedural Waves

Fullscreen shader-art surface with layered wave ridges, fake normals,
caustic glow, and a restrained cinematic grade.

### HDR Bloom Demo

An emissive stress-test scene built to drive the HDR bloom path with
rings, cores, spokes, and high-value highlights.

### Tunnel Flythrough

Palette-driven procedural tunnel motion rendered as a fullscreen shader,
intended as a compact travel/velocity piece in the menu lineup.

### Color Field

An ambient shader-art screensaver with drifting gradients, contour bands,
and low-intensity idle playback.

### Combined Showcase

A 60-second flagship sequence driven by a text timeline. It crossfades
from fractal zoom to Mandelbulb ascent to a particle lightwell finale
using the same HDR and bloom path as the standalone scenes.

## Architecture

The codebase is split into platform, GL interop, rendering, scene,
animation, and offline-export layers. See [ARCHITECTURE.md](ARCHITECTURE.md)
for the module-level walkthrough and [TECHNICAL_PAPER.md](TECHNICAL_PAPER.md)
for the deeper implementation write-up.

## Contributing

1. Add the new scene module under `src/scene/`.
2. Register it in `src/scene/scene_registry.f90`.
3. Document controls and behavior in `README.md` and the relevant docs file.
4. Build both configs and verify `--render` if the scene supports offline export.

Full guidance: [CONTRIBUTING.md](CONTRIBUTING.md)

## Docs

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [TECHNICAL_PAPER.md](TECHNICAL_PAPER.md)
- [docs/POSTPROCESS.md](docs/POSTPROCESS.md)
- [docs/ANIMATION.md](docs/ANIMATION.md)
- [docs/FRACTALS_2D.md](docs/FRACTALS_2D.md)
- [docs/FRACTALS_3D.md](docs/FRACTALS_3D.md)
- [docs/PARTICLES.md](docs/PARTICLES.md)
- [docs/SHADER_ART.md](docs/SHADER_ART.md)

## License

MIT. Third-party notices live in [THIRD_PARTY.md](THIRD_PARTY.md) and
under `third_party/`.

# Architecture

`Fortran GL Showcase` is organized as a small modern-Fortran rendering
runtime with clear module boundaries between platform bootstrapping,
OpenGL interop, scene logic, animation, and offline export.

## Module Map

```text
main
 └─ showcase_app
    ├─ platform_window / platform_input
    ├─ gl_loader / gl_debug
    ├─ render_post_process / text_renderer / fullscreen_quad / shader
    ├─ app_runtime
    ├─ scene_registry
    │  └─ scene_*
    └─ anim_*
```

## Lifecycle

1. `main` parses CLI flags such as `--scene` and `--render`.
2. `showcase_app` creates a GLFW window, binds input, loads OpenGL
   entry points, registers scenes, and initializes the text renderer.
3. Each frame:
   - input is captured
   - runtime context is published through `app_runtime`
   - the active scene updates
   - the scene renders into the shared HDR target
   - `render_post_process` composites bloom and tone mapping
   - the final image is swapped to the window
4. Offline mode follows the same scene/post path, but uses a hidden
   window, fixed timestep progression, and `glReadPixels` export.

## Key Subsystems

### Platform

- `src/platform/window.f90`
  Owns GLFW startup, context negotiation, swap interval, fullscreen
  toggle, framebuffer sizing, and hidden-window support for offline
  rendering.
- `src/platform/input.f90`
  Poll-based keyboard, mouse, and scroll capture with a small Fortran
  state object.

### OpenGL Interop

- `src/gl/gl_loader.f90`
  Declares the OpenGL procedures and constants used by the runtime via
  `iso_c_binding`.
- `src/render/shader.f90`
  Compiles/link shader programs and reports OpenGL logs through the
  logger.

### Runtime Helpers

- `src/app/app_runtime.f90`
  Acts as the bridge from scenes back into the application. Scenes use
  it for input, elapsed time, framebuffer size, text drawing, and scene
  transition requests.
- `src/core/logger*.f90`
  Minimal structured log output for build/test/runtime feedback.

### Rendering

- `src/render/fullscreen_quad.f90`
  Reusable fullscreen triangle/quad submission path.
- `src/render/text_renderer.f90`
  Bitmap text overlay system for HUDs and menus.
- `src/render/post_process.f90`
  Shared HDR pipeline:
  - scene render target
  - bright-pass extraction
  - bloom pyramid
  - composite and tone mapping

### Scene System

- `src/scene/scene_base.f90`
  Abstract scene contract: `init`, `update`, `render`, `destroy`,
  `get_name`, and per-scene post settings.
- `src/scene/scene_registry.f90`
  Menu-visible scene catalog plus factory dispatch.
- `src/scene/scene_fractal2d.f90`
  Escape-time fractals with palette animation and HUD.
- `src/scene/scene_mandelbulb.f90`
  Raymarched Mandelbulb/Menger scene.
- `src/scene/scene_particles.f90`
  Particle simulation and additive draw path.
- `src/scene/scene_combined.f90`
  Timeline-driven flagship scene that reuses the visual language of the
  other scenes.

### Animation

- `src/anim/keyframe_track.f90`
  Named scalar tracks with linear, Catmull-Rom, or smoothstep
  interpolation.
- `src/anim/timeline.f90`
  Multi-track container with evaluation by absolute time.
- `src/anim/camera_spline.f90`
  Thin adapter from timeline tracks to camera position/look-at vectors.
- `src/anim/tiny_parser.f90`
  Plain-text timeline file loader.

### Offline Export

- `src/core/frame_export.f90`
  Writes frame dumps to PNG via a temporary PPM + `ffmpeg` conversion
  path.
- `scripts/encode.sh`
  Encodes PNG frame sequences to H.264 MP4.
- `scripts/render_gallery.sh`
  Low-resolution smoke render path for CI.

## Data Flow

```text
scene update
  -> scene render
  -> HDR scene texture
  -> bloom + tone map composite
  -> window backbuffer

offline render
  -> same post path
  -> glReadPixels
  -> PNG frames
  -> ffmpeg encode helpers
```

## Design Notes

- The scene interface is intentionally narrow. Scenes do not own the
  window, swap chain, or final post chain.
- Most rendering code is shader-driven, while Fortran is used for scene
  orchestration, parameter control, and data movement.
- The offline renderer shares the exact same render path as the
  interactive runtime, which keeps exported frames consistent with what
  the user sees on screen.

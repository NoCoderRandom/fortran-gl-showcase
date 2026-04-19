# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

- Initial scaffold with a GLFW window, empty scene registry, and build/docs baseline.
- Added a keyboard-driven main menu, embedded bitmap text renderer, and placeholder scene flow for the eight showcase entries.
- Replaced the `Fractal Explorer` stub with a real fullscreen shader scene featuring Mandelbrot, Julia, and Burning Ship modes, palette cycling, orbit traps, and idle autopilot.
- Added generated palette strip assets and fractal scene documentation.
- Replaced the `Mandelbulb Cathedral` stub with a staged raymarch scene featuring Mandelbulb and Menger distance estimators, lighting, soft shadows, ambient occlusion, fog, orbit-trap coloring, emissive creases, and an `F` toggle between fractals.
- Added auto-orbit, manual drag orbit, wheel radius control, quality presets, reset, and HUD support to `Mandelbulb Cathedral`.
- Replaced the `Particle Galaxy` stub with a GPU particle scene using a compute shader, SSBO-backed state, additive point-sprite rendering, presets, orbit camera controls, and a HUD.
- Added a shared HDR post-processing pipeline with bloom, tone mapping, vignette, grain, and optional chromatic aberration, plus per-scene look settings for the menu, fractal, mandelbulb, and particle scenes.
- Added the Prompt 7A animation foundation: keyframe tracks, timeline loading, camera spline evaluation, `assets/timelines/demo.tl`, and a dev-only `--scene anim_test` path for interpolation validation.
- Replaced the `Combined Showcase` placeholder with a real 60-second timeline-driven scene featuring fractal birth, Mandelbulb ascent, particle lightwell finale, smooth HDR crossfades, and timeline scrub controls.
- Added a first offline render CLI path with hidden-window frame export to PNG plus `scripts/encode.sh`, `scripts/encode_gif.sh`, and `scripts/render_gallery.sh`.
- Replaced the remaining placeholder menu entries with real shader-art scenes: `Procedural Waves`, `HDR Bloom Demo`, `Tunnel Flythrough`, and `Color Field`, and marked them offline-render capable.

# Post Processing

Prompt 6 adds a shared fullscreen post-processing pass on top of the scene
render path.

## Pipeline

1. Each scene renders into an HDR offscreen color target.
2. A bright-pass extracts emissive highlights using a configurable threshold.
3. A small bloom pyramid is built with downsample and upsample passes.
4. A final composite shader applies:
   - additive bloom
   - ACES or Reinhard tone mapping
   - optional chromatic aberration
   - vignette
   - film grain

## Scene Look Tuning

Each scene can override `get_post_settings()` and supply:

- `bloom_strength`
- `bloom_threshold`
- `tone_map_mode`
- `vignette_strength`
- `grain_strength`
- `chromatic_ab`

Current real scenes use different looks:

- `menu_scene`: restrained bloom and light vignette
- `fractal_explorer`: moderate bloom and cinematic grain
- `mandelbulb_cathedral`: stronger bloom and heavier vignette
- `particle_galaxy`: strong bloom with chromatic aberration enabled

Scenes without a custom override inherit the default `post_settings_t` values.

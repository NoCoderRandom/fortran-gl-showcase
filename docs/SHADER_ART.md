# Shader Art Scenes

The remaining four menu entries are lightweight fullscreen shader scenes.
They intentionally reuse the same scene/runtime path so they stay simple,
render offline cleanly, and fit the existing post-process pipeline.

## Procedural Waves

`Procedural Waves` layers several analytic sine fields into a height-like
surface, estimates a fake normal from local differences, and shades it
with a single directional light plus crest glow.

## HDR Bloom Demo

`HDR Bloom Demo` is a post-process stress scene. The shader writes values
well above `1.0`, especially in ring edges and flare spokes, so the
shared bloom pass has obvious material to work with.

## Tunnel Flythrough

`Tunnel Flythrough` is a compact tunnel illusion driven by radial depth
warping and palette animation. It is not a full raymarcher; it is meant
to be a lighter procedural motion piece.

## Color Field

`Color Field` uses value-noise layers and slow palette drift to produce
an ambient screensaver scene that still benefits from the shared film
grain and tone-map path.

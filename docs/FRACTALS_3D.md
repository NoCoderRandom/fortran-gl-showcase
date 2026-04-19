# Mandelbulb Cathedral Notes

The current `Mandelbulb Cathedral` scene is the Prompt 4 Stage H baseline:

- fullscreen ray generation in the fragment shader
- Mandelbulb distance estimator
- sphere-tracing / raymarching toward the surface
- tetrahedral normal estimate
- single directional Lambert light with a small ambient floor
- soft shadows from a secondary march toward the key light
- ambient occlusion from samples taken along the surface normal
- exponential distance fog with a warm tint
- orbit-trap color modulation from axis and origin proximity
- emissive creases on higher-iteration terminations
- `F` toggle between Mandelbulb and Menger sponge distance estimators
- black background

At each pixel, the shader builds a camera ray from the fullscreen triangle,
marches forward by the distance estimator value, and stops when the estimated
distance falls below an epsilon tied to the screen-space ray footprint:

`eps = max(floor_eps, pixel_radius * t)`

That scaling keeps the hit test from becoming too loose at distance while still
avoiding needless micro-steps near the camera.

The current integration also includes:

- auto-orbit camera
- manual orbit override with left-mouse drag
- mouse-wheel radius control
- `1/2/3` quality presets mapped to the step budget
- `R` reset and `H` HUD toggle

# Particle Galaxy Notes

`Particle Galaxy` keeps particle state on the GPU in a single SSBO with the
layout:

- `position_age`
- `velocity_mass`
- `color`

The compute shader updates the whole buffer in workgroups of `256` threads. The
simulation uses a softened central pull, a tangential bias so the cloud forms a
disk instead of collapsing inward, and a curl-noise perturbation so the motion
does not read as rigid concentric rings.

Particles are rendered as additive point sprites. The vertex shader derives a
screen-facing point size from camera depth, and the fragment shader applies a
soft gaussian-style falloff so each sprite behaves like a little light source.
That additive approach works well here because the particles are emissive and
small enough that exact depth-sorted transparency is not worth the cost.

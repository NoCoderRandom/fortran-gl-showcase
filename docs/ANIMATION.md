# Animation

Prompt 7 introduces a tiny timeline system for deterministic scene control.

## Timeline Format

```text
# comments are ignored
duration 10.0

track bloom_strength linear
    0.0   0.3
    5.0   1.4
   10.0   0.6
```

Rules:

- `duration <seconds>` defines the loop length.
- `track <name> <mode>` starts a new track.
- following indented lines are `time value` pairs.
- blank lines and `#` comments are ignored.
- duplicate `track` names are allowed; the last declaration wins.
- malformed lines stop with a line-numbered error.

Interpolation modes:

- `linear`
- `cubic` (Catmull-Rom)
- `smoothstep`

## Worked Example

`assets/timelines/demo.tl` drives:

- `camera_pos_x/y/z`
- `camera_look_x/y/z`
- `bloom_strength`

The dev-only `anim_test` scene can be launched with:

```bash
./build/bin/fortran_gl_showcase --scene anim_test
```

It logs each track value once per second so interpolation can be checked
before the combined showcase scene is built on top of the same system.

## Combined Showcase

`assets/timelines/combined.tl` now drives the flagship scene:

- Act I: fractal zoom and bloom rise
- Act II: Mandelbulb ascent and warm grading
- Act III: particle spiral with peak bloom

The scene evaluates from absolute timeline time, supports pause/scrub,
and applies a 1.5-second black-in plus a final 3-second fade to black.

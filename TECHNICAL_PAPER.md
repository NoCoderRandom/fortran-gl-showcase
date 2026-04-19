# Technical Paper

## 1. Abstract

`Fortran GL Showcase` is a graphics demo collection built in modern
Fortran with OpenGL, GLFW, compute shaders, HDR post-processing, and a
deterministic timeline system. The project aims to demonstrate that
Fortran in 2026 is viable for interactive graphics work when the code is
structured around explicit module boundaries and `iso_c_binding`
interop. The codebase includes 2D escape-time fractals, 3D
distance-estimated fractals, a GPU particle scene, a shared bloom and
tone-mapping path, an animation timeline, and an offline frame export
pipeline. This document explains the technical decisions behind those
systems, the math used in the shader stages, the benefits and awkward
parts of implementing them in Fortran, and the practical lessons from
running OpenGL on WSL2.

## 2. Introduction & Motivation

The default expectation for graphics programming is still C++ first,
with Rust, C, and engine-specific scripting ecosystems following close
behind. Fortran rarely appears in that conversation, even though modern
Fortran remains excellent at expressing numeric code and remains backed
by mature optimizing compilers. That gap is exactly what motivated this
project: build something visually ambitious enough that the language
choice is surprising, but technically grounded enough that the result is
useful as a real reference.

Fortran is particularly well-suited to numerically sensitive code. Its
type system encourages explicit precision, and double precision
(`real64`) is a first-class, ergonomic choice instead of a niche
optimization escape hatch. That matters in fractal work. Deep zooms,
camera paths, and time-evaluated interpolation all benefit from code
that stays precise by default.

The second motivation is educational. Many developers still associate
Fortran with fixed-form source, COMMON blocks, and Fortran 77-era style.
That is not the language used here. This project uses free-form source,
modules, derived types, type-bound procedures, submodules,
`iso_c_binding`, allocatables, and a modular application structure. The
result is not “Fortran pretending to be C++”, but modern Fortran used as
its own language for a contemporary graphics program.

## 3. System Architecture

The application is organized around a small runtime shell and
self-contained scenes. The entry point parses CLI flags and dispatches
into either interactive mode or offline render mode. The main
application object owns the window, input state, text renderer, scene
registry, active scene, and post-process stack.

```text
main
 ├─ CLI parsing
 └─ showcase_app
    ├─ platform_window
    ├─ platform_input
    ├─ gl_loader / gl_debug
    ├─ render_shader
    ├─ render_fullscreen_quad
    ├─ render_text_renderer
    ├─ render_post_process
    ├─ scene_registry
    ├─ scene_*
    └─ anim_*
```

Each frame follows the same sequence:

1. Poll window events and capture input.
2. Advance the frame clock.
3. Publish runtime state through `app_runtime`.
4. Update the active scene.
5. Bind the shared HDR scene target.
6. Render the scene.
7. Run bloom/tone-map composite.
8. Present the backbuffer.

Scenes themselves do not own swap behavior or final framebuffer
presentation. They render into whatever target the runtime has already
bound. This is the crucial architectural decision that keeps post
processing centralized and makes offline rendering practical. The same
scene code can run interactively or as part of a frame export without
duplicating logic.

## 4. Rendering Foundations

The target runtime environment is WSL2 Ubuntu on Windows 11 with an
NVIDIA GPU. In practice, that also means the code has to survive
software-fallback paths such as `llvmpipe` during development or when
WSLg routing is imperfect. The window layer negotiates a core OpenGL
context, preferring modern versions and falling back when necessary.

OpenGL interop is handled manually through `iso_c_binding`. Rather than
pulling a heavyweight binding generator into the runtime, the project
declares only the functions and constants it actually uses. This keeps
the Fortran side readable:

```fortran
interface
  subroutine gl_uniform1f(location, value) bind(C, name="glUniform1f")
    import :: c_float, c_int
    integer(c_int), value :: location
    real(c_float), value :: value
  end subroutine gl_uniform1f
end interface
```

Shader compilation is centralized in `render_shader`. Fullscreen
presentations use a single reusable fullscreen triangle/quad helper so
that post and scene compositors do not each reinvent the draw path. HDR
scene targets use `GL_RGBA16F` rather than packed alternatives. The
reason is simple: the project values predictable precision and a clean
post pipeline over minor bandwidth savings.

## 5. 2D Escape-Time Fractals

The `Fractal Explorer` scene implements Mandelbrot, Julia, and Burning
Ship escape-time fractals in a fullscreen fragment shader. Each pixel
maps to a point in the complex plane. The iteration repeatedly applies a
complex recurrence until the magnitude exceeds a bailout radius or a
maximum iteration count is reached.

For Mandelbrot:

`z_{n+1} = z_n^2 + c`, with `z_0 = 0`

For Julia:

`z_{n+1} = z_n^2 + k`, with `z_0 = pixel_position`

For Burning Ship:

`z_{n+1} = (|Re(z_n)| + i|Im(z_n)|)^2 + c`

Naive coloring based on the integer iteration count produces obvious
bands. The project instead uses smooth coloring, based on the familiar
log-log escape refinement:

`μ = n + 1 - log(log(|z|)) / log(2)`

That value is normalized and used to sample a palette texture. The
palettes themselves are generated offline and uploaded as 1D-like strips
stored in a 2D texture of height 1.

Orbit traps are used as additional stylistic control. Instead of only
using the escape count, the shader also measures how close the orbit
came to simple geometric features during iteration, then uses that as an
extra modulation channel. This creates more structured, less uniformly
striped color fields.

## 6. Distance-Estimated 3D Fractals

The `Mandelbulb Cathedral` scene is built around signed/distance-like
estimators rather than explicit polygonal geometry. The shader traces a
ray from the camera into the scene and advances along the ray by the
estimated distance to the nearest surface. This sphere-tracing approach
is efficient when the distance estimate is reasonably conservative.

The Mandelbulb estimator derives from repeated conversion between
Cartesian and spherical form. The key idea is that a power operation in
spherical coordinates creates a 3D analogue of the 2D power map used in
complex fractals. The distance estimate uses the running derivative:

`d ≈ 0.5 * log(r) * r / dr`

The Menger sponge path uses repeated folds, sorting, and scale/translate
operations. It is less smooth than the Mandelbulb but well-suited to the
same sphere-tracing framework.

Normals are estimated numerically using a tetrahedral sampling pattern:

```text
n ≈ normalize(
   e.xyy * d(p + e.xyy) +
   e.yyx * d(p + e.yyx) +
   e.yxy * d(p + e.yxy) +
   e.xxx * d(p + e.xxx))
```

This uses four offset samples instead of a full six-sample central
difference and gives a good balance of cost and stability.

Soft shadows use the common penumbra estimate described by Inigo Quilez:

`shadow = min(shadow, k * distance / travel)`

Ambient occlusion is approximated by sampling the distance field along
the normal. If the field rises more slowly than expected, geometry is
nearby and the point is considered occluded. Fog is exponential in ray
travel distance, helping push the scene toward a cinematic rather than
purely diagnostic look.

## 7. GPU Particle Simulation

`Particle Galaxy` uses a compute-shader update plus a separate draw
shader. Simulation state lives in an SSBO using a tightly packed
`std430`-style layout. Each particle stores position, age, velocity, and
color modulation data in a fixed float stride.

The compute pass updates particles in parallel, with workgroup sizing
chosen for straightforward dispatch:

`num_groups_x = ceil(particle_count / 256)`

The integrator is intentionally simple. This is not a physically
accurate N-body solver. Instead it is an aesthetic simulation that uses
drag, lifetime, tangential motion, and seeded perturbation to produce
stable swirling fields quickly. That tradeoff is appropriate for a demo
project: predictable motion and visual structure matter more than
astronomical realism.

The draw pass renders point sprites with additive blending. In the
fragment shader, `gl_PointCoord` is used to create circular falloff:

```glsl
vec2 p = gl_PointCoord * 2.0 - 1.0;
float radius2 = dot(p, p);
if (radius2 > 1.0) discard;
float falloff = exp(-3.6 * radius2);
```

This makes each point behave more like a small glowing sprite than a
hard raster point, which is essential for bloom to read correctly.

## 8. HDR + Bloom + Tone Mapping

Prompt 6 added a shared HDR post-process path. Scenes render into an
`RGBA16F` target, allowing values greater than `1.0`. Those high-intensity
values are the basis for convincing bloom. If a scene never emits HDR
values above `1.0`, bloom has almost nothing to work with.

The bloom path is a bright-pass plus a compact downsample/upsample
pyramid. The project uses a dual-filter style chain rather than a full
multi-pass separable gaussian. The reasons are familiar:

- fewer passes
- lower bandwidth
- softer large-radius glow without excessive halo width

Tone mapping supports ACES and Reinhard. The ACES fit used here follows
the widely cited Narkowicz approximation:

`ACES(x) = clamp((x*(a*x+b)) / (x*(c*x+d)+e), 0, 1)`

ACES generally produces a more filmic shoulder and nicer highlight roll
off. Reinhard remains useful as a simpler baseline and as a debugging
comparison.

sRGB handling is deliberately single-path: the final composite applies
gamma in shader rather than relying on an sRGB default framebuffer. The
important rule is not which method is chosen, but that both are not
applied at once.

## 9. Animation System

Prompt 7 introduced a deterministic timeline layer for the combined
scene. A `timeline_type` owns named scalar tracks, each with one of
three interpolation modes:

- linear
- smoothstep
- cubic Catmull-Rom

Catmull-Rom is useful because it passes through the keyed values while
remaining local and relatively cheap:

`P(t) = 0.5 * (2P1 + (-P0 + P2)t + (2P0 - 5P1 + 4P2 - P3)t² + (-P0 + 3P1 - 3P2 + P3)t³)`

Timeline files are plain text on purpose. The parser is tiny, easy to
debug, and has no dependency on YAML or JSON libraries. Determinism is
the most important property: the combined scene is evaluated from
absolute time `t`, not accumulated frame history. That keeps offline
frame export consistent across different framerates.

## 10. Offline Rendering Pipeline

The offline renderer reuses the interactive scene pipeline almost
exactly. The difference is that it creates a hidden GLFW window, fixes
the timestep to `1/fps`, and reads back the final LDR image after the
post process pass.

The current exporter writes a temporary PPM stream and converts it to
PNG through `ffmpeg`. This is a pragmatic bridge until a vendored image
writer is added. It preserves the important project property: exported
frames go through the same scene, HDR, bloom, and tone-map path as the
interactive runtime.

The encode helpers use:

- H.264 via `libx264`
- `-crf 16`
- `-preset slow`
- `yuv420p` for broad player compatibility

These are conservative defaults that work on typical systems without
requiring exotic playback support.

## 11. Performance Observations

Performance depends heavily on whether WSL2 is using hardware
acceleration or falling back to `llvmpipe`. On proper GPU routing, the
menu and lighter scenes are responsive. On software rendering, the
combined scene and raymarched scenes become much slower, especially when
timeline scrubbing forces more expensive redraw patterns.

Broadly:

- 2D fractals are shader-heavy but still relatively cheap.
- The Mandelbulb scene is dominated by raymarch step count and normal /
  shadow / AO sampling.
- The particle scene scales mostly with particle count and additive
  draw cost.
- The combined scene pays the highest cost because it can render two HDR
  scenes during crossfades and then still run post.

The next optimization targets would be:

1. reduce raymarch cost adaptively during motion
2. trim particle counts for the interactive presets
3. reduce temporary compositing overhead in the combined scene
4. move more gallery capture work to offline mode where framerate is not
   a constraint

## 12. Lessons Learned

Modern Fortran made several parts of the project easier than expected.
Modules and derived types keep the codebase coherent. `real64` is
pleasant to use. The compiler-generated optimization quality on numeric
code remains strong.

The awkward part is C interop verbosity. OpenGL and GLFW are still C
APIs, so even simple operations require explicit interface blocks,
careful pointer handling, and value semantics discipline. None of that
is conceptually difficult, but it is undeniably more verbose than in a
language with a richer native FFI story.

WSL2 was another recurring lesson. The project itself can be correct
while the effective renderer is still `llvmpipe`. That makes visual
debugging harder because “the app is slow and looks wrong” can be either
an algorithm problem or an environment problem. The practical fix was to
treat the graphics path as a system-level dependency and verify it
explicitly rather than assuming all OpenGL sessions are equivalent.

Bloom tuning also reinforced a standard post-processing lesson: if a
scene looks bad with bloom, the right fix is almost never “just turn it
up.” Usually the issue is threshold, HDR source values, or the order of
operations relative to tone mapping.

## 13. Future Work

There is still clear room to extend the project:

- audio-reactive parameters
- additional fractal families
- a proper vendored PNG writer path
- offline-only hero-frame rendering
- a lightweight live parameter UI
- more complete gallery capture for every menu scene

The important part is that the current foundation supports those
extensions cleanly. The scene model, post path, timeline system, and
offline renderer are all modular enough to build on.

## 14. References

- Inigo Quilez, distance functions, soft shadows, and ambient
  occlusion: https://iquilezles.org/
- Daniel White / Paul Nylander, Mandelbulb derivation and distance
  estimation notes
- Krzysztof Narkowicz, ACES filmic tone mapping fit:
  https://knarkowicz.wordpress.com/
- Ashima Arts / Stefan Gustavson, simplex noise:
  https://github.com/ashima/webgl-noise
- Marius Bjørge, dual-filter bloom presentation and related talks
- Fragmentarium and related fractal resources by Mikael H. Christensen

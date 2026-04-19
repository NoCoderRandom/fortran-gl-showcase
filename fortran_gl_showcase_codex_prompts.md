# Fortran GL Showcase — 8 Codex Build Prompts (v2)

A staged build plan for a **Modern Fortran (2018 / 2023) + OpenGL 4.6** visual
showcase application, designed to run on **WSL2 Ubuntu** with an **NVIDIA RTX
3070**, managed as a professional GitHub repository with gallery screenshots
and a technical paper documenting how it was built.

---

## How to use this document

1. Read the **Environment baseline**, **Universal rules**, and **Dependency
   policy** sections below. These apply to *every* prompt and should be
   included with each Codex task.
2. Feed the prompts to Codex **one at a time, in order**. Each prompt ends
   with a **Self-check** block — Codex must run it and report the results
   before you move on.
3. After each successful prompt: commit, tag (`prompt-N-done`), push, and
   take a screenshot. Drop the screenshot into `docs/gallery/`.
4. If a prompt breaks something, stay in that prompt's scope to fix it.
   Do not jump ahead hoping the next prompt will fix the previous one.

---

## Environment baseline

```
Platform:       WSL2 Ubuntu 22.04 or 24.04 (Windows 11 host)
GPU:            NVIDIA RTX 3070 (8 GB), OpenGL 4.6 core, compute-capable
Compiler:       gfortran 13+ (Fortran 2008 / 2018 / 2023: submodules,
                 ISO_C_BINDING, implicit none (type, external),
                 error stop with message, select type)
Build system:   CMake >= 3.20 + Ninja
Windowing:      GLFW (system: libglfw3-dev)
GL loader:      glad (GL 4.6 core, generated once, vendored) or GLFW's own
Image I/O:      stb_image_write.h (single-header, vendored third_party/)
Video:          ffmpeg (scripts only; not linked)
Git hosting:    GitHub (public repo, MIT license)

WSL2 GPU sanity check (must pass before coding starts):
    sudo apt install mesa-utils
    glxinfo -B | grep -E "OpenGL (renderer|version)"
  Expected renderer: NVIDIA GeForce RTX 3070 (not llvmpipe).
  If llvmpipe: install NVIDIA's Windows driver with WSL2 support,
  then `wsl --shutdown` and retry.

One-time apt install on a fresh clone:
    sudo apt install build-essential cmake ninja-build pkg-config git gh \
                     gfortran libglfw3-dev libx11-dev libxi-dev libxrandr-dev \
                     libxcursor-dev libxinerama-dev mesa-utils ffmpeg
```

---

## Universal rules (include with EVERY prompt)

> Copy this block into the top of each prompt you give Codex. It is the
> single most important part of this document — without it, Codex will
> over-engineer, drift, and leak personal info into the repo.

```
Universal rules (apply to this prompt and every prompt in this project):

1. SIMPLICITY FIRST
   Prefer simple, working code over complete or perfect code. Do not add
   features, abstractions, config systems, helper layers, or files that
   were not explicitly requested in this prompt. When in doubt, leave it
   out — we can add it in a future prompt.

2. MINIMAL MODULES
   Target under ~200 lines per file for v1. You can refactor later
   prompts; you cannot un-overengineer a foundation.

3. TEST AND DEBUG BEFORE "DONE"
   Before declaring this prompt complete, you must:
     a. Build with zero warnings on -Wall -Wextra (Release and Debug).
     b. Launch the binary; confirm the new feature visibly works.
     c. Confirm every feature from previous prompts still works.
     d. Run the Self-check block at the bottom of this prompt and paste
        its output into the commit message or PR description.
   If any check fails, fix it inside this prompt's scope. Do not defer.

4. GIT AND GITHUB DISCIPLINE
     - Branch:   git checkout -b prompt-N-<short-slug>
     - Commits:  focused, imperative, prefixed "prompt-N: ..."
                 (e.g. "prompt-3: add smooth escape-time coloring")
                 No "wip", "stuff", "updates", or emoji-only messages.
     - Merge:    git merge --no-ff prompt-N-<slug> on main
     - Tag:      git tag prompt-N-done
     - Push:     git push origin main --tags
     - CHANGELOG.md gets a bullet under [Unreleased] for every
       user-visible change.

5. NO PERSONAL INFORMATION, EVER
   Nothing in the repository may contain:
     - Real names, email addresses, phone numbers
     - Home directory paths (/home/<user>/, /mnt/c/Users/<user>/)
     - Windows usernames, machine hostnames
     - API keys, tokens, SSH keys, .env contents
     - Screenshots containing window titles from other apps,
       taskbars, or personal desktops
   The user configures git user.name and user.email themselves — do
   not hard-code them. For placeholder authorship in docs, use
   "Project Author". Scrub any accidental personal paths from logs,
   comments, and error messages before committing.

6. README AND DOCS STAY IN SYNC
   When this prompt adds a user-visible feature (scene, key binding,
   CLI flag, asset), update README.md's relevant section in the same
   commit. Add a gallery placeholder under docs/gallery/ if a new
   scene was added.

7. DEPENDENCY POLICY (FULL VERSION BELOW)
   Short version: MIT/BSD/Apache/zlib/CC0 only. Prefer single-header
   vendored libs. Document every dep in THIRD_PARTY.md. Credit adapted
   shader snippets with source URL and license in a comment. No large
   engines or frameworks.
```

---

## Dependency policy (full)

```
Allowed licenses for vendored code and dependencies:
  MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0, zlib, Unlicense, CC0, ISC.

Forbidden licenses (incompatible with our MIT project):
  GPL (any version), LGPL, AGPL, CC-BY-SA, or any copyleft / share-alike.
  If a license is unclear or missing, do not use it.

System packages are fine for heavy infrastructure:
  GLFW, OpenGL, libc, ffmpeg (invoked as a subprocess, not linked).
  Everything else: prefer single-header libs vendored under third_party/.

When you add any dependency or adapted code:
  1. Vendor single-header libs under third_party/<libname>/.
  2. Copy the upstream LICENSE file next to the header.
  3. Add an entry to THIRD_PARTY.md with:
        - Name
        - Version or commit hash
        - License (SPDX identifier)
        - Upstream URL
        - One-line purpose in this project
        - Any modifications made (list each, with "// MODIFIED:" markers
          in the code itself)
  4. If you adapt a shader snippet from Shadertoy / a blog / a paper,
     add a comment at the top of the shader:
        // Adapted from: <URL>
        // Original author: <name>
        // License: <SPDX> (verified <date>)

Use known-good implementations instead of writing from scratch for:
  - Noise functions — Ashima / Stefan Gustavson simplex noise
  - Shader hashes — pcg or "hash without sine" variants
  - Tone mapping — Narkowicz ACES fit, Reinhard-Jodie
  - Fractal distance estimators — Mikael H. Christensen's Fragmentarium
    references and Inigo Quilez's published formulas
  - Soft shadows / AO in raymarching — Inigo Quilez's standard formulas

Do NOT pull in:
  - Large engines or frameworks (Raylib, SDL2, Qt, Magnum, bgfx, etc.)
    We want to own our rendering pipeline — that is the point.
  - Autotools-based libs that need nested build systems
  - Anything "free for non-commercial" or with a CLA
  - Anything with unclear license status

When in doubt, write it ourselves. The project's value is the hand-built
Fortran + OpenGL pipeline, not gluing libraries together.
```

---

## Prompt 1 — Foundation, architecture, Git, GitHub repo

```
[Paste Universal rules and Dependency policy first, then:]

Create the project "Fortran GL Showcase" — a modern Fortran + OpenGL
desktop application, designed for GitHub presentation and later video
capture. This prompt builds ONLY the foundation. No demo scenes, no
post-processing, no fractals yet.

Target platform:
- WSL2 Ubuntu 22.04/24.04 on Windows 11
- NVIDIA RTX 3070, OpenGL 4.6 core profile
- gfortran 13+, Fortran 2018/2023 features required (submodules,
  ISO_C_BINDING, `implicit none (type, external)`, `error stop "msg"`,
  abstract types with deferred type-bound procedures)
- CMake >= 3.20 with Ninja
- GLFW (system) + glad (vendored) for GL function loading

Architecture (one concern per module, aim for < 200 lines per file):
  src/core/kinds.f90             real32 / real64 / C interop kinds
  src/core/logger.f90            leveled logging to stdout
  src/core/timing.f90            monotonic clock, delta time
  src/platform/window.f90        GLFW wrapper (abstract type)
  src/platform/input.f90         key state, edge events
  src/gl/gl_loader.f90           ISO_C_BINDING wrappers (only calls we use)
  src/gl/gl_debug.f90            KHR_debug callback in Debug builds
  src/render/shader.f90          shader_program type, uniform helpers
  src/render/fullscreen_quad.f90 cached VAO/VBO for post-process quads
  src/scene/scene_base.f90       abstract type, deferred init/update/render
  src/scene/scene_registry.f90   registers scenes by name with metadata
  src/app/app.f90                owns window, registry, current scene, loop
  src/main.f90                   tiny entry point (< 40 lines)

Minimum runnable behavior for this prompt ONLY:
- Window opens at 1280x720, titled "Fortran GL Showcase".
- Clears to a subtle dark-gray every frame.
- F11 toggles fullscreen, Esc quits.
- A placeholder "empty_scene" is registered and active by default.
- Frame time and FPS logged once per second.

Git + GitHub setup (do this as part of the prompt):
1. Initialize git, create .gitignore (build/, .cache/, out/, *.o, *.mod,
   *.png except docs/gallery/, *.mp4, .vscode/, .idea/, local.cmake).
2. Add LICENSE (MIT, holder: "Project Author", year: current year).
3. Add README.md with: one-line tagline, WSL2 setup (apt install line +
   glxinfo check), build instructions, "scene list" placeholder, MIT
   badge, controls table stub.
4. Add CHANGELOG.md with [Unreleased] section.
5. Add ARCHITECTURE.md explaining the module layout in plain English.
6. Add THIRD_PARTY.md seeded with the glad entry.
7. Add scripts/check_gpu.sh that runs glxinfo -B and fails loudly if
   renderer contains "llvmpipe".
8. First commit on `main`: "prompt-1: initial project scaffold".
9. Create the GitHub repository:
   - Try `gh repo create fortran-gl-showcase --public --source=. --push
     --description "Cinematic fractals and shader art in modern Fortran"`
   - If `gh` is not authenticated: print exact manual instructions
     (create repo on github.com, then `git remote add origin ...;
     git push -u origin main`). Do NOT fail the prompt on this —
     repo creation is a one-time step the user may do manually.
10. Tag `prompt-1-done` and push tag.

Anti-scope (do NOT do any of these in Prompt 1):
- No menu UI
- No text rendering
- No fractals, raymarching, particles, or post-processing
- No CI config yet (comes in Prompt 8)
- No "future-proofing" abstractions for features not yet requested

Self-check (run and report output):
  [ ] cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release  succeeds
  [ ] cmake --build build  succeeds with zero warnings
  [ ] scripts/check_gpu.sh prints the NVIDIA renderer
  [ ] ./build/fortran_gl_showcase opens a 1280x720 dark-gray window
  [ ] F11 toggles fullscreen, Esc exits cleanly (exit code 0)
  [ ] FPS log line appears within the first 2 seconds
  [ ] git log --oneline shows exactly one commit
  [ ] grep -rn -E "(/home/|/mnt/c/Users/)" . --exclude-dir=build
      returns nothing (no personal paths leaked)
```

---

## Prompt 2 — Main menu, bitmap text rendering, scene selection

```
[Universal rules + Dependency policy]

Add a main menu and a simple text renderer so Fortran GL Showcase feels
like a real application, not a test harness.

Text rendering (smallest thing that works):
- Embed an 8x8 or 8x16 ASCII bitmap font as a uint8 array compiled
  into the binary (generate via a small Python script committed at
  tools/gen_font.py, run once, emit src/render/font_data.f90).
- Upload as a single-channel R8 texture at startup.
- Expose:
    call text%draw(str, x_px, y_px, scale, rgba)
  where (x_px, y_px) is the top-left in pixels, scale is an integer >=1.
- Draw text as batched textured quads in screen space — one draw call
  per `text%draw` call is fine for now.

Menu scene:
- Title:     "FORTRAN GL SHOWCASE" (large, centered, top third)
- Subtitle:  "Modern Fortran 2018 / 2023  •  OpenGL 4.6  •  WSL2 + NVIDIA"
- Scene list (read from scene_registry, not hard-coded):
    1. Fractal Explorer     — Mandelbrot / Julia / Burning Ship
    2. Mandelbulb Cathedral — 3D raymarched fractal, cinematic light
    3. Particle Galaxy      — GPU-simulated particle field
    4. Procedural Waves     — shader-art surface
    5. HDR Bloom Demo       — bright emissive shapes with bloom
    6. Tunnel Flythrough    — procedural tube with palette animation
    7. Color Field          — pure shader art, ambient screensaver
    8. Combined Showcase    — flagship animated piece
- Selected entry: highlighted with accent color + left chevron "▸"
- Background: very subtle animated dark gradient (NOT flashy).
- Footer (small, dim):
    "↑ ↓  navigate    ⏎  select    Esc  back    F11  fullscreen    F12  screenshot"

Scene registry updates:
- Each registered scene now carries: display_name, short_description,
  factory procedure. The menu iterates the registry to build its list.
- Adding a future scene must NOT require editing menu_scene.

Input / flow:
- Up/Down (and W/S) navigate; wraps.
- Enter: instantiate and switch to the selected scene.
- Esc (from any non-menu scene): return to menu, free the old scene.
- F12: log "screenshot: not yet implemented" (real export in Prompt 8).

Stub scenes:
- Register all 8 scene entries even though only empty_scene exists.
  Entries 1–8 can all instantiate the same placeholder "coming soon"
  scene that shows the scene name as big text on a dark background.
  This lets the menu be exercised end-to-end right now.

Anti-scope:
- No font shaping, kerning, Unicode, or TTF. ASCII bitmap only.
- No click/mouse input on menu yet — keyboard only.
- Do NOT switch to an ImGui or similar UI lib.

README update:
- Fill in the Controls table with the global keys.
- Add a short "Scenes" section listing the 8 entries with descriptions
  matching the menu.

Self-check:
  [ ] Builds clean, previous Prompt 1 checks still pass
  [ ] Menu appears on launch, shows 8 entries
  [ ] Up/Down highlights cycle correctly
  [ ] Enter on each of entries 1–8 shows its "coming soon" scene
  [ ] Esc from any scene returns to the menu
  [ ] Esc on the menu exits the app cleanly
  [ ] No personal paths in repo (grep check)
  [ ] Branch merged, tag prompt-2-done pushed, CHANGELOG updated
```

---

## Prompt 3 — Fractal Explorer (2D: Mandelbrot / Julia / Burning Ship)

```
[Universal rules + Dependency policy]

Implement the first flagship scene: "Fractal Explorer". This is the
first thing someone screenshots for the README, so quality matters.

Technique:
Fullscreen 2D escape-time fractal in a fragment shader on a cached
fullscreen quad. Three fractal types, switchable at runtime:
  - Mandelbrot
  - Julia (animated c parameter when idle)
  - Burning Ship

Shader requirements:
- Continuous escape-time coloring (log-log smoothing):
     mu = iter + 1 - log(log(|z|)) / log(2)
  NOT raw integer iteration count. Image must be band-free.
- Iteration cap scales with zoom depth (start 256, cap 2048).
- Double precision for the complex coordinate (emulated via two
  floats if needed — plain `double` uniforms are fine on RTX 3070).
- Palette lookup from a 1D RGBA8 texture (256 entries). Ship four
  palettes as PNG strips under assets/palettes/:
     twilight    deep indigo → violet → warm gold
     ember       black → oxblood → amber → cream
     oceanic     midnight → teal → cyan → pale foam
     monochrome  black → graphite → bone, with one hot accent dot
- Inner-set shading: not flat black. Use a slow dark gradient based
  on the last |z| inside the set.
- Optional orbit-trap mode (trap to a circle OR a line), toggled
  with key T.

Controls (scene-local):
  Arrow keys / WASD    pan
  Mouse drag (LMB)     pan
  Q / E, mouse wheel   zoom out / in
  [ ]                  cycle fractal type
  PgUp / PgDn          cycle palette
  T                    toggle orbit-trap mode
  Space                toggle idle autopilot
  H                    toggle HUD
  R                    reset camera
  Esc                  back to menu

Idle autopilot:
- After 5 seconds of no input, begin a slow scripted zoom toward
  the Mandelbrot coordinate (-0.743643887037151, 0.131825904205330)
  to depth ~1e-12. Palette cycles slowly. Any input cancels.

HUD (bottom-left, toggleable):
  fractal: Mandelbrot
  zoom:    1e-6
  iter:    768
  palette: twilight

Output:
- Scene renders into the shared offscreen HDR target (same interface
  the post-process in Prompt 6 will consume). Output is linear color,
  NOT pre-tonemapped.
- Write bright areas with values up to ~2.5 so Prompt 6's bloom has
  something to grab onto.

Reference material (allowed, credit in shader comment):
- Inigo Quilez on smooth iteration:
  https://iquilezles.org/articles/msetsmooth/   (adapt the idea and
  write your own implementation — do not paste verbatim).
- Stefan Gustavson palette interpolation if you choose to blend
  palettes analytically.

Deliverables:
- src/scene/scene_fractal2d.f90 (+ submodule if > 200 lines)
- assets/shaders/fractal2d.vert, fractal2d.frag
- assets/palettes/{twilight,ember,oceanic,monochrome}.png
- tools/gen_palettes.py if palettes are script-generated (optional)
- Menu entry wired to this scene (replacing the stub)
- docs/FRACTALS_2D.md: short note on the math + smooth coloring,
  with the formula typeset in plain text.

Anti-scope:
- No deep-zoom perturbation theory (that is a rabbit hole — save it).
- No bloom, tone mapping, or screen-space effects (Prompt 6).
- No animated parameter keyframes yet (Prompt 7).

Self-check:
  [ ] Build clean, Prompts 1–2 still work
  [ ] Menu → Fractal Explorer launches the real shader
  [ ] All three fractal types render without banding
  [ ] Zoom to 1e-10 stays stable (no pixelation at edges)
  [ ] All four palettes load and cycle
  [ ] Autopilot engages after 5s idle, cancels on keypress
  [ ] HUD values update live
  [ ] Esc returns to menu; menu still launches other stub scenes
  [ ] Screenshot of each fractal type saved manually to
      docs/gallery/fractal2d_{mandelbrot,julia,burning_ship}.png
  [ ] Tag prompt-3-done, CHANGELOG updated, pushed
```

---

## Prompt 4 — Mandelbulb Cathedral (3D raymarched fractal)

```
[Universal rules + Dependency policy]

Implement "Mandelbulb Cathedral" — the 3D raymarched centerpiece.
This is the hardest prompt in the project. Build it in stages and
commit between stages so any failure is recoverable.

STAGING POLICY (important):
Do the stages in this order. Commit after each. If a stage fails
to render correctly, STOP, revert to the previous stage, and ask
for help — do NOT continue piling on features.

  Stage A  basic raymarch: Mandelbulb DE, fixed camera, flat color
           from iteration count. Black background. Commit.
  Stage B  tetrahedral-gradient normals + single directional light
           (Lambert + tiny ambient). Commit.
  Stage C  soft shadows via secondary march toward the key light
           (Inigo Quilez standard formula, k ~ 16). Commit.
  Stage D  ambient occlusion (5 DE samples along normal, geometric
           falloff). Commit.
  Stage E  exponential distance fog with slight warm tint. Commit.
  Stage F  orbit-trap coloring during DE iteration (track min dist
           to x/y/z planes and origin; mix into albedo). Commit.
  Stage G  emissive creases on high-iteration terminations. Commit.
  Stage H  Menger sponge DE as a second, key-switchable fractal.
           Commit. Merge branch. Tag prompt-4-done.

Technical requirements:
- Distance epsilon scales with screen-space ray footprint:
    eps = pixelRadius * t       (clamped to a sane floor)
- Tetrahedral normal sampling (4 taps, not 6).
- Soft shadow formula: standard penumbra estimator from IQ's
  "rmshadows" article. Credit in shader comment.
- AO: 5 samples along the normal at logarithmic distances; accumulate
  with a decay weight; normalize.
- Fog: 1 - exp(-density * t * fog_color), color slightly warmer than
  the key light so separation reads clearly against the cool sky.
- Orbit traps stored per-ray in shader, NOT via SSBO feedback.

Camera:
- Auto-orbit: slow radial orbit + gentle vertical sine drift + slow roll
- LMB drag: manual orbit override; 5 seconds idle returns to auto.
- Wheel: orbit radius within sane bounds.
- Keys 1/2/3: quality presets
    draft   max_steps=64,  shadow=24, AO=3
    normal  max_steps=128, shadow=48, AO=5
    heavy   max_steps=256, shadow=96, AO=8
- R: reset camera.
- F: toggle fractal type (Mandelbulb / Menger).

Performance target (RTX 3070, 1920x1080, "normal" preset): ≥ 60 fps.

Output:
- Render into the shared HDR target, emissive values > 1.0, linear
  color (no tonemapping in this shader).

Aesthetic:
- Dark scene, warm key light from upper-right, cool indigo sky
  gradient. No rainbow saturation. "Ancient bronze in a cathedral
  at dusk" is the mood.

Reference material (allowed, credit in shader):
- IQ distance estimators: https://iquilezles.org/articles/distfunctions/
- IQ soft shadows: https://iquilezles.org/articles/rmshadows/
- Mandelbulb math: Daniel White / Paul Nylander derivation (public)

Deliverables:
- src/scene/scene_mandelbulb.f90 (+ submodules if > 200 lines)
- assets/shaders/raymarch.vert, raymarch.frag (well-commented)
- docs/FRACTALS_3D.md: explains ray gen → march → shade → fog in
  plain English, with the DE and shadow formulas.
- Gallery captures at each stage saved as
  docs/gallery/mandelbulb_stage_{A..H}.png

Anti-scope:
- No reflections or refractions.
- No volumetric lighting (god rays) — save it.
- No path tracing — this is a DE + direct lighting scene.
- Don't try to do all eight stages in one shader rewrite. Commit between.

Self-check:
  [ ] Build clean, Prompts 1–3 still work
  [ ] All 8 stage commits present in prompt-4 branch history
  [ ] "normal" preset runs ≥ 60 fps at 1080p on RTX 3070
  [ ] Mandelbulb and Menger both toggle cleanly with F
  [ ] No z-fighting / shadow acne / popping during auto-orbit
  [ ] Esc returns to menu; all prior scenes still work
  [ ] Personal-paths grep clean
  [ ] Tag prompt-4-done, CHANGELOG updated, pushed
```

---

## Prompt 5 — Particle Galaxy (GPU compute-shader particle field)

```
[Universal rules + Dependency policy]

Implement "Particle Galaxy" — a GPU-resident particle simulation
that contrasts with the shader fractals and demonstrates compute.

Implementation:
- Particle struct (std430 SSBO layout):
    struct Particle {
        vec4 position_age;    // xyz = pos, w = age seconds
        vec4 velocity_mass;   // xyz = vel, w = mass
        vec4 color;           // rgba, a used as sprite alpha
    };
- Default count: 500,000 (RTX 3070 handles this easily).
  Configurable via preset up to 2,000,000.

Compute pass (GL 4.3+ compute shader, workgroup size 256):
- Soft central attractor: Newtonian with softening length ε ≈ 0.1
- Small tangential component so particles form a disk, not a ball
- Curl-noise perturbation on velocity (3D simplex noise, Ashima —
  vendor the shader snippet under third_party/ashima_noise/ with
  its MIT license).
- Age-based respawn: when age > lifetime, respawn on a fresh outer
  ring with randomized initial vel.

Render pass:
- Draw the SSBO as GL_POINTS using point sprites.
- Fragment shader: soft gaussian falloff (not hard circles).
- Additive blending.
- Size scaled by 1/z, clamped to [1.0, 24.0] pixels.
- Color from palette lookup indexed by age.

Presets (keys 1/2/3):
  galaxy   disk with spiral arms, warm core cyan→white→rose
  vortex   tighter rotation, higher angular velocity, amber palette
  nebula   looser bounds, slower, cool teal/violet palette

Controls:
  Space         pause / resume simulation
  R             reseed from initial distribution
  1 / 2 / 3     change preset
  Mouse drag    orbit camera
  Wheel         dolly in/out
  H             HUD toggle

HUD: particle count, sim step ms, render ms, preset name, paused flag.

Output:
- Render into the shared HDR target with bright (4–6) particle cores
  so bloom in Prompt 6 makes them glow naturally.

Deliverables:
- src/scene/scene_particles.f90 (+ submodule for SSBO setup if long)
- assets/shaders/particles_step.comp
- assets/shaders/particles_draw.vert, particles_draw.frag
- third_party/ashima_noise/ with LICENSE and THIRD_PARTY.md entry
- docs/PARTICLES.md: workgroup math, why SSBO + compute, why
  additive blending works without depth sorting here
- docs/gallery/particles_{galaxy,vortex,nebula}.png

Anti-scope:
- No CPU fallback (Prompt 1 self-check already confirmed GL 4.6).
- No collisions, no true N-body (softened central only).
- No transform feedback variant.

Self-check:
  [ ] Build clean, Prompts 1–4 still work
  [ ] 500k particles render ≥ 120 fps at 1080p on RTX 3070
  [ ] 2M particles render ≥ 60 fps at 1080p on RTX 3070
  [ ] All three presets produce visually distinct scenes
  [ ] Pause freezes the sim; render continues; resume is seamless
  [ ] No GL errors logged
  [ ] Menu round-trip works for all 5 real scenes
  [ ] Tag prompt-5-done, CHANGELOG updated, pushed
```

---

## Prompt 6 — HDR, bloom, tone mapping, filmic grade

```
[Universal rules + Dependency policy]

Build the shared post-processing pipeline and retrofit it into every
existing scene. This is the prompt that turns demos into images you
would hang on a wall.

Pipeline, in pass order:
  1. Scene renders into HDR color:  GL_RGBA16F (not R11F_G11F_B10F).
  2. Bright pass: soft-knee threshold ≈ 1.0 → half-res RGBA16F.
  3. Bloom: 5-level dual-filter downsample/upsample chain
     (Marius Bjørge "Call of Duty" style — cheaper and better than
     separable gaussian). Upsamples accumulate into level 0.
  4. Composite: additive blend with configurable bloom_strength.
  5. Tone map: ACES filmic (Narkowicz 2015 fit) OR Reinhard-Jodie,
     selectable via enum uniform.
  6. Gamma / sRGB: pick ONE approach — either shader pow(1/2.2) OR
     an sRGB-format default framebuffer. Not both.
  7. Optional per-scene passes (booleans in post_settings):
        vignette       smooth radial darkening, default 0.3
        grain          animated blue noise, default 0.02
        chromatic_ab   ≤ 1 pixel offset at frame edges

Integration:
- Introduce `post_process` type that owns all FBOs and shaders.
- Scenes no longer manage their own framebuffers; they call
    call post%begin_scene_target()
    ... scene renders ...
    call post%end_and_present()
- Each scene exposes a `post_settings` struct:
    type :: post_settings_t
        real(real32) :: bloom_strength     = 0.9
        real(real32) :: bloom_threshold    = 1.0
        integer      :: tone_map_mode      = TONE_ACES
        real(real32) :: vignette_strength  = 0.3
        real(real32) :: grain_strength     = 0.02
        logical      :: chromatic_ab       = .false.
    end type
- Per-scene tuning:
    menu             bloom 0.3, vignette 0.2, grain 0.01
    fractal2d        bloom 0.8, ACES, vignette 0.3
    mandelbulb       bloom 1.1 (emissive creases shine), vignette 0.4
    particles        bloom 1.6, ACES, chromatic_ab on, grain 0.03
    combined scene   per-act (Prompt 7 will override at runtime)

Window resize:
- All FBOs reallocate on framebuffer_size_callback. Test by dragging
  the corner — no stretch, no black bars, no crash.

Deliverables:
- src/render/post_process.f90 (+ submodule for shader loading)
- assets/shaders/post/bright_pass.frag
- assets/shaders/post/downsample.frag
- assets/shaders/post/upsample.frag
- assets/shaders/post/composite_tonemap.frag   (composite + tonemap +
  gamma + vignette + grain in one final pass — one texture sample per
  effect beats one pass per effect at this scale)
- docs/POSTPROCESS.md with ASCII-art pass-order diagram

Anti-scope:
- No TAA, DOF, motion blur, SSAO, god rays. Not this project.
- No runtime shader reload — save it.
- Do NOT turn scenes into blurry glowing messes. If a scene looks
  worse with bloom on, lower bloom_strength. Do NOT "fix" it by
  brightening the scene.

Bloom debugging tips (include in POSTPROCESS.md):
  Everything glows    → bloom_strength too high OR threshold too low
  Washed out          → tone map applied before composite, or exposure off
  Gray / low contrast → double gamma correction (check pipeline)
  Haloing             → upsample filter too wide OR too many levels
  Dim bright areas    → scene not outputting HDR > 1.0 values

Self-check:
  [ ] Build clean, all previous scenes still work
  [ ] Each scene's bloom strength and grade is visibly appropriate
  [ ] Bright particle cores / emissive creases clearly bloom
  [ ] Window resize does not corrupt FBOs
  [ ] Toggling tone_map_mode live produces different but correct images
  [ ] No double-gamma (checkerboard test pattern looks right)
  [ ] No GL errors, no validation warnings
  [ ] Updated per-scene gallery screenshots in docs/gallery/
  [ ] Tag prompt-6-done, CHANGELOG updated, pushed
```

---

## Prompt 7 — Animation system + "Combined Showcase" flagship scene

```
[Universal rules + Dependency policy]

Build the animation system first as an independent module with a
trivial test. Only after it passes its own self-check, build the
flagship "Combined Showcase" scene on top of it.

═══════════ PART A — Animation system (do this FIRST) ═══════════

Module: src/anim/
  src/anim/keyframe_track.f90   generic real64 track of (t, v) pairs
                                interpolation: linear, cubic (Catmull-Rom),
                                smoothstep. Selectable per track.
  src/anim/timeline.f90         owns multiple named tracks; evaluate all
                                at a given absolute time t.
  src/anim/camera_spline.f90    wraps 3× position tracks + 3× look-at
                                tracks → view matrix at time t.
  src/anim/tiny_parser.f90      a small hand-written parser for a
                                plain-text timeline format. Do NOT
                                pull in a YAML library.

Timeline file format (write your own — it's ~80 lines of parser):

    # assets/timelines/demo.tl
    duration 10.0

    track  bloom_strength  linear
        0.0   0.3
        5.0   1.4
       10.0   0.6

    track  camera_pos_x    cubic
        0.0  -4.0
        5.0   0.0
       10.0   4.0

    # (other tracks...)

Testing the animation system BEFORE building the flagship:
- Add a temporary scene "anim_test" (not in the menu, accessible via
  CLI flag `--scene anim_test`) that:
    * loads assets/timelines/demo.tl
    * maps camera_pos_x/y/z to the current scene's camera
    * prints all track values each second to the log
- Run it manually; verify the interpolation modes look correct by
  watching the log output.
- Remove anim_test (or keep it as a dev-only scene behind a define)
  before moving to Part B. Commit Part A separately with tag
  `prompt-7a-done`.

═══════════ PART B — Combined Showcase (AFTER Part A passes) ════

A single 60-second scene driven by assets/timelines/combined.tl.
Deterministic: given time t, the image is fixed regardless of FPS.

Act I   (0–20s)   "Birth"
  - Mandelbrot deep zoom (reuse fractal2d shader)
  - Twilight palette
  - Camera path from wide view to ~1e-6 around the bulb
  - Bloom fades 0.0 → 0.9
  - Black-in fade 0.0–1.5s

Act II  (20–40s)  "Ascent"
  - Crossfade (2s) to Mandelbulb (reuse raymarch shader)
  - Slow orbit, push-in over the act
  - Fog density fades up
  - Palette shifts warm (ember)
  - Bloom rises 0.9 → 1.2 on emissive creases

Act III (40–60s)  "Lightwell"
  - Crossfade to Particle Galaxy
  - Camera pulls back as particles organize into a bright spiral
  - Bloom peaks at 1.8
  - Final 3s fade to black

Technical requirements:
- Scene evaluates ONLY from absolute wall-clock t (pauseable), never
  from dt accumulation. This guarantees frame-for-frame identical
  output in Prompt 8's offline renderer.
- Crossfades implemented by rendering both sub-scenes to separate
  HDR targets and blending in the composite step, weighted by a
  smoothstep over the crossfade window.
- A mini scrub-bar along the bottom: thin line + playhead. Left/Right
  arrows jump ±1s. Space pauses. R restarts. "." steps one frame
  at the target FPS for debugging.

Anti-scope:
- No audio yet (Prompt 9 territory).
- No GUI timeline editor — text file is enough.
- No auto-scene-composer — the three acts are hard-coded in this scene.

Deliverables:
- src/anim/ with all four modules, ≤ 200 lines each
- assets/timelines/combined.tl (well-commented)
- src/scene/scene_combined.f90
- docs/ANIMATION.md: timeline format spec + one worked example
- docs/gallery/combined_act{1,2,3}.png captured at mid-act

Self-check (Part A):
  [ ] Linear / cubic / smoothstep interpolation produce visibly
      correct curves (log output inspected)
  [ ] tiny_parser handles: comments, blank lines, duplicate keys
      (last wins), malformed lines (error with line number)
  [ ] tag prompt-7a-done pushed

Self-check (Part B):
  [ ] Build clean, all previous scenes still work
  [ ] Combined scene runs 60s end-to-end without glitches
  [ ] Seeking with Left/Right produces the expected frame
  [ ] Two runs at different FPS produce visually identical frames
      at the same timeline-t (manual A/B check)
  [ ] Crossfades are smooth, no flash or black gap
  [ ] Esc returns to menu; menu still works
  [ ] tag prompt-7-done pushed
```

---

## Prompt 8 — Offline frame export + README gallery + Technical Paper

```
[Universal rules + Dependency policy]

Finalize the project: add deterministic offline rendering, capture
the real gallery, write the technical paper, and polish the repo to
a state where a stranger landing on GitHub understands it in 60s.

═══════════ PART A — Offline frame export ═══════════

CLI:
    fortran_gl_showcase --render <scene> \
                        --seconds <N> --fps <F> \
                        --width <W>  --height <H> \
                        --out <dir>

Behavior:
- Open a HIDDEN GLFW window (glfwWindowHint(GLFW_VISIBLE, GL_FALSE))
  with a GL 4.6 context; allocate offscreen FBOs at (W, H).
- Advance the scene in fixed dt = 1/fps steps. Never use real wall
  clock for timeline evaluation during --render.
- After every full post-process pass, glReadPixels the final LDR
  buffer into a uint8 RGBA buffer and save as
    <out>/frame_000000.png, frame_000001.png, ...
  via stb_image_write (vendored). Flip Y as needed.
- Print progress every 30 frames:
    "frame 300/3600 (8.3%)  42 ms/frame"

Scenes must opt in by setting `is_offline_capable = .true.` in their
metadata. At minimum: fractal2d (in autopilot mode), mandelbulb,
particles, combined. The menu and any interactive-only scenes stay
off-by-default.

Shell helpers:
    scripts/encode.sh       PNG dir → H.264 MP4 (libx264, crf 16, slow)
    scripts/encode_gif.sh   PNG dir → palette-optimized looping GIF
    scripts/render_gallery.sh
        Renders short clips of every offline-capable scene at low
        resolution for CI smoke testing.

═══════════ PART B — README with visuals ═══════════

Rewrite README.md top to bottom:

  # Fortran GL Showcase
  > Cinematic fractals and shader art, written in modern Fortran.

  [ build status badge ] [ MIT badge ] [ GL 4.6 badge ]

  ## Gallery
  A 2×4 image grid (markdown table) of docs/gallery/*.png —
  one image per scene. Click-through to full-size.

  ## Why Fortran?
  Three short paragraphs:
    1. Numeric stability (real64 first-class, no silent promotions)
    2. Modern Fortran is nothing like Fortran 77 — submodules, OO,
       clean C interop, excellent optimizer
    3. Novelty — most graphics demos are C++/Rust; this is different

  ## Quick start (WSL2 Ubuntu)
    apt install line ...
    git clone ...
    cmake -S . -B build -G Ninja
    cmake --build build
    ./build/fortran_gl_showcase

  ## Controls
  Table: global keys + per-scene keys.

  ## Rendering your own videos
  Exact command sequence from --render to mp4.

  ## Scenes
  One subsection per scene with: small gallery image + 2-sentence
  description + key bindings.

  ## Architecture
  One-paragraph summary + link to ARCHITECTURE.md and TECHNICAL_PAPER.md.

  ## Contributing
  Four-step "add a new scene" checklist.

  ## License
  MIT. Third-party licenses under third_party/ and THIRD_PARTY.md.

Capture the gallery:
- Run --render at 1920×1080 for each scene, pick the best frame(s)
  manually, save under docs/gallery/ with lowercase snake_case names.
- Commit the PNGs — gallery images are part of the repo, not LFS.
- Keep each image under ~500 KB (pngquant or oxipng).

═══════════ PART C — Technical Paper ═══════════

Create TECHNICAL_PAPER.md at repo root. This is a real technical
write-up (≈ 3000–5000 words) explaining how the project was built,
aimed at a developer with graphics background but no Fortran.

Required sections:

  1. Abstract (≤ 200 words)
  2. Introduction & Motivation
       Why Fortran for graphics in 2026; numeric stability; novelty.
  3. System Architecture
       Module diagram (ASCII or Mermaid). Scene lifecycle. Data flow.
  4. Rendering Foundations
       GL 4.6 context on WSL2 + NVIDIA; ISO_C_BINDING approach;
       shader loader; fullscreen quad; HDR target choice.
  5. 2D Escape-Time Fractals
       Mandelbrot / Julia / Burning Ship iteration. Smooth (log-log)
       coloring derivation. Palette lookup via 1D texture. Orbit traps.
  6. Distance-Estimated 3D Fractals
       Mandelbulb DE derivation; Menger folding DE; tetrahedral
       gradient normals; soft shadow penumbra estimator; AO by
       distance-field sampling; exponential fog.
  7. GPU Particle Simulation
       std430 SSBO layout; compute shader workgroup sizing; integrator;
       curl-noise perturbation; additive point-sprite rendering.
  8. HDR + Bloom + Tone Mapping
       Why RGBA16F; dual-filter bloom pros/cons; ACES fit vs Reinhard;
       sRGB pipeline correctness.
  9. Animation System
       Keyframe tracks; Catmull-Rom interpolation math; plain-text
       timeline format; why deterministic t matters for offline render.
 10. Offline Rendering Pipeline
       Hidden GLFW window on WSL2; fixed dt stepping; PNG output via
       stb_image_write; ffmpeg encoding choices (crf, pix_fmt).
 11. Performance Observations
       Frame times per scene at 1920×1080 on RTX 3070; where time
       goes; what would be optimized next.
 12. Lessons Learned
       What Fortran 2018/2023 made easy; what it made awkward
       (mostly C interop verbosity); WSL2 surprises; bloom pitfalls.
 13. Future Work
       Audio reactivity, more fractals, path-traced hero frames,
       live parameter GUI.
 14. References
       Linked list:
         - Inigo Quilez (iquilezles.org): distance fns, shadows, AO
         - Mikael H. Christensen: Fragmentarium, Mandelbulb DE
         - Krzysztof Narkowicz: ACES filmic curve
         - Ashima / Stefan Gustavson: simplex noise
         - Marius Bjørge: dual-filter bloom
         - Daniel White / Paul Nylander: Mandelbulb derivation

Tone: technical but readable. Include formulas in plain text
(Unicode OK). Include short code snippets for the non-obvious
algorithms (smooth coloring, soft shadows, Catmull-Rom). Credit
every reference.

═══════════ PART D — Repo hygiene ═══════════

- .github/workflows/ci.yml:
    Ubuntu-latest runner; apt install deps; cmake Release build;
    run scripts/render_gallery.sh at 320×180 for 1 second per scene;
    assert ≥ 1 PNG produced per scene. Do NOT run the interactive
    GUI in CI.
- .editorconfig: Fortran = 4 spaces, LF, final newline.
- CONTRIBUTING.md: the 4-step "add a scene" checklist.
- CODE_OF_CONDUCT.md: Contributor Covenant 2.1.
- SECURITY.md: stub with "report issues via GitHub security advisories".
- Enable GitHub Pages from docs/ if you want a landing page
  (optional — note in README).

Final final-check Codex runs before calling done:

    $ cmake --build build   # zero warnings
    $ ./build/fortran_gl_showcase
        # menu appears, all 8 scenes launch, Esc returns, F11 works
    $ ./build/fortran_gl_showcase --render combined \
        --seconds 5 --fps 30 --width 640 --height 360 --out /tmp/smoke
        # 150 PNGs produced, all same size, none empty
    $ scripts/encode.sh /tmp/smoke /tmp/smoke.mp4 30
        # plays in any video player
    $ grep -rn -E "(/home/[a-z]|/mnt/c/Users/|@gmail|@outlook)" \
           . --exclude-dir=build --exclude-dir=.git
        # returns nothing
    $ git log --oneline | head -20
        # clear, prompt-N-prefixed commit history
    $ cat THIRD_PARTY.md
        # every vendored dep listed with license

Self-check:
  [ ] All of the above pass
  [ ] docs/gallery/ has one captured image per scene (not placeholders)
  [ ] README renders correctly on github.com (preview before pushing)
  [ ] TECHNICAL_PAPER.md is complete and internally linked from README
  [ ] CI workflow green on a test push to a branch
  [ ] Tag v0.1.0 on main; GitHub release created with short notes
  [ ] Tag prompt-8-done; final push
```

---

## After Prompt 8 (optional future prompts)

These are NOT in the initial 8. Save for when the foundation is solid.

- **Prompt 9** — Audio-reactive mode (FFT drives bloom, camera speed,
  palette shift)
- **Prompt 10** — Scene preset system (save/load parameter state to
  TOML-ish files)
- **Prompt 11** — More fractals (Burning Ship deep-zoom, Phoenix,
  Kaleidoscopic IFS, Newton)
- **Prompt 12** — One-bounce path tracer over the Mandelbulb for a
  hero still image (offline only, minutes/frame)
- **Prompt 13** — Live parameter GUI via minimal ImGui Fortran binding
- **Prompt 14** — Real-time shader reload for fast iteration

---

## Working with Codex on this project — hard-won tips

1. **Keep every prompt's scope tight.** If Codex starts "also adding X
   while I'm here," tell it to revert. Staged builds break when stages
   bleed into each other.

2. **Run it yourself after every prompt.** Codex compiles; only you
   verify it looks right. Screenshot after every scene.

3. **Describe what you see, not what you think is wrong.** "The
   Mandelbulb has banding on the shadow terminator at normal-up angles"
   is useful. "Shadows look weird" is not.

4. **Commit after every successful prompt** with tag `prompt-N-done`.
   If Prompt 5 breaks the world, `git reset --hard prompt-4-done`.

5. **When in doubt, simplify.** If a stage of Prompt 4 fails, strip it
   back to Stage A and build up again. Speed of iteration beats feature
   completeness.

6. **Read the shader code Codex writes.** Shaders are where bugs hide
   and where style points live. A human-readable shader with clear
   comments is worth more than a clever one-liner.

7. **Let screenshots drive the art.** After Prompt 3, you should already
   have framable images. If you don't, your palettes or your tonemap are
   off — don't continue until the image looks good.

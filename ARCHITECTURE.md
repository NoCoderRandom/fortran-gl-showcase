# Architecture

The project is split by responsibility so the rendering path stays easy to evolve.

- `src/core/`: shared utilities such as numeric kinds, logging, and frame timing.
- `src/platform/`: GLFW-backed window management and per-frame input polling.
- `src/gl/`: low-level OpenGL bindings and optional debug wiring.
- `src/render/`: reusable rendering helpers such as shader programs and fullscreen geometry.
- `src/scene/`: the abstract scene interface, built-in scene registration, and scene implementations.
- `src/app/`: application ownership and the main loop.
- `src/main.f90`: tiny entry point that starts the application.

For Prompt 1 the app only boots an `empty_scene`, clears the framebuffer, logs frame stats once per second, and handles `Esc`/`F11`.


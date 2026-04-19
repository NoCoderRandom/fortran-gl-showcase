# Contributing

## Add A New Scene

1. Add the scene module under `src/scene/` and keep it self-contained.
2. Register it in `src/scene/scene_registry.f90` with menu metadata and a factory.
3. Document its controls and output in `README.md`, `CHANGELOG.md`, and the relevant `docs/*.md` file.
4. Build both configs and, if the scene supports offline export, verify `--render` produces PNG frames before opening a PR.

## Development Notes

- Prefer modern free-form Fortran 2018 style.
- Keep OpenGL interop explicit through `iso_c_binding`.
- Avoid introducing new heavy dependencies when a small local module is enough.

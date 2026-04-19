# Fractal Explorer Notes

`Fractal Explorer` is a fullscreen escape-time shader scene with three formulas:

- Mandelbrot
- Julia
- Burning Ship

The shader uses smooth escape-time coloring instead of raw integer bands:

`mu = iter + 1 - log(log(|z|)) / log(2)`

That continuous value is used to index a palette strip, which keeps gradients
smooth while still preserving structure near the boundary.

For deeper zooms, the scene increases its iteration cap from `256` up to
`2048`. The view transform is sent as hi/lo float pairs so the shader keeps
usable precision well past the default single-precision comfort zone.

Inside-set pixels are not rendered as flat black. They use a slow dark gradient
modulated by time and the final orbit magnitude, which keeps the image readable
even before the later HDR/bloom prompt is added.

#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "palettes"
MODULE_PATH = ROOT / "src" / "render" / "palette_data.f90"
WIDTH = 256


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def sample_stops(stops: list[tuple[float, tuple[int, int, int, int]]], x: float) -> tuple[int, int, int, int]:
    if x <= stops[0][0]:
        return stops[0][1]
    if x >= stops[-1][0]:
      return stops[-1][1]
    for left, right in zip(stops, stops[1:]):
        if left[0] <= x <= right[0]:
            span = max(1e-6, right[0] - left[0])
            t = (x - left[0]) / span
            return tuple(int(round(lerp(left[1][i], right[1][i], t))) for i in range(4))
    return stops[-1][1]


def build_palette(name: str) -> list[tuple[int, int, int, int]]:
    if name == "twilight":
        stops = [
            (0.0, (10, 14, 30, 255)),
            (0.3, (42, 24, 78, 255)),
            (0.64, (120, 60, 142, 255)),
            (1.0, (246, 197, 102, 255)),
        ]
    elif name == "ember":
        stops = [
            (0.0, (3, 2, 3, 255)),
            (0.28, (45, 8, 14, 255)),
            (0.6, (133, 43, 20, 255)),
            (1.0, (250, 233, 198, 255)),
        ]
    elif name == "oceanic":
        stops = [
            (0.0, (6, 15, 25, 255)),
            (0.35, (12, 70, 90, 255)),
            (0.72, (62, 190, 205, 255)),
            (1.0, (223, 248, 240, 255)),
        ]
    elif name == "monochrome":
        stops = [
            (0.0, (0, 0, 0, 255)),
            (0.65, (68, 70, 72, 255)),
            (0.92, (212, 205, 190, 255)),
            (1.0, (248, 243, 229, 255)),
        ]
    else:
        raise ValueError(name)

    colors = [sample_stops(stops, index / (WIDTH - 1)) for index in range(WIDTH)]
    if name == "monochrome":
        for index in range(WIDTH):
            accent = max(0.0, 1.0 - abs(index - 196) / 8.0)
            if accent > 0.0:
                r, g, b, a = colors[index]
                colors[index] = (
                    min(255, int(round(lerp(r, 255, accent)))),
                    min(255, int(round(lerp(g, 115, accent)))),
                    min(255, int(round(lerp(b, 60, accent)))),
                    a,
                )
    return colors


def write_chunk(handle, tag: bytes, payload: bytes) -> None:
    handle.write(struct.pack(">I", len(payload)))
    handle.write(tag)
    handle.write(payload)
    handle.write(struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))


def write_png(path: pathlib.Path, colors: list[tuple[int, int, int, int]]) -> None:
    raw = bytearray()
    raw.append(0)
    for r, g, b, a in colors:
        raw.extend((r, g, b, a))

    with path.open("wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        write_chunk(handle, b"IHDR", struct.pack(">IIBBBBB", WIDTH, 1, 8, 6, 0, 0, 0))
        write_chunk(handle, b"IDAT", zlib.compress(bytes(raw), level=9))
        write_chunk(handle, b"IEND", b"")


def write_module(path: pathlib.Path, palettes: dict[str, list[tuple[int, int, int, int]]]) -> None:
    lines: list[str] = [
        "module render_palette_data",
        "  use, intrinsic :: iso_c_binding, only: c_float",
        "  implicit none (type, external)",
        "  private",
        "",
        "  integer, parameter, public :: palette_count = 4",
        f"  integer, parameter, public :: palette_width = {WIDTH}",
        "  character(len=16), parameter, public :: palette_names(palette_count) = [character(len=16) :: &",
        '    "twilight", "ember", "oceanic", "monochrome"]',
        "  real(c_float), parameter, public :: palette_rgba(4, palette_width, palette_count) = reshape([ &",
    ]

    flat: list[str] = []
    order = ["twilight", "ember", "oceanic", "monochrome"]
    for name in order:
        for r, g, b, a in palettes[name]:
            flat.extend(
                [
                    f"{r / 255.0:.8f}_c_float",
                    f"{g / 255.0:.8f}_c_float",
                    f"{b / 255.0:.8f}_c_float",
                    f"{a / 255.0:.8f}_c_float",
                ]
            )

    for index in range(0, len(flat), 4):
        chunk = ", ".join(flat[index:index + 4])
        suffix = ", &" if index + 4 < len(flat) else "], [4, palette_width, palette_count])"
        lines.append(f"    {chunk}{suffix}")

    lines.extend(
        [
            "end module render_palette_data",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    palettes = {name: build_palette(name) for name in ["twilight", "ember", "oceanic", "monochrome"]}
    for name, colors in palettes.items():
        write_png(ASSET_DIR / f"{name}.png", colors)
    write_module(MODULE_PATH, palettes)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Mask a full-bleed square icon PNG to the macOS squircle (superellipse).

Usage: squircle_mask.py <src.png> <out.png>
Resizes src to 1024x1024, applies a superellipse alpha mask (n=5, the macOS
"continuous corner" look), and writes an RGBA PNG.
"""
import sys
from PIL import Image

SIZE = 1024
N = 5.0          # superellipse exponent — ~5 matches macOS's squircle
INSET = 0.0      # 0 = full-bleed; raise slightly to pad from the edge


def main() -> None:
    src, out = sys.argv[1], sys.argv[2]
    img = Image.open(src).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)

    mask = Image.new("L", (SIZE, SIZE), 0)
    px = mask.load()
    a = (SIZE / 2.0) * (1.0 - INSET)
    c = SIZE / 2.0
    # Supersample the boundary a touch by testing at pixel centers.
    for y in range(SIZE):
        ny = abs((y + 0.5 - c) / a)
        ny_n = ny ** N
        if ny_n > 1.0:
            continue
        for x in range(SIZE):
            nx = abs((x + 0.5 - c) / a)
            if nx ** N + ny_n <= 1.0:
                px[x, y] = 255

    img.putalpha(mask)
    img.save(out)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()

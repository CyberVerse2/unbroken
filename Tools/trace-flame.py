#!/usr/bin/env python3
"""Trace the app-icon flame into a normalized point array for the menu-bar glyph.

The menu-bar icon must be a monochrome template (it tints to the bar and inverts
on click), so it can't use the colour logo directly. Instead we trace the *exact
silhouette* of the app-icon flame and bake it into MenuBarIcon.flameSilhouette,
so the tiny glyph is unmistakably the same flame as the logo.

Segments the flame from its warm background by red-minus-blue (the flame's orange
is far redder than the pale peach ground), fills the bright core, keeps the
largest component, Moore-neighbour traces the boundary, and Douglas-Peucker
simplifies it. Prints a Swift array (x, y in 0..1, y-up for AppKit) and writes a
preview PNG next to the source.

Usage:  python3 Tools/trace-flame.py
Requires: pillow, numpy
"""
import numpy as np
from collections import deque
from PIL import Image, ImageDraw

SRC = "Support/Brand/AppIcon-flame-imagegen.png"
PREVIEW = "dist/flame-trace-preview.png"

img = Image.open(SRC).convert("RGB").resize((256, 256), Image.BILINEAR)
a = np.asarray(img).astype(np.int32)
mask = (a[..., 0] - a[..., 2]) > 172          # flame orange vs pale-peach ground
H, W = mask.shape

# Fill interior holes (the bright yellow core): BFS the outside, holes are the rest.
outside = np.zeros_like(mask)
dq = deque()
for x in range(W):
    for y in (0, H - 1):
        if not mask[y, x] and not outside[y, x]:
            outside[y, x] = True; dq.append((y, x))
for y in range(H):
    for x in (0, W - 1):
        if not mask[y, x] and not outside[y, x]:
            outside[y, x] = True; dq.append((y, x))
while dq:
    y, x = dq.popleft()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ny, nx = y + dy, x + dx
        if 0 <= ny < H and 0 <= nx < W and not mask[ny, nx] and not outside[ny, nx]:
            outside[ny, nx] = True; dq.append((ny, nx))
filled = mask | (~outside & ~mask)

# Largest connected component.
lbl = np.zeros((H, W), np.int32); cur = best = bestid = 0
for sy in range(H):
    for sx in range(W):
        if filled[sy, sx] and lbl[sy, sx] == 0:
            cur += 1; cnt = 0; dq = deque([(sy, sx)]); lbl[sy, sx] = cur
            while dq:
                y, x = dq.popleft(); cnt += 1
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < H and 0 <= nx < W and filled[ny, nx] and lbl[ny, nx] == 0:
                        lbl[ny, nx] = cur; dq.append((ny, nx))
            if cnt > best:
                best = cnt; bestid = cur
flame = lbl == bestid

# Moore-neighbour boundary trace (clockwise from the topmost-leftmost pixel).
ys, xs = np.where(flame)
start = (ys.min(), xs[ys == ys.min()].min())
nbr = [(-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1)]
inside = lambda y, x: 0 <= y < H and 0 <= x < W and flame[y, x]
contour = [start]; curp = start; bdir = 6; guard = 0
while guard < 200000:
    guard += 1
    hit = False
    for k in range(8):
        d = (bdir + 1 + k) % 8
        ny, nx = curp[0] + nbr[d][0], curp[1] + nbr[d][1]
        if inside(ny, nx):
            bdir = (d + 4) % 8; curp = (ny, nx)
            if curp == start and len(contour) > 2:
                hit = True; break
            contour.append(curp); hit = True; break
    if not hit or curp == start:
        break


def dp(pts, eps):
    if len(pts) < 3:
        return pts
    p0, p1 = np.array(pts[0]), np.array(pts[-1])
    ab = p1 - p0; L = np.hypot(*ab) + 1e-9
    dmax = idx = 0
    for i in range(1, len(pts) - 1):
        d = abs(np.cross(ab, np.array(pts[i]) - p0)) / L
        if d > dmax:
            dmax, idx = d, i
    if dmax > eps:
        return dp(pts[:idx + 1], eps)[:-1] + dp(pts[idx:], eps)
    return [pts[0], pts[-1]]


simp = dp(contour, 1.4)
pts = np.array(simp, float)
ymin, xmin = pts[:, 0].min(), pts[:, 1].min()
h = pts[:, 0].max() - ymin; w = pts[:, 1].max() - xmin
norm = [((x - xmin) / w, 1 - (y - ymin) / h) for y, x in pts]

Image.new("RGB", (300, 360), (255, 251, 244)).save(PREVIEW)  # ensure dir exists
prev = Image.new("RGB", (300, 360), (255, 251, 244)); dr = ImageDraw.Draw(prev)
dr.polygon([(20 + nx * 260, 20 + (1 - ny) * 320) for nx, ny in norm], fill=(242, 107, 33))
prev.save(PREVIEW)

print(f"// Traced from {SRC} — {len(norm)} points")
print("private static let flameSilhouette: [(CGFloat, CGFloat)] = [")
for nx, ny in norm:
    print(f"    ({nx:.4f}, {ny:.4f}),")
print("]")

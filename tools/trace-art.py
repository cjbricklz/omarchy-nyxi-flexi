#!/usr/bin/env python3
"""Turns NYXI's line drawing of the Flexi into the vector paths PadArt.qml draws (Paths.js).

The parts that light up (face buttons, D-pad cross, stick caps, centre buttons) are erased first,
because PadArt draws those live. Strokes are thinned to centre lines, followed pixel by pixel into
chains and simplified.

Usage: trace-art.py <drawing.png> <config.json> <out.js> [debug-preview.png]

The config names the part of the drawing to trace and what to erase first, in drawing coordinates:
  {"crop": [x0, y0, x1, y1], "threshold": 140, "speck": 0, "eraseHexes": "hexes.json", "erasePolys": "erase.json",
   "erase": [{"circle": [x, y, r]}, {"rect": [x0, y0, x1, y1]}, {"poly": [[x, y], ...]}]}
Needs: python3 with Pillow.
"""
import json
import os
import sys
from PIL import Image, ImageDraw

SCALE = 2


def thin(pixels):
    """Zhang-Suen thinning: shrinks strokes to one-pixel centre lines."""
    ring = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]   # P2..P9, clockwise from north
    pixels = set(pixels)
    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            drop = []
            for (x, y) in pixels:
                p = [(x + dx, y + dy) in pixels for dx, dy in ring]
                n = sum(p)
                if not 2 <= n <= 6:
                    continue
                if sum(1 for i in range(8) if not p[i] and p[(i + 1) % 8]) != 1:
                    continue
                if step == 0 and (p[0] and p[2] and p[4] or p[2] and p[4] and p[6]):
                    continue
                if step == 1 and (p[0] and p[2] and p[6] or p[0] and p[4] and p[6]):
                    continue
                drop.append((x, y))
            if drop:
                changed = True
                pixels.difference_update(drop)
    return pixels


def deburr(pixels):
    """Drops pixels that are redundant: three or more neighbours that already touch each other, so
    removing the pixel cannot break the line. What is left has two neighbours per pixel along a line,
    and only true junctions and ends stand out."""
    pixels = set(pixels)
    changed = True
    while changed:
        changed = False
        for (x, y) in sorted(pixels):
            near = [(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                    if (dx or dy) and (x + dx, y + dy) in pixels]
            if len(near) < 3:
                continue
            reach, todo = {near[0]}, [near[0]]       # are all neighbours connected without this pixel?
            while todo:
                cx, cy = todo.pop()
                for n in near:
                    if n not in reach and max(abs(n[0] - cx), abs(n[1] - cy)) == 1:
                        reach.add(n)
                        todo.append(n)
            if len(reach) == len(near):
                pixels.discard((x, y))
                changed = True
    return pixels


def chains(pixels):
    """Follows a one-pixel-wide skeleton into polylines, splitting at junctions."""
    nb = {}
    for (x, y) in pixels:
        nb[(x, y)] = [(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                      if (dx or dy) and (x + dx, y + dy) in pixels]
    seen, out = set(), []

    def walk(start, nxt):
        line, prev, cur = [start], start, nxt
        seen.add((start, nxt)); seen.add((nxt, start))
        while True:
            line.append(cur)
            if len(nb[cur]) != 2:
                break
            a, b = nb[cur]
            step = b if a == prev else a
            if (cur, step) in seen:
                break
            seen.add((cur, step)); seen.add((step, cur))
            prev, cur = cur, step
        return line

    nodes = [p for p in nb if len(nb[p]) != 2]
    for n in nodes:
        for m in nb[n]:
            if (n, m) not in seen:
                out.append(walk(n, m))
    for p in nb:   # closed loops with no junction at all
        for m in nb[p]:
            if (p, m) not in seen:
                out.append(walk(p, m))
    return out


def merge(lines):
    """Joins chains that meet end to end where exactly two of them touch, so a stroke stays one polyline."""
    lines = [list(l) for l in lines if len(l) >= 2]
    while True:
        ends = {}
        for i, l in enumerate(lines):
            for k in (0, -1):
                ends.setdefault(l[k], []).append((i, k))
        joined = False
        used = set()
        for pt, at in ends.items():
            if len(at) != 2 or at[0][0] == at[1][0] or at[0][0] in used or at[1][0] in used:
                continue
            (i, ki), (j, kj) = at
            a = lines[i] if ki == -1 else lines[i][::-1]       # ends at pt
            b = lines[j] if kj == 0 else lines[j][::-1]        # starts at pt
            lines[i] = a + b[1:]
            lines[j] = []
            used.update((i, j))
            joined = True
        lines = [l for l in lines if l]
        if not joined:
            return lines


def drop_specks(lines, longest):
    """Removes short chains that touch nothing else and are not closed loops: scanner noise, such as the
    stray dots left by the drawing's grip shading. A fragment of a real line always touches its neighbours."""
    owner = {}
    for i, l in enumerate(lines):
        for p in l:
            owner[p] = i
    near = [(dx, dy) for dx in range(-2, 3) for dy in range(-2, 3)]
    keep = []
    for i, l in enumerate(lines):
        closed = len(l) > 12 and abs(l[0][0] - l[-1][0]) <= 1 and abs(l[0][1] - l[-1][1]) <= 1
        touches = any(owner.get((e[0] + dx, e[1] + dy), i) != i for e in (l[0], l[-1]) for dx, dy in near)
        if len(l) < longest and not closed and not touches:
            continue
        keep.append(l)
    return keep


def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    (x1, y1), (x2, y2) = pts[0], pts[-1]
    dx, dy = x2 - x1, y2 - y1
    norm = (dx * dx + dy * dy) ** 0.5 or 1e-9
    best, idx = 0, 0
    for i in range(1, len(pts) - 1):
        d = abs(dy * (pts[i][0] - x1) - dx * (pts[i][1] - y1)) / norm
        if d > best:
            best, idx = d, i
    if best <= eps:
        return [pts[0], pts[-1]]
    return rdp(pts[:idx + 1], eps)[:-1] + rdp(pts[idx:], eps)


def main():
    src, config, out = sys.argv[1], sys.argv[2], sys.argv[3]
    preview = sys.argv[4] if len(sys.argv) > 4 else None
    cfg = json.load(open(config))
    crop = cfg["crop"]
    im = Image.open(src).convert("L").crop(crop)
    d = ImageDraw.Draw(im)
    ox, oy = crop[0], crop[1]
    for e in cfg.get("erase", []):
        if "circle" in e:
            x, y, r = e["circle"]
            d.ellipse([x - r - ox, y - r - oy, x + r - ox, y + r - oy], fill=255)
        elif "rect" in e:
            x0, y0, x1, y1 = e["rect"]
            d.rectangle([x0 - ox, y0 - oy, x1 - ox, y1 - oy], fill=255)
        elif "poly" in e:
            d.polygon([(x - ox, y - oy) for x, y in e["poly"]], fill=255)
    for poly in json.load(open(os.path.join(os.path.dirname(config), cfg["erasePolys"]))) if cfg.get("erasePolys") else []:
        d.polygon([(x - ox, y - oy) for x, y in poly], fill=255)
    for x, y, r in json.load(open(os.path.join(os.path.dirname(config), cfg["eraseHexes"]))) if cfg.get("eraseHexes") else []:
        d.ellipse([x - r - 7 - ox, y - r - 7 - oy, x + r + 7 - ox, y + r + 7 - oy], fill=255)
    w, h = im.size
    big = im.resize((w * SCALE, h * SCALE), Image.LANCZOS)   # finer grid, so the centre lines are smoother
    px = big.load()
    limit = cfg.get("threshold", 140)
    ink = {(x, y) for y in range(big.size[1]) for x in range(big.size[0]) if px[x, y] < limit}
    result = []
    traced = merge(chains(deburr(thin(ink))))
    if cfg.get("speck"):
        traced = drop_specks(traced, cfg["speck"] * SCALE)
    for c in traced:
        s = rdp(c, SCALE * 0.6)
        if len(s) >= 2:
            result.append([round(v / SCALE + off, 1) for p in s for v, off in ((p[0], ox), (p[1], oy))])
    with open(out, "w") as f:
        f.write("// Generated by tools/trace-art.py from NYXI's line drawing of the Flexi. Do not edit by hand.\n")
        f.write("// Each entry is one polyline: x0, y0, x1, y1, ... in drawing coordinates.\n")
        f.write("var PATHS = [\n")
        for line in result:
            f.write("  [" + ",".join(map(str, line)) + "],\n")
        f.write("]\n")
        f.write("\nif (typeof module !== \"undefined\") module.exports = { PATHS: PATHS }\n")
    print(len(result), "chains,", sum(len(l) // 2 for l in result), "points")
    if preview:
        pv = Image.new("RGB", (w, h), "white")
        pd = ImageDraw.Draw(pv)
        for line in result:
            pts = [(line[i] - ox, line[i + 1] - oy) for i in range(0, len(line), 2)]
            pd.line(pts, fill=(0, 0, 0), width=1)
        pv.save(preview)


if __name__ == "__main__":
    main()

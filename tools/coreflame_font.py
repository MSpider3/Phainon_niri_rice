#!/usr/bin/env python3
"""Builds the Coreflame fonts from stroke centre-lines, in the style of the in-game recurrence
counter (monoline, angular, a dotted diamond for 0):
  fonts/CoreflameDisplay-Regular.ttf, -Bold.ttf  full set: digits, A-Z, small-cap a-z, punctuation
  fonts/CoreflameNumerals.ttf                     digits 0-9 only, for the system-wide fontconfig rule
Each stroke is one quad per segment plus a disc at every point, all wound the same way, so the
overlaps fill (non-zero). Usage: python3 tools/coreflame_font.py [out-dir]"""
import math
import sys
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

UPM, CAP, XH, SB, BOX = 1000, 700, 500, 70, 420  # BOX: glyph box width at width-factor 1
ZERO_DOT = 45

# char: (centre-lines in a unit box, u right / v up, [(u, v, radius in half-strokes)], width factor)
G = {
    "0": ([[(0.5, 1), (0, 0.5), (0.5, 0), (1, 0.5), (0.5, 1)]], [(0.5, 0.5, None)], 1),
    "1": ([[(0.22, 0.82), (0.55, 1), (0.55, 0)]], [], 1),
    "2": ([[(0, 0.86), (0.15, 1), (1, 1), (0, 0), (1, 0)]], [], 1),
    "3": ([[(0, 1), (1, 1), (0.35, 0.56), (0.85, 0.48), (1, 0.3), (0.85, 0.08), (0.5, 0), (0, 0)]], [], 1),
    "4": ([[(0.8, 1), (0, 0.32), (1, 0.32)], [(0.8, 1), (0.8, 0)]], [], 1),
    "5": ([[(1, 1), (0.05, 1), (0.05, 0.55), (0.95, 0.55), (0.95, 0.25), (0.5, 0), (0.05, 0.2)]], [], 1),
    "6": ([[(0.15, 1), (0.03, 0.5), (1, 0.5), (0.5, 0), (0.03, 0.5)]], [], 1),
    "7": ([[(0, 0.84), (0.13, 1), (1, 1), (0.6, 0.5), (0.4, 0)]], [], 1),
    "8": ([[(0.5, 1), (0.18, 0.76), (0.5, 0.52), (0.82, 0.76), (0.5, 1)],
           [(0.5, 0.52), (0.02, 0.26), (0.5, 0), (0.98, 0.26), (0.5, 0.52)]], [], 1),
    "9": ([[(0.5, 1), (0.02, 0.5), (1, 0.5), (0.5, 1)], [(1, 0.5), (0.4, 0)]], [], 1),
    # Letters: drawn to match the digits (straight strokes, pointed bowls, hexagon O so it never reads as 0)
    "A": ([[(0, 0), (0.5, 1), (1, 0)], [(0.22, 0.38), (0.78, 0.38)]], [], 1),
    "B": ([[(0, 0), (0, 1), (0.72, 1), (0.92, 0.78), (0.72, 0.55), (0, 0.55)],
           [(0.72, 0.55), (1, 0.3), (0.78, 0), (0, 0)]], [], 1),
    "C": ([[(1, 0.84), (0.84, 1), (0.3, 1), (0, 0.66), (0, 0.34), (0.3, 0), (0.84, 0), (1, 0.16)]], [], 1),
    "D": ([[(0, 0), (0, 1), (0.6, 1), (1, 0.62), (1, 0.38), (0.6, 0), (0, 0)]], [], 1),
    "E": ([[(1, 1), (0, 1), (0, 0), (1, 0)], [(0, 0.52), (0.75, 0.52)]], [], 0.85),
    "F": ([[(1, 1), (0, 1), (0, 0)], [(0, 0.52), (0.75, 0.52)]], [], 0.85),
    "G": ([[(1, 0.84), (0.84, 1), (0.3, 1), (0, 0.66), (0, 0.34), (0.3, 0), (0.84, 0), (1, 0.16), (1, 0.45), (0.55, 0.45)]], [], 1),
    "H": ([[(0, 1), (0, 0)], [(1, 1), (1, 0)], [(0, 0.52), (1, 0.52)]], [], 1),
    "I": ([[(0.5, 1), (0.5, 0)], [(0, 1), (1, 1)], [(0, 0), (1, 0)]], [], 0.45),
    "J": ([[(0.3, 1), (1, 1), (1, 0.28), (0.55, 0), (0.05, 0.2)]], [], 0.85),
    "K": ([[(0, 1), (0, 0)], [(1, 1), (0, 0.42)], [(0.32, 0.62), (1, 0)]], [], 1),
    "L": ([[(0, 1), (0, 0), (1, 0)]], [], 0.85),
    "M": ([[(0, 0), (0, 1), (0.5, 0.32), (1, 1), (1, 0)]], [], 1.15),
    "N": ([[(0, 0), (0, 1), (1, 0), (1, 1)]], [], 1),
    "O": ([[(0.5, 1), (0, 0.76), (0, 0.24), (0.5, 0), (1, 0.24), (1, 0.76), (0.5, 1)]], [], 1),
    "P": ([[(0, 0), (0, 1), (0.75, 1), (1, 0.78), (0.75, 0.52), (0, 0.52)]], [], 1),
    "Q": ([[(0.5, 1), (0, 0.76), (0, 0.24), (0.5, 0), (1, 0.24), (1, 0.76), (0.5, 1)], [(0.62, 0.22), (1.05, -0.12)]], [], 1),
    "R": ([[(0, 0), (0, 1), (0.75, 1), (1, 0.78), (0.75, 0.52), (0, 0.52)], [(0.5, 0.52), (1, 0)]], [], 1),
    "S": ([[(1, 0.86), (0.86, 1), (0.14, 1), (0, 0.86), (0, 0.66), (0.14, 0.54), (0.86, 0.46), (1, 0.34),
            (1, 0.14), (0.86, 0), (0.14, 0), (0, 0.14)]], [], 1),
    "T": ([[(0, 1), (1, 1)], [(0.5, 1), (0.5, 0)]], [], 0.95),
    "U": ([[(0, 1), (0, 0.3), (0.5, 0), (1, 0.3), (1, 1)]], [], 1),
    "V": ([[(0, 1), (0.5, 0), (1, 1)]], [], 1),
    "W": ([[(0, 1), (0.25, 0), (0.5, 0.65), (0.75, 0), (1, 1)]], [], 1.3),
    "X": ([[(0, 1), (1, 0)], [(1, 1), (0, 0)]], [], 1),
    "Y": ([[(0, 1), (0.5, 0.5), (1, 1)], [(0.5, 0.5), (0.5, 0)]], [], 1),
    "Z": ([[(0, 1), (1, 1), (0, 0), (1, 0)], [(0.25, 0.5), (0.75, 0.5)]], [], 1),
    # Punctuation
    ".": ([], [(0.5, 0, 1.3)], 0.25),
    ",": ([[(0.55, 0), (0.35, -0.2)]], [], 0.25),
    ":": ([], [(0.5, 0.15, 1.3), (0.5, 0.6, 1.3)], 0.25),
    ";": ([[(0.55, 0.05), (0.35, -0.2)]], [(0.5, 0.6, 1.3)], 0.25),
    "·": ([], [(0.5, 0.45, 1.3)], 0.25),
    "!": ([[(0.5, 1), (0.5, 0.3)]], [(0.5, 0, 1.3)], 0.25),
    "?": ([[(0, 0.86), (0.15, 1), (0.85, 1), (1, 0.86), (1, 0.7), (0.5, 0.45), (0.5, 0.28)]], [(0.5, 0, 1.3)], 0.8),
    "'": ([[(0.5, 1), (0.5, 0.72)]], [], 0.2),
    '"': ([[(0, 1), (0, 0.72)], [(1, 1), (1, 0.72)]], [], 0.4),
    "-": ([[(0, 0.45), (1, 0.45)]], [], 0.55),
    "–": ([[(0, 0.45), (1, 0.45)]], [], 0.9),
    "—": ([[(0, 0.45), (1, 0.45)]], [], 1.6),
    "_": ([[(0, -0.1), (1, -0.1)]], [], 1),
    "/": ([[(0, -0.1), (1, 1.1)]], [], 0.6),
    "\\": ([[(0, 1.1), (1, -0.1)]], [], 0.6),
    "|": ([[(0.5, 1.15), (0.5, -0.15)]], [], 0.2),
    "(": ([[(1, 1.12), (0.25, 0.72), (0.25, 0.28), (1, -0.12)]], [], 0.4),
    ")": ([[(0, 1.12), (0.75, 0.72), (0.75, 0.28), (0, -0.12)]], [], 0.4),
    "[": ([[(1, 1.12), (0, 1.12), (0, -0.12), (1, -0.12)]], [], 0.35),
    "]": ([[(0, 1.12), (1, 1.12), (1, -0.12), (0, -0.12)]], [], 0.35),
    "<": ([[(1, 0.82), (0, 0.45), (1, 0.08)]], [], 0.7),
    ">": ([[(0, 0.82), (1, 0.45), (0, 0.08)]], [], 0.7),
    "+": ([[(0.5, 0.8), (0.5, 0.1)], [(0, 0.45), (1, 0.45)]], [], 0.75),
    "=": ([[(0, 0.6), (1, 0.6)], [(0, 0.3), (1, 0.3)]], [], 0.75),
    "*": ([[(0.5, 1), (0.5, 0.5)], [(0.1, 0.88), (0.9, 0.62)], [(0.1, 0.62), (0.9, 0.88)]], [], 0.65),
    "#": ([[(0.4, 1), (0.25, 0)], [(0.85, 1), (0.7, 0)], [(0.05, 0.68), (1, 0.68)], [(0, 0.32), (0.95, 0.32)]], [], 0.9),
    "%": ([[(0, 0), (1, 1)], [(0.18, 1), (0, 0.82), (0.18, 0.64), (0.36, 0.82), (0.18, 1)],
           [(0.82, 0.36), (0.64, 0.18), (0.82, 0), (1, 0.18), (0.82, 0.36)]], [], 0.9),
    "&": ([[(1, 0), (0.2, 0.72), (0.38, 1), (0.6, 1), (0.72, 0.82), (0, 0.32), (0.3, 0), (0.62, 0), (1, 0.42)]], [], 0.95),
    "°": ([[(0.5, 1), (0, 0.8), (0.5, 0.6), (1, 0.8), (0.5, 1)]], [], 0.4),
    "@": ([[(0.72, 0.3), (0.72, 0.72), (0.28, 0.5), (0.72, 0.3), (1, 0.3), (1, 0.76), (0.5, 1), (0, 0.76),
            (0, 0.24), (0.5, 0), (0.95, 0)]], [], 1.15),
}


def glyph_name(ch):
    return "space" if ch == " " else f"uni{ord(ch):04X}"


def outline(lines, dots, width, height, stroke):
    """Polygons for one glyph, in font units."""
    r = stroke / 2
    box = BOX * width

    def at(u, v):
        return SB + r + u * (box - stroke), r + v * (height - stroke)

    def disc(cx, cy, rad, n=20):
        return [(cx + rad * math.cos(2 * math.pi * i / n), cy + rad * math.sin(2 * math.pi * i / n)) for i in range(n)]

    polys = []
    for line in lines:
        pts = [at(*p) for p in line]
        for (px, py), (qx, qy) in zip(pts, pts[1:]):
            k = r / math.hypot(qx - px, qy - py)
            nx, ny = -(qy - py) * k, (qx - px) * k
            polys.append([(px + nx, py + ny), (qx + nx, qy + ny), (qx - nx, qy - ny), (px - nx, py - ny)])
        polys += [disc(*p, r) for p in pts]
    polys += [disc(*at(u, v), ZERO_DOT if s is None else s * r) for u, v, s in dots]
    return polys, round(box + 2 * SB)


def to_glyph(polys):
    pen = TTGlyphPen(None)
    for poly in polys:
        area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(poly, poly[1:] + poly[:1]))
        poly = poly[::-1] if area > 0 else poly  # TrueType fills clockwise contours
        pen.moveTo(tuple(round(c) for c in poly[0]))
        for pt in poly[1:]:
            pen.lineTo(tuple(round(c) for c in pt))
        pen.closePath()
    return pen.glyph()


def build(out, family, style, stroke, chars):
    glyphs = {".notdef": to_glyph([]), }
    advance = {".notdef": 560}
    cmap = {}
    if " " in chars:
        glyphs["space"], advance["space"], cmap[0x20] = to_glyph([]), 280, "space"
    for ch in chars:
        if ch == " ":
            continue
        lower = ch.islower() and ch.upper() in G
        lines, dots, width = G[ch.upper() if lower else ch]
        polys, adv = outline(lines, dots, width, XH if lower else CAP, stroke)
        name = glyph_name(ch)
        glyphs[name], advance[name], cmap[ord(ch)] = to_glyph(polys), adv, name

    bold = style == "Bold"
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(list(glyphs))
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    glyf = fb.font["glyf"]
    for n in glyphs:
        glyf[n].recalcBounds(glyf)
    fb.setupHorizontalMetrics({n: (advance[n], getattr(glyf[n], "xMin", 0)) for n in glyphs})
    fb.setupHorizontalHeader(ascent=900, descent=-250)
    ps = family.replace(" ", "") + "-" + style
    fb.setupNameTable({"familyName": family, "styleName": style, "fullName": f"{family} {style}",
                       "psName": ps, "uniqueFontIdentifier": ps, "version": "Version 1.0"})
    fb.setupOS2(sTypoAscender=900, sTypoDescender=-250, sTypoLineGap=0, usWinAscent=900, usWinDescent=250,
                sCapHeight=CAP, sxHeight=XH, usWeightClass=700 if bold else 400,
                fsSelection=0x20 if bold else 0x40)
    fb.font["head"].macStyle = 1 if bold else 0
    fb.setupPost()
    fb.save(out)

    font = TTFont(out)  # self-check: every requested character made it into the font
    missing = [c for c in chars if ord(c) not in font.getBestCmap()]
    assert not missing, f"{out}: missing {missing}"
    print("wrote", out, len(cmap), "chars")


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "fonts")
    full = " " + "".join(G) + "abcdefghijklmnopqrstuvwxyz"
    build(out / "CoreflameDisplay-Regular.ttf", "Coreflame Display", "Regular", 62, full)
    build(out / "CoreflameDisplay-Bold.ttf", "Coreflame Display", "Bold", 100, full)
    # Digits only: anything more (space, punctuation) would replace those characters system-wide too.
    build(out / "CoreflameNumerals.ttf", "Coreflame Numerals", "Regular", 62, "0123456789")

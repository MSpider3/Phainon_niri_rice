#!/usr/bin/env python3
"""Draws the boot splash's number digits and caption (plymouth/coreflame-recurrence/) in
Coreflame Display, with the same placement and glow the shell's cinematic overlay uses.
Needs Pillow. Re-run after changing the font, the caption or the layout values below.

    python3 tools/recurrence_splash.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "plymouth" / "coreflame-recurrence"
FONT = ROOT / "fonts" / "CoreflameDisplay-Regular.ttf"

# Same values as the shell's cinematic sidecar (video-relative), and its 2^0.2 zoom.
ZOOM = 2 ** 0.2
CAP, PITCH = 0.037, 0.0413
CAPTION = ["Eternal Recurrence", "Booting into the Simulation"]
CAPTION_Y, CAPTION_CAP = 0.642, 0.018
COLOR, GLOW = (0xE7, 0xD2, 0xAF), (0xB8, 0x79, 0x2A)
REF_W, REF_H = 1920, 1080  # drawn for a 1080p screen; the splash scales to others
MARGIN, BLUR = 24, 7


def glow(layer):
    """Gold halo under the text, like the shell's MultiEffect shadow."""
    a = layer.getchannel("A").filter(ImageFilter.GaussianBlur(BLUR))
    halo = Image.new("RGBA", layer.size, GLOW + (0,))
    halo.putalpha(a)
    return Image.alpha_composite(halo, layer)


def digits():
    cap = REF_H * ZOOM * CAP
    em = cap / 0.7
    font = ImageFont.truetype(str(FONT), round(em))
    w = round(REF_H * ZOOM * PITCH) + 2 * MARGIN
    h = round(cap) + 2 * MARGIN
    for d in "0123456789":
        layer = Image.new("RGBA", (w, h), COLOR + (0,))
        # Advance centre on the cell centre, cap centre on the image centre.
        ImageDraw.Draw(layer).text((w / 2 - 0.28 * em, MARGIN + cap), d, font=font, fill=COLOR, anchor="ls")
        glow(layer).save(OUT / f"d{d}.png", optimize=True)


def caption():
    em = REF_H * ZOOM * CAPTION_CAP / 0.7
    font = ImageFont.truetype(str(FONT), round(em))
    spacing = em * 0.12
    line_pitch = 1.35 * 1.15 * em  # Qt lineHeight 1.35 x the font's 1.15 em line
    baseline = REF_H * ((CAPTION_Y - 0.5) * ZOOM + 0.5 + ZOOM * CAPTION_CAP / 2)
    # Full-frame canvas, so the splash places it exactly like a video frame.
    layer = Image.new("RGBA", (REF_W, REF_H), COLOR + (0,))
    draw = ImageDraw.Draw(layer)
    for i, line in enumerate(CAPTION):
        width = sum(font.getlength(c) + spacing for c in line)
        x, y = REF_W / 2 - width / 2, baseline + i * line_pitch
        for c in line:
            draw.text((x, y), c, font=font, fill=COLOR, anchor="ls")
            x += font.getlength(c) + spacing
    glow(layer).save(OUT / "caption.png", optimize=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    digits()
    caption()
    made = sorted(p.name for p in OUT.glob("*.png"))
    assert made == ["caption.png"] + [f"d{d}.png" for d in "0123456789"], made
    print("Wrote", ", ".join(made), "to", OUT)

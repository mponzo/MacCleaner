#!/usr/bin/env python3
"""Render packaging/dmg-background.png (+ @1x) from DESIGN.md tokens."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "packaging"

W, H = 1440, 900  # 2× of 720×450 Finder window
CANVAS_DEEP = (7, 18, 36)
SEA = (77, 163, 255)
SEA_DEEP = (46, 107, 209)
NAVY = (22, 58, 107)
ACCENT = (255, 158, 72)
INK = (245, 249, 255)
MUTED = (169, 196, 232)

# 1× Finder icon centers (points)
PAD_1X = [(217, 238), (500, 240)]
PAD_R_1X = 124


def load_font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFCompact.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Unicode.ttf",
    ):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def main() -> None:
    img = Image.new("RGBA", (W, H), (*CANVAS_DEEP, 255))
    px = img.load()
    cx, cy = W // 2, int(H * 0.42)

    for y in range(H):
        for x in range(W):
            t = y / (H - 1)
            r = int(NAVY[0] * (1 - t) + CANVAS_DEEP[0] * t)
            g = int(NAVY[1] * (1 - t) + CANVAS_DEEP[1] * t)
            b = int(NAVY[2] * (1 - t) + CANVAS_DEEP[2] * t)
            dx = (x - cx) / (W * 0.55)
            dy = (y - cy) / (H * 0.55)
            glow = max(0.0, 1.0 - math.sqrt(dx * dx + dy * dy)) ** 1.8
            r = min(255, int(r + SEA_DEEP[0] * 0.35 * glow + SEA[0] * 0.12 * glow))
            g = min(255, int(g + SEA_DEEP[1] * 0.28 * glow + SEA[1] * 0.10 * glow))
            b = min(255, int(b + SEA_DEEP[2] * 0.40 * glow + SEA[2] * 0.18 * glow))
            vx = abs(x - W / 2) / (W / 2)
            vy = abs(y - H / 2) / (H / 2)
            vig = max(vx, vy) ** 2.2
            px[x, y] = (
                int(r * (1 - 0.28 * vig)),
                int(g * (1 - 0.28 * vig)),
                int(b * (1 - 0.28 * vig)),
                255,
            )

    pane = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pane)
    pd.rounded_rectangle([80, 120, 620, 420], radius=48, fill=(*SEA, 28))
    pd.rounded_rectangle([780, 380, 1380, 780], radius=56, fill=(*SEA_DEEP, 36))
    img = Image.alpha_composite(img, pane.rotate(-14, resample=Image.BICUBIC))

    pane2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(pane2).rounded_rectangle(
        [520, 160, 1120, 520], radius=52, fill=(*SEA, 18)
    )
    img = Image.alpha_composite(img, pane2.rotate(10, resample=Image.BICUBIC))

    pads = [(x * 2, y * 2) for x, y in PAD_1X]
    pad_r = PAD_R_1X * 2

    for center in pads:
        glow_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow_layer)
        cxp, cyp = center
        for i, a in enumerate([18, 12, 8]):
            rr = pad_r + 18 - i * 6
            gd.ellipse([cxp - rr, cyp - rr, cxp + rr, cyp + rr], fill=(*SEA, a))
        img = Image.alpha_composite(
            img, glow_layer.filter(ImageFilter.GaussianBlur(12))
        )

    draw = ImageDraw.Draw(img)
    for cxp, cyp in pads:
        overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.ellipse(
            [cxp - pad_r, cyp - pad_r, cxp + pad_r, cyp + pad_r],
            fill=(46, 107, 209, 42),
        )
        od.ellipse(
            [cxp - pad_r + 18, cyp - pad_r + 14, cxp + pad_r - 18, cyp - 20],
            fill=(77, 163, 255, 22),
        )
        img = Image.alpha_composite(img, overlay)
        draw = ImageDraw.Draw(img)
        for t in range(3):
            rr = pad_r - t
            draw.ellipse(
                [cxp - rr, cyp - rr, cxp + rr, cyp + rr],
                outline=(*INK, 90 - t * 20),
                width=2,
            )
        draw.ellipse(
            [cxp - pad_r + 4, cyp - pad_r + 4, cxp + pad_r - 4, cyp + pad_r - 4],
            outline=(*SEA, 70),
            width=2,
        )

    ax0, ay0 = pads[0][0] + pad_r - 20, pads[0][1]
    ax1, ay1 = pads[1][0] - pad_r + 20, pads[1][1]
    arrow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arrow)
    mid_y = ay0 - 36
    pts = []
    for i in range(48):
        t = i / 47
        x = (1 - t) * (1 - t) * ax0 + 2 * (1 - t) * t * ((ax0 + ax1) / 2) + t * t * ax1
        y = (1 - t) * (1 - t) * ay0 + 2 * (1 - t) * t * mid_y + t * t * ay1
        pts.append((x, y))
    for width, alpha in ((14, 40), (8, 90), (4, 200)):
        ad.line(pts, fill=(*SEA, alpha), width=width, joint="curve")
    tip = pts[-1]
    ad.polygon(
        [tip, (tip[0] - 28, tip[1] - 18), (tip[0] - 28, tip[1] + 18)],
        fill=(*SEA, 220),
    )
    img = Image.alpha_composite(img, arrow.filter(ImageFilter.GaussianBlur(6)))
    img = Image.alpha_composite(img, arrow)
    draw = ImageDraw.Draw(img)

    title_font = load_font(72)
    sub_font = load_font(30)
    foot_font = load_font(20)
    title, sub = "MacCleaner", "Drag to Applications"
    tb = draw.textbbox((0, 0), title, font=title_font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    sb = draw.textbbox((0, 0), sub, font=sub_font)
    sw = sb[2] - sb[0]
    tx, ty = (W - tw) // 2, 78
    draw.text((tx, ty + 2), title, font=title_font, fill=(0, 0, 0, 90))
    draw.text((tx, ty), title, font=title_font, fill=(*INK, 255))
    uy = ty + th + 10
    acc_glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(acc_glow).rounded_rectangle(
        [tx - 8, uy - 2, tx + tw + 8, uy + 8], radius=4, fill=(*ACCENT, 50)
    )
    img = Image.alpha_composite(img, acc_glow.filter(ImageFilter.GaussianBlur(6)))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([tx, uy, tx + tw, uy + 4], radius=2, fill=(*ACCENT, 240))
    draw.text(((W - sw) // 2, uy + 22), sub, font=sub_font, fill=(*MUTED, 230))
    foot = "Open source · Zero telemetry"
    fb = draw.textbbox((0, 0), foot, font=foot_font)
    draw.text(
        ((W - (fb[2] - fb[0])) // 2, H - 56),
        foot,
        font=foot_font,
        fill=(*MUTED, 110),
    )

    OUT.mkdir(parents=True, exist_ok=True)
    rgb = img.convert("RGB")
    path2x = OUT / "dmg-background.png"
    path1x = OUT / "dmg-background@1x.png"
    rgb.save(path2x, "PNG", optimize=True)
    rgb.resize((720, 450), Image.Resampling.LANCZOS).save(path1x, "PNG", optimize=True)
    # Finder/dmgbuild prefer TIFF for the volume background picture
    import subprocess

    tiff = OUT / "dmg-background@1x.tiff"
    subprocess.run(
        ["sips", "-s", "format", "tiff", str(path1x), "--out", str(tiff)],
        check=True,
        capture_output=True,
    )
    print(f"wrote {path2x} ({W}x{H})")
    print(f"wrote {path1x} (720x450)")
    print(f"wrote {tiff}")
    print(f"icon centers 1x: {PAD_1X}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate SondeApp.icns from the pixel-art mascot logo."""

import os
import shutil
import subprocess
from PIL import Image, ImageDraw

# Sonde mascot pixel art on a 16x16 grid
GREEN = (29, 158, 117)
EYE = (10, 26, 20)
RECTS = [
    (7, 2, 2, 2, GREEN),   # head top
    (4, 4, 8, 2, GREEN),   # head band
    (3, 6, 10, 5, GREEN),  # face
    (5, 7, 2, 2, EYE),     # left eye
    (9, 7, 2, 2, EYE),     # right eye
    (4, 11, 2, 2, GREEN),  # left foot
    (10, 11, 2, 2, GREEN), # right foot
]

BG_COLOR = (15, 23, 20)


def render_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    radius = int(size * 0.2237)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=BG_COLOR + (255,))

    padding = size * 0.15
    px = (size - 2 * padding) / 16.0

    for x, y, w, h, color in RECTS:
        x0 = int(padding + x * px)
        y0 = int(padding + y * px)
        x1 = int(padding + (x + w) * px)
        y1 = int(padding + (y + h) * px)
        draw.rectangle([x0, y0, x1, y1], fill=color + (255,))

    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    img.putalpha(mask)

    return img


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    iconset_dir = os.path.join(project_root, "SondeApp", "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    icon_specs = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for filename, size in icon_specs:
        img = render_icon(size)
        path = os.path.join(iconset_dir, filename)
        img.save(path, "PNG")
        print(f"  {filename} ({size}x{size})")

    icns_path = os.path.join(project_root, "SondeApp", "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print(f"\nCreated {icns_path}")

    shutil.rmtree(iconset_dir)


if __name__ == "__main__":
    main()

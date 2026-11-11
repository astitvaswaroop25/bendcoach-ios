#!/usr/bin/env python3
"""Draws the placeholder BendCoach app icon (1024x1024, no alpha, as the App Store requires).

Run: python3 tools/make_icon.py
Writes BendCoach/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "BendCoach/Assets.xcassets/AppIcon.appiconset/AppIcon.png"


def main():
    img = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(img)

    # Vertical charcoal gradient.
    top, bottom = (36, 40, 48), (16, 18, 22)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
        draw.line([(0, y), (SIZE, y)], fill=color)

    # An offset in conduit: low run, angled leg, high run.
    path = [(-40, 720), (360, 720), (664, 330), (1064, 330)]
    draw.line(path, fill=(92, 100, 110), width=150, joint="curve")   # shadow edge
    draw.line(path, fill=(196, 203, 210), width=118, joint="curve")  # galvanized body
    draw.line([(p[0], p[1] - 26) for p in path], fill=(232, 236, 240), width=22, joint="curve")  # highlight

    # Orange bend marks across the pipe, one before each bend.
    orange = (255, 122, 0)
    for x, y in [(250, 720), (770, 330)]:
        draw.rounded_rectangle([x - 16, y - 92, x + 16, y + 92], radius=12, fill=orange)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()

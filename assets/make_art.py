#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
#
# Draws logo.png, splash.png and icon.png from the glyph tables below. Run it from any folder: python3 assets/make_art.py
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
YELLOW = (255, 255, 0, 255)
GREEN = (0, 255, 0, 255)
BLACK = (0, 0, 0, 255)
CLEAR = (0, 0, 0, 0)

GLYPHS = {
    "C": [".#####.", "##...##", "##.....", "##.....", "##.....", "##.....", "##...##", ".#####."],
    "H": ["##...##", "##...##", "##...##", "#######", "#######", "##...##", "##...##", "##...##"],
    "U": ["##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".#####."],
    "K": ["##...##", "##..##.", "##.##..", "####...", "####...", "##.##..", "##..##.", "##...##"],
    "I": ["#######", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "#######"],
    "E": ["#######", "##.....", "##.....", "#####..", "#####..", "##.....", "##.....", "#######"],
    "G": [".#####.", "##...##", "##.....", "##.####", "##...##", "##...##", "##...##", ".#####."],
    " ": ["....", "....", "....", "....", "....", "....", "....", "...."],
}


def draw_word(image, word, x, y, scale, colour):
    px = image.load()
    for letter in word:
        rows = GLYPHS[letter]
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch == "#":
                    for dy in range(scale):
                        for dx in range(scale):
                            px[x + c * scale + dx, y + r * scale + dy] = colour
        x += (len(rows[0]) + 1) * scale
    return x


def word_width(word, scale):
    return sum((len(GLYPHS[l][0]) + 1) * scale for l in word) - scale


def logo():
    scale = 3
    width = word_width("CHUCKIE EGG", scale)
    image = Image.new("RGBA", (width, 8 * scale), CLEAR)
    draw_word(image, "CHUCKIE EGG", 0, 0, scale, YELLOW)
    image.save(os.path.join(HERE, "logo.png"))


def splash():
    image = Image.new("RGBA", (128, 96), BLACK)
    draw_word(image, "CHUCKIE", (128 - word_width("CHUCKIE", 2)) // 2, 14, 2, YELLOW)
    draw_word(image, "EGG", (128 - word_width("EGG", 2)) // 2, 36, 2, YELLOW)
    draw = ImageDraw.Draw(image)
    draw.text((26, 66), "32BLIT PORT", fill=GREEN)
    image.convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=4).save(os.path.join(HERE, "splash.png"))


def icon():
    rows = [
        "..yyyy..",
        ".yyyyyy.",
        "yyyyyyyy",
        "yyyyyyyy",
        "yyyyyyyy",
        "yyyyyyyy",
        ".yyyyyy.",
        "gggggggg",
    ]
    image = Image.new("RGB", (8, 8), (0, 0, 0))
    px = image.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "y":
                px[x, y] = (255, 255, 0)
            elif ch == "g":
                px[x, y] = (0, 255, 0)
    image.convert("P", palette=Image.ADAPTIVE, colors=3).save(os.path.join(HERE, "icon.png"))


logo()
splash()
icon()

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
#
# Draws logo.png, splash.png and icon.png from the glyph tables below. Run it from any folder: python3 assets/make_art.py
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
YELLOW = (255, 255, 0, 255)
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


PORT_TEXT = [
    ".1112..2112..11112.1.....1.2111112..11112.21112..111122111112",
    "22..1..1.21..1..21.1.....1....1.....1..2121...12.1..21...1...",
    "...21.22..1..1...1.1.....1....1.....1...112...21.1...1...1...",
    "..112....21..1..22.1.....1....1.....1..211.....1.1..21...1...",
    "...21....1...11111.1.....1....1.....1111.1.....1.1111....1...",
    "2...1...12...1..21.1.....1....1.....1....12...21.1..22...1...",
    "12.21..12....1...1.1.....1....1.....1....21...12.1..21...1...",
    ".1112.21111..11112.11112.1....1.....1.....21112..1...1...1...",
]
SPLASH_PALETTE = [255, 255, 0, 0, 222, 0, 0, 80, 0, 0, 0, 0]


def logo():
    scale = 3
    width = word_width("CHUCKIE EGG", scale)
    image = Image.new("RGBA", (width, 8 * scale), CLEAR)
    draw_word(image, "CHUCKIE EGG", 0, 0, scale, YELLOW)
    image.save(os.path.join(HERE, "logo.png"))


def splash():
    image = Image.new("P", (128, 96), 3)
    image.putpalette(SPLASH_PALETTE)
    draw_word(image, "CHUCKIE", (128 - word_width("CHUCKIE", 2)) // 2, 14, 2, 0)
    draw_word(image, "EGG", (128 - word_width("EGG", 2)) // 2, 36, 2, 0)
    px = image.load()
    for r, row in enumerate(PORT_TEXT):
        for c, ch in enumerate(row):
            if ch != ".":
                px[26 + c, 68 + r] = int(ch)
    image.save(os.path.join(HERE, "splash.png"))


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
    image = Image.new("P", (8, 8), 2)
    image.putpalette([255, 255, 0, 0, 255, 0, 0, 0, 0])
    px = image.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "y":
                px[x, y] = 0
            elif ch == "g":
                px[x, y] = 1
    image.save(os.path.join(HERE, "icon.png"))


logo()
splash()
icon()

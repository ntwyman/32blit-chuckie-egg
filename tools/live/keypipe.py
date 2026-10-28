#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
"""Send key events to the display from lines on stdin, over one X connection.

With a path argument it creates that file once the display is open.

Each line is `keydown <name>` or `keyup <name>`, with a key name as xdotool spells it (Left, Right, Up, Down, z).
`drive.sh play` uses it because starting xdotool for each event takes about 17 ms, and a game step is 30 ms."""
import ctypes
import os
import sys

x11 = ctypes.CDLL("libX11.so.6")
xtst = ctypes.CDLL("libXtst.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XStringToKeysym.restype = ctypes.c_ulong
x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
x11.XKeysymToKeycode.restype = ctypes.c_ubyte
x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x11.XFlush.argtypes = [ctypes.c_void_p]
xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]


def main():
    display = x11.XOpenDisplay(None)
    if not display:
        sys.exit("keypipe: cannot open the display")
    if len(sys.argv) > 1:
        open(sys.argv[1], "w").close()
    pending = b""
    while True:
        chunk = os.read(0, 4096)
        if not chunk:
            return
        pending += chunk
        *lines, pending = pending.split(b"\n")
        for raw in lines:
            send(display, raw.decode().split())


def send(display, words):
    if len(words) != 2 or words[0] not in ("keydown", "keyup"):
        sys.exit("keypipe: expected 'keydown <name>' or 'keyup <name>', got %r" % " ".join(words))
    keycode = x11.XKeysymToKeycode(display, x11.XStringToKeysym(words[1].encode()))
    if keycode == 0:
        sys.exit("keypipe: unknown key %r" % words[1])
    xtst.XTestFakeKeyEvent(display, keycode, 1 if words[0] == "keydown" else 0, 0)
    x11.XFlush(display)


main()

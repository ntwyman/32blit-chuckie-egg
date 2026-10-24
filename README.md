# Chuckie Egg for 32blit

![Build](https://github.com/ntwyman/32blit-chuckie-egg/workflows/Build/badge.svg)

A work-in-progress port of the classic Chuckie Egg, originally developed in
[ntwyman/32blit-beta](https://github.com/ntwyman/32blit-beta/tree/a6f2bce8b749c0004990718a892a6ca9fcd325d4/examples/chuckie-egg)
and moved here (built on the
[32blit boilerplate](https://github.com/32blit/32blit-boilerplate)) to build
against the current [32Blit SDK](https://github.com/32blit/32blit-sdk).

## Credits

Chuckie Egg is the original game by A & F Software. This port is based on Paul
Brook's C source, [Chuckie Egg](https://github.com/pbrook/Chuckie-Egg),
released under the GNU GPL v3. A read-only copy of that source, pinned to one
commit, is in [`third_party/pbrook-chuckie-egg/`](https://github.com/ntwyman/32blit-chuckie-egg/tree/main/third_party/pbrook-chuckie-egg).
The level and sprite data in `levels.cpp` and `sprites.cpp` come from Paul
Brook's `leveldata.c` and `spritedata.c`.

## License

This port is released under the GNU GPL v3, the same license as the C source it
is based on. See [`LICENSE`](LICENSE). Each source file carries an SPDX header
that credits Paul Brook and this port.

The port changes the original as follows.

* It is C++ on the 32Blit SDK. The original's SDL, OpenGL, and ncurses front
  ends are not used.
* It draws the game from a 32Blit sprite sheet, not from the original's
  renderers and 3D models.
* It does not play the original's sound yet.

## Building

For local builds this is:
```
mkdir build
cd build
cmake -D32BLIT_DIR=/path/to/32blit-sdk/ ..
```

### VS Code Dev Container

The `.devcontainer` folder defines a Linux (Ubuntu 24.04) development
container with the 32blit SDK (`/opt/32blit-sdk`), the Pico SDK
(`/opt/pico-sdk`), the PicoVision libraries (`/opt/picovision`), the 32blit
tools (built from source), SDL2, `gcc-arm-none-eabi`, Emscripten, the GitHub
CLI (`gh`) and the [Claude Code](https://claude.com/claude-code) CLI
preinstalled. Claude Code's and `gh`'s logins and settings are kept in Docker
volumes, so they survive rebuilds.

With Docker and the VS Code [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
extension installed, run "Dev Containers: Reopen in Container". CMake Tools
is preconfigured; pick a kit to choose the target:

* the detected GCC kit for local (SDL) builds
* "32Blit" for device builds
* "PicoSystem" for PicoSystem builds (produces a `.uf2`; to flash, hold X
  while powering on and copy it to the `RPI-RP2` drive)
* "Emscripten" for web builds (serve the build directory with
  `python3 -m http.server 8000`; the port is forwarded)

From the terminal, `cmake ..` finds the SDK automatically for local and
device builds. For PicoSystem, pass the toolchain:

```
cmake .. -DCMAKE_TOOLCHAIN_FILE=/opt/32blit-sdk/pico.toolchain
```

Other RP2040 boards can be selected with `-DPICO_BOARD=` (e.g.
`pimoroni_picovision`, which uses the preinstalled PicoVision libraries), and
RP2350 boards with `pico2.toolchain`.

Web builds need the SDK passed explicitly, as the Emscripten toolchain only
searches its own sysroot for packages:

```
emcmake cmake .. -D32BLIT_DIR=/opt/32blit-sdk
```

The SDK/tools/Pico SDK/PicoVision revisions and Emscripten install can be
changed via the build `args` in `.devcontainer/devcontainer.json`.

Note that Docker Desktop on macOS/Windows can't pass USB devices through, so
`32blit flash` only works from the container on a Linux host (see the
`runArgs` comment in `devcontainer.json`). Elsewhere, copy the `.blit` file to
the device or flash it from the host.

Platform/Editor specific insctuctions [can be found in the main 32blit repo](https://github.com/32blit/32blit-sdk#you-will-need)
(For Visual Studio, you should follow the "Option 2" instructions, as the boilerplate does not contain a solution file)

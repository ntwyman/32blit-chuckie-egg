// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

// Runs the port's Game on a parity input script with no screen and writes one
// FrameTrace line per input frame to stdout. With --bench it writes no trace
// and prints the mean time of one Game::Step to stderr instead.

#include "game.hpp"
#include "engine/api_private.hpp"
#include "inputs.h"

#include <chrono>
#include <cstdio>
#include <cstring>

static void host_debug(const char *message) { fputs(message, stderr); }

// The engine library sends debugf through blit::api, which only a platform
// layer defines. The SDL one owns main() and opens a window, so the driver
// defines the two objects itself with nothing but the debug hook.
static blit::APIConst host_api = [] {
  blit::APIConst api{};
  api.debug = host_debug;
  return api;
}();
static blit::APIData host_api_data;

namespace blit {
const APIConst &api = host_api;
APIData &api_data = host_api_data;
}

static const char usage[] = "port_driver [--level <n>] <script.inputs> [--bench]";

int main(int argc, char **argv) {
  int next;
  Inputs in = inputs_from_args(argc, argv, usage, &next);
  bool bench = next < argc && strcmp(argv[next], "--bench") == 0;
  if (next + (bench ? 1 : 0) != argc) {
    fprintf(stderr, "usage: %s\n", usage);
    return 2;
  }

  // Game depends on static storage to zero its members.
  static Game game(in.level);
  blit::Size screen(320, 240);
  game.SetScreenSize(screen);
  game.Step(BUTTON_A);
  game.Step(0);
  game.Step(BUTTON_A);

  if (bench) {
    auto start = std::chrono::steady_clock::now();
    for (size_t frame = 0; frame < in.count; frame++) {
      game.Step(in.buttons[frame]);
    }
    std::chrono::duration<double, std::micro> took = std::chrono::steady_clock::now() - start;
    fprintf(stderr, "port_driver: %zu steps, mean %.3f us per Game::Step\n", in.count,
            took.count() / (double)in.count);
    return 0;
  }

  for (size_t frame = 0; frame < in.count; frame++) {
    game.Step(in.buttons[frame]);
    FrameTrace t = game.Snapshot();
    trace_write(stdout, (int)frame, &t);
  }
  return 0;
}

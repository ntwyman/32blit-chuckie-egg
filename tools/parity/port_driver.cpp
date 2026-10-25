// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

#include "game.hpp"
#include "engine/api_private.hpp"
#include "inputs.h"
#include "trace_write.h"

#include <algorithm>
#include <chrono>
#include <vector>
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

static const int BATCH_RUNS = 200;

static const char usage[] = "port_driver [--level <n>] <script.inputs> [--bench]";

static void enterLevel(Game &game) {
  blit::Size screen(320, 240);
  game.SetScreenSize(screen);
  game.Step(BUTTON_A);
  game.Step(0);
  game.Step(BUTTON_A);
}

static double meanStepMicros(const Inputs &in, size_t frames) {
  Game game(in.level);
  enterLevel(game);
  auto start = std::chrono::steady_clock::now();
  for (size_t frame = 0; frame < frames; frame++) {
    game.Step(in.buttons[frame]);
  }
  std::chrono::duration<double, std::micro> took = std::chrono::steady_clock::now() - start;
  return took.count() / (double)frames;
}

static double medianBatchMicros(const Inputs &in, size_t frames, int runs) {
  std::vector<double> took;
  for (int run = 0; run < runs; run++) {
    Game game(in.level);
    enterLevel(game);
    auto start = std::chrono::steady_clock::now();
    for (size_t frame = 0; frame < frames; frame++) {
      game.Step(in.buttons[frame]);
    }
    took.push_back(std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - start).count());
  }
  std::sort(took.begin(), took.end());
  return took[took.size() / 2];
}

static void bench(const Inputs &in) {
  Game game(in.level);
  enterLevel(game);
  size_t framesToFirstDeath = in.count;
  for (size_t frame = 0; frame < in.count; frame++) {
    game.Step(in.buttons[frame]);
    if (game.Snapshot().dead) {
      framesToFirstDeath = frame + 1;
      break;
    }
  }
  fprintf(stderr, "port_driver: %zu steps, mean %.3f us per Game::Step\n", in.count,
          meanStepMicros(in, in.count));
  fprintf(stderr, "port_driver: %zu steps up to the first death, mean %.3f us per Game::Step\n",
          framesToFirstDeath, meanStepMicros(in, framesToFirstDeath));
  fprintf(stderr, "port_driver: batch of %zu steps up to the first death, median %.1f us over %d runs\n",
          framesToFirstDeath, medianBatchMicros(in, framesToFirstDeath, BATCH_RUNS), BATCH_RUNS);
}

int main(int argc, char **argv) {
  int next;
  Inputs in = inputs_from_args(argc, argv, usage, &next);
  bool benchmark = next < argc && strcmp(argv[next], "--bench") == 0;
  if (next + (benchmark ? 1 : 0) != argc) {
    fprintf(stderr, "usage: %s\n", usage);
    return 2;
  }
  if (benchmark) {
    bench(in);
    return 0;
  }

  Game game(in.level);
  enterLevel(game);
  for (size_t frame = 0; frame < in.count; frame++) {
    game.Step(in.buttons[frame]);
    FrameTrace t = game.Snapshot();
    trace_write(stdout, (int)frame, &t);
  }
  return 0;
}

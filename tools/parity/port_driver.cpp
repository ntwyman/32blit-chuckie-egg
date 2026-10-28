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

static bool quiet = false;

static void host_debug(const char *message) {
  if (!quiet) {
    fputs(message, stderr);
  }
}

// The engine library sends debugf through blit::api, which only a platform
// layer defines. The SDL one owns main() and opens a window, so the driver
// defines the two objects itself with nothing but the debug hook and the
// audio channels the game starts sounds on.
static blit::AudioChannel host_channels[CHANNEL_COUNT];
static blit::APIConst host_api = [] {
  blit::APIConst api{};
  api.debug = host_debug;
  api.channels = host_channels;
  return api;
}();
static blit::APIData host_api_data;

namespace blit {
const APIConst &api = host_api;
APIData &api_data = host_api_data;
}

static const int BATCH_RUNS = 200;

static const char usage[] = "port_driver [--level <n>] [--score <n>] [--players <n>] <script.inputs> [--bench <frames>]";

static void enterLevel(Game &game, int players) {
  blit::Size screen(320, 240);
  game.SetScreenSize(screen);
  for (int i = 1; i < players; i++) {
    game.Step(BUTTON_UP);
    game.Step(0);
  }
  game.Step(BUTTON_A);
  game.Step(0);
  game.Step(BUTTON_A);
}

// After a death with more than one player the port stops on a "Ready player" screen where the original goes
// straight to the next player's level. Answer that screen and replay the frame, so both traces hold the next
// player's first frame at the same index. Any other Ready screen is a port bug the trace must show. The port
// handles a death at the start of the next step, so Henry is already dead before it.
static void stepFrame(Game &game, uint8_t buttons, int players) {
  if (buttons & INPUTS_SKIP) {
    game.SkipLevel();
  }
  buttons &= INPUTS_BUTTONS;
  bool died = players > 1 && game.Snapshot().dead;
  game.Step(buttons);
  if (died && game.State() == GameState::READY_PLAYER) {
    game.Step(buttons & ~BUTTON_A);
    game.Step(buttons | BUTTON_A);
    game.Step(buttons);
  }
}

static double stepBatchMicros(const Inputs &in, size_t frames) {
  Game game(in.level, in.score);
  enterLevel(game, in.players);
  auto start = std::chrono::steady_clock::now();
  for (size_t frame = 0; frame < frames; frame++) {
    stepFrame(game, in.buttons[frame], in.players);
  }
  return std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - start).count();
}

static double medianBatchMicros(const Inputs &in, size_t frames, int runs) {
  std::vector<double> took;
  for (int run = 0; run < runs; run++) {
    took.push_back(stepBatchMicros(in, frames));
  }
  std::sort(took.begin(), took.end());
  return took[took.size() / 2];
}

static size_t framesUntilDeath(const Inputs &in) {
  Game game(in.level, in.score);
  enterLevel(game, in.players);
  for (size_t frame = 0; frame < in.count; frame++) {
    stepFrame(game, in.buttons[frame], in.players);
    if (game.Snapshot().dead) {
      return frame + 1;
    }
  }
  return in.count;
}

static int bench(const Inputs &in, size_t frames) {
  quiet = true;
  size_t live = framesUntilDeath(in);
  if (frames > live) {
    fprintf(stderr, "port_driver: Henry dies after %zu steps, so a batch of %zu would time game-over frames\n", live,
            frames);
    return 2;
  }
  double batch = medianBatchMicros(in, frames, BATCH_RUNS);
  double whole = stepBatchMicros(in, in.count);
  fprintf(stderr, "port_driver: batch of %zu steps, median %.1f us over %d runs\n", frames, batch, BATCH_RUNS);
  fprintf(stderr, "port_driver: %zu steps, mean %.3f us per Game::Step\n", in.count, whole / (double)in.count);
  return 0;
}

int main(int argc, char **argv) {
  int next;
  Inputs in = inputs_from_args(argc, argv, usage, &next);
  bool benchmark = next < argc && strcmp(argv[next], "--bench") == 0;
  if (next + (benchmark ? 2 : 0) != argc) {
    fprintf(stderr, "usage: %s\n", usage);
    return 2;
  }
  if (benchmark) {
    char *end;
    long frames = strtol(argv[next + 1], &end, 10);
    if (*end != '\0' || frames < 1 || (size_t)frames > in.count) {
      fprintf(stderr, "port_driver: --bench takes a frame count from 1 to %zu, got '%s'\n", in.count, argv[next + 1]);
      return 2;
    }
    return bench(in, (size_t)frames);
  }

  Game game(in.level, in.score);
  enterLevel(game, in.players);
  for (size_t frame = 0; frame < in.count; frame++) {
    stepFrame(game, in.buttons[frame], in.players);
    FrameTrace t = game.Snapshot();
    trace_write(stdout, (int)frame, &t);
  }
  return 0;
}

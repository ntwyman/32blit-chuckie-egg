// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

// The build applies tools/parity/patches/ to a copy of chuckie.c and this
// file includes that copy, so the trace can read the file-static Henry state.

#include "chuckie.c"
#include "inputs.h"
#include "trace_write.h"

#include <signal.h>
#include <unistd.h>

int parity_start_level;

static Inputs script;
static size_t frame;

static void no_player(void) {}
static void no_digit(int n) {}
static void no_score(int n, int oldval, int newval) {}
static void no_tile(int x, int y, int type) {}
static void no_lift(int x, int y) {}

static raster_hooks no_raster = {
    no_player, no_player, no_digit, no_digit, no_score, no_tile,
    no_player, no_digit,  no_digit, no_lift,  no_player,
};
raster_hooks *raster = &no_raster;

void sound_start(int pitch, int kind) {}
void RenderBackground(void) {}

static int32_t digits(const uint8_t *d, int n) {
  int32_t value = 0;
  for (int i = 0; i < n; i++) {
    value = value * 10 + d[i];
  }
  return value;
}

void PollKeys(void) {
  if (frame == script.count) {
    fflush(stdout);
    exit(0);
  }
  buttons = script.buttons[frame];
}

void RenderFrame(void) {
  FrameTrace t = {0};
  t.henry_x = player_x;
  t.henry_y = player_y;
  t.henry_tile_x = player_tilex;
  t.henry_tile_y = player_tiley;
  t.henry_partial_x = player_partial_x;
  t.henry_partial_y = player_partial_y;
  t.henry_mode = player_mode;
  t.dead = is_dead != 0 || player_y < 0x11;
  t.score = digits(player_data->score, 8);
  t.lives = player_data->lives;
  t.bonus = digits(bonus, 4);
  t.timer = digits(timer_ticks, 3);
  t.has_lift = have_lift;
  if (have_lift) {
    t.lift_x = lift_x;
    t.lift_y[0] = lift_y[0];
    t.lift_y[1] = lift_y[1];
  }
  t.duck_timer = duck_timer;
  t.current_duck = current_duck;
  t.hens = num_ducks;
  for (int i = 0; i < num_ducks; i++) {
    t.hen[i].x = duck[i].x;
    t.hen[i].y = duck[i].y;
    t.hen[i].mode = duck[i].mode;
  }
  trace_write(stdout, (int)frame, &t);
  frame++;
}

// Upstream calls abort() when the timer runs out (chuckie.c MoveDucks).
// abort() is called from the game loop itself, not from another thread, so
// stdout is not mid-write here.
static void on_abort(int sig) {
  printf("frame=%zu abort=1\n", frame);
  fflush(stdout);
  _exit(0);
}

int main(int argc, char **argv) {
  int next;
  script = inputs_from_args(argc, argv, "original_driver [--level <n>] <script.inputs>", &next);
  if (next != argc) {
    fprintf(stderr, "usage: original_driver [--level <n>] <script.inputs>\n");
    return 2;
  }
  parity_start_level = script.level - 1;
  signal(SIGABRT, on_abort);
  run_game();
  return 0;
}

// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

// One frame of game state, in upstream chuckie.c's units: x from the left
// edge of the play field and y up from its bottom row, both in pixels.
// Both parity drivers write it with trace_write, so the two traces compare
// line for line.

#ifndef CHUCKIE_PARITY_TRACE_H
#define CHUCKIE_PARITY_TRACE_H

#include <stdint.h>
#include <stdio.h>

#define TRACE_MAX_HENS 5

typedef struct {
  int32_t x;
  int32_t y;
  int32_t mode;
} HenTrace;

typedef struct {
  int32_t henry_x;
  int32_t henry_y;
  int32_t henry_tile_x;
  int32_t henry_tile_y;
  int32_t henry_partial_x;
  int32_t henry_partial_y;
  int32_t henry_mode;
  int32_t score;
  int32_t lives;
  int32_t bonus;
  int32_t timer;
  int32_t has_lift;
  int32_t lift_x;
  int32_t lift_y[2];
  int32_t duck_timer;
  int32_t current_duck;
  int32_t hens;
  HenTrace hen[TRACE_MAX_HENS];
} FrameTrace;

// Writes one line of name=value fields. A level without a lift has no lift
// fields, and only the level's hens are written, because the rest hold stale
// values in both games.
static inline void trace_write(FILE *out, int frame, const FrameTrace *t) {
  fprintf(out,
          "frame=%d henry_x=%d henry_y=%d henry_tile_x=%d henry_tile_y=%d"
          " henry_partial_x=%d henry_partial_y=%d henry_mode=%d"
          " score=%d lives=%d bonus=%d timer=%d",
          frame, (int)t->henry_x, (int)t->henry_y, (int)t->henry_tile_x,
          (int)t->henry_tile_y, (int)t->henry_partial_x, (int)t->henry_partial_y,
          (int)t->henry_mode, (int)t->score, (int)t->lives, (int)t->bonus,
          (int)t->timer);
  if (t->has_lift) {
    fprintf(out, " lift_x=%d lift_y0=%d lift_y1=%d", (int)t->lift_x,
            (int)t->lift_y[0], (int)t->lift_y[1]);
  }
  fprintf(out, " duck_timer=%d current_duck=%d hens=%d", (int)t->duck_timer,
          (int)t->current_duck, (int)t->hens);
  for (int i = 0; i < t->hens && i < TRACE_MAX_HENS; i++) {
    fprintf(out, " hen%d_x=%d hen%d_y=%d hen%d_mode=%d", i, (int)t->hen[i].x, i,
            (int)t->hen[i].y, i, (int)t->hen[i].mode);
  }
  fputc('\n', out);
}

#endif

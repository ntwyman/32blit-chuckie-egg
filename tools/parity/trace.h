// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

// One frame of game state, in upstream chuckie.c's units: x from the left
// edge of the play field and y up from its bottom row, both in pixels.
// trace_write.h writes it for both parity drivers.

#ifndef CHUCKIE_PARITY_TRACE_H
#define CHUCKIE_PARITY_TRACE_H

#include <stdint.h>

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
  int32_t dead;
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

#endif

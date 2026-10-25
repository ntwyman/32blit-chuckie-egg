// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

#include "frame_clock.hpp"
#include <cstdio>

static int failures = 0;

static void expect(uint32_t got, uint32_t want, const char *what) {
  if (got != want) {
    fprintf(stderr, "clock_test: %s: expected %u, got %u\n", what, want, got);
    failures++;
  }
}

static uint32_t feed(FrameClock &clock, uint32_t &now, uint32_t duration, uint32_t period) {
  uint32_t steps = 0;
  for (uint32_t end = now + duration; now != end;) {
    now += period;
    steps += clock.due(now);
  }
  return steps;
}

int main() {
  FrameClock clock;
  uint32_t now = 1000;
  expect(clock.due(now), 0, "the first call");
  expect(feed(clock, now, 3000, 10), 100, "steps in 3 seconds of 10 ms updates");

  now += 500;
  expect(clock.due(now), 2, "steps after a 500 ms jump");
  expect(feed(clock, now, 300, 10), 10, "steps in 300 ms of 10 ms updates after the jump");
  expect(feed(clock, now, 300, 30), 10, "steps in 300 ms of 30 ms updates after the jump");

  FrameClock slow;
  now = 0;
  slow.due(now);
  expect(feed(slow, now, 900, 45), 30, "steps in 900 ms of 45 ms updates");

  FrameClock wrap;
  now = 0xFFFFFFF0u;
  wrap.due(now);
  expect(feed(wrap, now, 3000, 10), 100, "steps across the 32-bit timestamp wrap");

  FrameClock gap;
  now = 5000;
  gap.due(now);
  now += 29;
  expect(gap.due(now), 0, "steps after a 29 ms gap");
  now += 1;
  expect(gap.due(now), 1, "steps after a 30 ms gap");

  FrameClock backlog;
  now = 9000;
  backlog.due(now);
  now += 61;
  expect(backlog.due(now), 2, "steps after a 61 ms gap");
  now += 28;
  expect(backlog.due(now), 0, "steps 28 ms after a 61 ms gap");
  now += 1;
  expect(backlog.due(now), 1, "steps 29 ms after a 61 ms gap");

  FrameClock dropped;
  now = 13000;
  dropped.due(now);
  now += 91;
  expect(dropped.due(now), 2, "steps after a 91 ms gap");
  now += 29;
  expect(dropped.due(now), 0, "steps 29 ms after a 91 ms gap");
  now += 1;
  expect(dropped.due(now), 1, "steps 30 ms after a 91 ms gap");

  if (failures == 0) {
    printf("clock: ok\n");
  }
  return failures == 0 ? 0 : 1;
}

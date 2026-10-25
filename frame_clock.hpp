// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

#pragma once
#include <cstdint>

class FrameClock {
public:
  static constexpr uint32_t STEP_MS = 30;
  static constexpr uint32_t MAX_STEPS_PER_CALL = 2;

  uint32_t due(uint32_t now) {
    if (!started) {
      started = true;
      last = now;
      return 0;
    }
    uint32_t steps = (now - last) / STEP_MS;
    if (steps > MAX_STEPS_PER_CALL) {
      last = now;
      return MAX_STEPS_PER_CALL;
    }
    last += steps * STEP_MS;
    return steps;
  }

private:
  bool started = false;
  uint32_t last = 0;
};

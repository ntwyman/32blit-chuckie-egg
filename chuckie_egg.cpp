// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2009-2011 Paul Brook
// 32Blit port Copyright (C) 2020-2026 ntwyman

#include "32blit.hpp"
#include "frame_clock.hpp"
#include "game.hpp"
#include "assets.hpp"

using namespace blit;

FrameClock frame_clock;
uint32_t step_count = 0;
Game game(CHUCKIE_START_LEVEL, CHUCKIE_START_SCORE);

void init() {
  set_screen_mode(ScreenMode::hires);
  game.SetScreenSize(screen.bounds);
  game.InitAudio();
  screen.sprites = Surface::load(asset_sprites);
  game.SetLogo(Surface::load(asset_logo));
  uint8_t save[HS_SAVE_SIZE];
  if (read_save(reinterpret_cast<char *>(save), sizeof(save))) {
    if (!game.LoadScores(save, sizeof(save))) {
      debugf("Ignored an unusable save, using the default high scores\r\n");
    }
  }
}

static uint8_t readButtons() {
  uint8_t down = 0;
  if (pressed(Button::DPAD_LEFT) || joystick.x < -0.1f) {
    down |= BUTTON_LEFT;
  }
  if (pressed(Button::DPAD_RIGHT) || joystick.x > 0.1f) {
    down &= ~BUTTON_LEFT;
    down |= BUTTON_RIGHT;
  }
  if (pressed(Button::DPAD_UP) || joystick.y < -0.1f) {
    down |= BUTTON_UP;
  }
  if (pressed(Button::DPAD_DOWN) || joystick.y > 0.1f) {
    down &= ~BUTTON_UP;
    down |= BUTTON_DOWN;
  }
  if (pressed(Button::A | Button::JOYSTICK)) {
    down |= BUTTON_A;
  }
  return down;
}

void update(uint32_t time) {
  // After a stall the engine replays updates with stamped times, so only now() shows the backlog.
  uint32_t steps = frame_clock.due(now());
  for (uint32_t i = 0; i < steps; i++) {
    game.Step(readButtons());
#ifndef TARGET_32BLIT_HW
    if (game.BeepNote() != NO_NOTE) {
      debugf("Beep note %d\r\n", game.BeepNote());
    }
    if (game.NoiseNote() != NO_NOTE) {
      debugf("Noise note %d\r\n", game.NoiseNote());
    }
#endif
  }
  if (game.TakeScoresChanged()) {
    uint8_t save[HS_SAVE_SIZE];
    game.EncodeScores(save);
    write_save(reinterpret_cast<const char *>(save), sizeof(save));
    debugf("Saved the high scores\r\n");
  }
  if (steps > 0) {
    step_count += steps;
    debugf("Step %u: ran %u at %u ms\r\n", step_count, steps, now());
  }
}

void render(uint32_t time) {
  screen.pen = Pen(0, 0, 0);
  screen.clear();
  game.Render(screen);
}

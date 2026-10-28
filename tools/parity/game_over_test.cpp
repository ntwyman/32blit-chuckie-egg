// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

// The trace diff cannot see the game-over screen, because the original starts a new game at
// once. This drives Game through the five deaths and checks when A leaves the screen.

#include "game.hpp"
#include "engine/api_private.hpp"

#include <cstdio>

static blit::APIConst host_api = [] {
  blit::APIConst api{};
  api.debug = [](const char *) {};
  return api;
}();
static blit::APIData host_api_data;

namespace blit {
const APIConst &api = host_api;
APIData &api_data = host_api_data;
}

static const int LOCK_STEPS = 67;

static int failures = 0;

static void expect(bool ok, const char *what) {
  if (!ok) {
    fprintf(stderr, "game_over_test: %s\n", what);
    failures++;
  }
}

static void steps(Game &game, int count, uint8_t buttons) {
  for (int i = 0; i < count; i++) {
    game.Step(buttons);
  }
}

// Level 2, one player. Each life runs right to the grain and then left into the gap in the floor.
static Game gameOver() {
  Game game(2, 0);
  blit::Size screen(320, 240);
  game.SetScreenSize(screen);
  game.Step(BUTTON_A);
  game.Step(0);
  game.Step(BUTTON_A);
  for (int life = 0; life < 5; life++) {
    steps(game, 100, 0);
    steps(game, 60, BUTTON_RIGHT);
    steps(game, 93, BUTTON_LEFT);
    game.Step(0);
  }
  return game;
}

int main() {
  {
    Game game(1, 0);
    blit::Size screen(320, 240);
    game.SetScreenSize(screen);
    game.Step(BUTTON_A);
    game.Step(0);
    game.Step(BUTTON_A);
    game.SkipLevel();
    steps(game, 2, 0);
    expect(game.Snapshot().level == 1 && game.Snapshot().bonus == 2000, "a skipped level 1 leads to level 2 with a 2,000 bonus");
    for (int life = 0; life < 5; life++) {
      steps(game, 100, 0);
      steps(game, 60, BUTTON_RIGHT);
      steps(game, 93, BUTTON_LEFT);
      game.Step(0);
    }
    expect(game.State() == GameState::GAME_OVER, "five deaths on level 2 show game over");
    steps(game, LOCK_STEPS, 0);
    game.Step(BUTTON_A);
    game.Step(0);
    game.Step(BUTTON_A);
    game.Step(0);
    game.Step(BUTTON_A);
    FrameTrace t = game.Snapshot();
    expect(game.State() == GameState::LEVEL, "a new game starts after game over");
    expect(t.level == 0 && t.bonus == 1000 && t.lives == 5 && t.score == 0,
           "the new game starts on level 1 with its own bonus, lives and score, not the level reached");
  }
  {
    Game game = gameOver();
    expect(game.State() == GameState::GAME_OVER, "the fifth death shows game over");
    game.Step(BUTTON_A);
    expect(game.State() == GameState::GAME_OVER, "a fresh A on the first step skips the screen");
  }
  {
    Game game = gameOver();
    for (int i = 0; i < LOCK_STEPS - 1; i++) {
      game.Step(i % 2 ? 0 : BUTTON_A);
    }
    expect(game.State() == GameState::GAME_OVER, "A tapped for 66 steps skips the screen");
    game.Step(BUTTON_A);
    expect(game.State() == GameState::GAME_OVER, "the press on step 67 skips the screen");
    game.Step(0);
    game.Step(BUTTON_A);
    expect(game.State() == GameState::HOW_MANY, "a fresh press on step 69 does not return to the player-count screen");
  }
  {
    Game game = gameOver();
    steps(game, 80, BUTTON_A);
    expect(game.State() == GameState::GAME_OVER, "an A held from the first step through two seconds does something");
    game.Step(0);
    game.Step(BUTTON_A);
    expect(game.State() == GameState::HOW_MANY, "a release and a new press do not return to the player-count screen");
  }
  {
    Game game = gameOver();
    steps(game, LOCK_STEPS, 0);
    game.Step(BUTTON_A);
    expect(game.State() == GameState::HOW_MANY, "a fresh A after two seconds does not return at once");
  }
  if (failures == 0) {
    puts("game_over_test: ok");
  }
  return failures == 0 ? 0 : 1;
}

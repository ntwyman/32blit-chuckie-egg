// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

// The trace diff cannot see the title or the high score table, because the original has neither.

#include "game.hpp"
#include "high_scores.hpp"
#include "engine/api_private.hpp"

#include <cstdio>
#include <cstring>

static blit::AudioChannel host_channels[CHANNEL_COUNT];
static blit::APIConst host_api = [] {
  blit::APIConst api{};
  api.debug = [](const char *) {};
  api.channels = host_channels;
  return api;
}();
static blit::APIData host_api_data;

namespace blit {
const APIConst &api = host_api;
APIData &api_data = host_api_data;
}

static int failures = 0;

static void expect(bool ok, const char *what) {
  if (!ok) {
    fprintf(stderr, "high_score_test: %s\n", what);
    failures++;
  }
}

static bool named(const HighScores &t, int rank, uint32_t score, const char *name) {
  return t.At(rank).score == score && strcmp(t.At(rank).name, name) == 0;
}

static void tableRules() {
  HighScores t;
  expect(named(t, 0, 325000, "NIK") && named(t, 4, 50000, "EGG-THE") && named(t, 6, 30000, "SAE FOR") &&
             named(t, 9, 50, "A&F"),
         "the default table is the original's");
  expect(!t.Qualifies(0), "a score of 0 does not qualify");
  expect(!t.Qualifies(50), "a score equal to the tenth entry does not qualify");
  expect(t.Qualifies(51), "a score above the tenth entry qualifies");
  expect(t.RankFor(51) == 9 && t.RankFor(400000) == 0 && t.RankFor(25000) == 7 && t.RankFor(50) == -1,
         "RankFor gives the rank a score takes");
  expect(t.Insert(0, "ZERO") == -1 && named(t, 9, 50, "A&F"), "Insert refuses a score of 0 and changes nothing");
  expect(t.Insert(25000, "ME") == 7, "a score of 25,000 takes rank 8");
  expect(named(t, 6, 30000, "SAE FOR") && named(t, 7, 25000, "ME") && named(t, 8, 20000, "RELEASE") &&
             named(t, 9, 10000, "DETAILS"),
         "the entries below move down and the last drops off");
  expect(t.Insert(25000, "TIE") == 8 && named(t, 7, 25000, "ME") && named(t, 8, 25000, "TIE"),
         "a tie goes below the existing entry");
  expect(t.Insert(500000, "TOP") == 0 && named(t, 0, 500000, "TOP") && named(t, 1, 325000, "NIK"), "a new best takes rank 1");
  expect(t.Insert(1, "LOW") == -1, "a score under the tenth entry does not qualify");
  expect(t.Insert(100000, "ABCDEFGHI") >= 0, "a long name is accepted");
  int rank = t.RankFor(100001);
  t.Insert(100001, "TOOLONGNAME");
  expect(strcmp(t.At(rank).name, "TOOLONG") == 0, "a name is cut to 7 characters");
  rank = t.RankFor(100002);
  t.Insert(100002, "A   ");
  expect(strcmp(t.At(rank).name, "A") == 0, "trailing spaces are trimmed");
  rank = t.RankFor(100003);
  t.Insert(100003, "   ");
  expect(strcmp(t.At(rank).name, "ANON") == 0, "an empty name becomes ANON");
  rank = t.RankFor(100004);
  t.Insert(100004, "a\x01z");
  expect(strcmp(t.At(rank).name, "...") == 0, "characters outside the set become dots");
  uint8_t save[HS_SAVE_SIZE];
  t.Encode(save);
  HighScores back;
  expect(back.Decode(save, sizeof(save)) && strcmp(back.At(rank).name, "...") == 0,
         "a table with a sanitized name survives its save round trip");
}

static void saveRoundTrip() {
  HighScores t;
  t.Insert(77777, "ROUND");
  t.Insert(999999, "A.B-C&D");
  uint8_t save[HS_SAVE_SIZE];
  t.Encode(save);
  expect(memcmp(save, "CHKE", 4) == 0 && save[4] == 1, "a save starts with the magic and version 1");
  HighScores back;
  back.Reset();
  expect(back.Decode(save, sizeof(save)), "a good save decodes");
  bool same = true;
  for (int i = 0; i < HS_ENTRIES; i++) {
    same = same && named(back, i, t.At(i).score, t.At(i).name);
  }
  expect(same, "a save round trip keeps every entry");
  uint8_t longer[HS_SAVE_SIZE + 16];
  memset(longer, 0, sizeof(longer));
  memcpy(longer, save, sizeof(save));
  expect(HighScores().Decode(longer, sizeof(longer)), "a longer file with a good start decodes");
}

static void corruptSaves() {
  HighScores t;
  t.Insert(77777, "ROUND");
  uint8_t good[HS_SAVE_SIZE];
  t.Encode(good);
  auto rejects = [&](const char *what, void (*corrupt)(uint8_t *), size_t size) {
    uint8_t bad[HS_SAVE_SIZE];
    memcpy(bad, good, sizeof(bad));
    corrupt(bad);
    HighScores into;
    into.Insert(123456, "KEEP");
    bool ok = !into.Decode(bad, size) && named(into, 0, 325000, "NIK") && named(into, 9, 50, "A&F");
    expect(ok, what);
  };
  rejects("a short save falls back to the default table", [](uint8_t *) {}, HS_SAVE_SIZE - 1);
  rejects("an empty save falls back to the default table", [](uint8_t *) {}, 0);
  rejects("a wrong magic falls back", [](uint8_t *b) { b[0] = 'X'; }, HS_SAVE_SIZE);
  rejects("an old or new version falls back", [](uint8_t *b) { b[4] = 2; }, HS_SAVE_SIZE);
  rejects("a flipped score bit falls back", [](uint8_t *b) { b[7] ^= 0x10; }, HS_SAVE_SIZE);
  rejects("a flipped checksum bit falls back", [](uint8_t *b) { b[HS_SAVE_SIZE - 1] ^= 1; }, HS_SAVE_SIZE);
  // The rest keep the checksum right, so each one reaches the rule it names.
  auto sealed = [&](const char *what, void (*corrupt)(uint8_t *)) {
    uint8_t bad[HS_SAVE_SIZE];
    memcpy(bad, good, sizeof(bad));
    corrupt(bad);
    uint32_t hash = 2166136261u;
    for (size_t i = 0; i < HS_SAVE_SIZE - 4; i++) {
      hash = (hash ^ bad[i]) * 16777619u;
    }
    for (int i = 0; i < 4; i++) {
      bad[HS_SAVE_SIZE - 4 + i] = (uint8_t)(hash >> (8 * i));
    }
    HighScores into;
    into.Insert(123456, "KEEP");
    bool ok = !into.Decode(bad, sizeof(bad)) && named(into, 0, 325000, "NIK") && named(into, 9, 50, "A&F");
    expect(ok, what);
  };
  expect(HighScores().Decode(good, sizeof(good)), "the unmodified save is accepted, so each rejection below is its own rule");
  sealed("a name with no end falls back", [](uint8_t *b) { memset(b + 10, 'A', 8); });
  sealed("a name with a lowercase letter falls back", [](uint8_t *b) { b[10] = 'a'; });
  sealed("an empty name falls back", [](uint8_t *b) { b[10] = 0; });
  sealed("a byte after the end of a name falls back", [](uint8_t *b) { b[10 + 7] = 'Z'; });
  sealed("a score over 99,999,999 falls back", [](uint8_t *b) { b[6] = 0xff; b[7] = 0xff; b[8] = 0xff; b[9] = 0xff; });
  sealed("an unsorted table falls back", [](uint8_t *b) { b[18] = 0x80; b[19] = 0x1a; b[20] = 0x06; b[21] = 0; });
  sealed("a nonzero reserved byte falls back", [](uint8_t *b) { b[5] = 1; });
  uint8_t zeros[HS_SAVE_SIZE] = {};
  expect(!HighScores().Decode(zeros, sizeof(zeros)), "an all-zero save falls back");
}

static blit::Size screen(320, 240);

static void steps(Game &game, int count, uint8_t buttons) {
  for (int i = 0; i < count; i++) {
    game.Step(buttons);
  }
}

static void tap(Game &game, uint8_t buttons) {
  game.Step(buttons);
  game.Step(0);
}

// With grain, level 2: each life runs right to the grain and then left into the gap in the floor. Without, level 3: Henry stands still and scores nothing.
static void playToGameOver(Game &game, int players, bool grain = true) {
  for (int i = 1; i < players; i++) {
    tap(game, BUTTON_UP);
  }
  tap(game, BUTTON_A);
  game.Step(BUTTON_A);
  for (int life = 0; life < 5 * players + 1 && game.State() != GameState::GAME_OVER; life++) {
    if (grain) {
      steps(game, 100, 0);
      steps(game, 60, BUTTON_RIGHT);
      steps(game, 93, BUTTON_LEFT);
      game.Step(0);
    } else {
      for (int i = 0; i < 9000 && game.State() == GameState::LEVEL; i++) {
        game.Step(0);
      }
    }
    if (game.State() == GameState::READY_PLAYER) {
      game.Step(0);
      game.Step(BUTTON_A);
    }
  }
}

static Game titleGame(unsigned int level, uint32_t score) {
  Game game(level, score);
  game.SetScreenSize(screen);
  return game;
}

static void finishGameOver(Game &game) {
  steps(game, 70, 0);
  tap(game, BUTTON_A);
}

static void titleScreens() {
  Game game = titleGame(1, 0);
  expect(game.State() == GameState::TITLE, "a new game opens on the title");
  steps(game, 199, 0);
  expect(game.State() == GameState::TITLE, "the title stays up with no input");
  tap(game, BUTTON_DOWN);
  tap(game, BUTTON_UP);
  expect(game.State() == GameState::TITLE, "only A leaves the title");
  game.Step(BUTTON_A);
  expect(game.State() == GameState::HOW_MANY, "A on the title shows the player-count screen");
  Game held = titleGame(1, 0);
  held.Step(BUTTON_A);
  held.Step(BUTTON_A);
  expect(held.State() == GameState::HOW_MANY, "a held A does not skip the player-count screen too");
}

static void noEntry() {
  Game zero = titleGame(3, 0);
  zero.SkipTitle();
  playToGameOver(zero, 1, false);
  expect(zero.State() == GameState::GAME_OVER, "five deaths end the game (score 0)");
  finishGameOver(zero);
  expect(zero.State() == GameState::TITLE, "a score of 0 skips initials and shows the title");
  expect(!zero.TakeScoresChanged(), "a score of 0 leaves the save alone");
  Game low = titleGame(3, 50);
  low.SkipTitle();
  playToGameOver(low, 1, false);
  finishGameOver(low);
  expect(low.State() == GameState::TITLE && !low.TakeScoresChanged(), "a score equal to the tenth entry skips initials");
}

static void entry() {
  Game game = titleGame(2, 80000);
  game.SkipTitle();
  playToGameOver(game, 1);
  finishGameOver(game);
  expect(game.State() == GameState::NAME_ENTRY && game.EntryPlayer() == 0, "a score that makes the table asks for initials");
  expect(strcmp(game.EntryName(), "A") == 0 && game.EntryCursor() == 0, "the entry starts on the letter A");
  tap(game, BUTTON_DOWN);
  expect(strcmp(game.EntryName(), ".") == 0, "down from A wraps to the last character");
  tap(game, BUTTON_UP);
  expect(strcmp(game.EntryName(), "A") == 0, "up from the last character wraps to A");
  steps(game, 2, BUTTON_UP);
  game.Step(0);
  expect(strcmp(game.EntryName(), "B") == 0, "a held up changes one letter at first");
  game.Step(BUTTON_UP);
  steps(game, 1 + 10 + 3, BUTTON_UP);
  game.Step(0);
  expect(game.EntryName()[0] > 'C', "a held up repeats");
  tap(game, BUTTON_LEFT);
  expect(strcmp(game.EntryName(), "A") == 0 && game.EntryCursor() == 0, "left on the first letter resets it to A");
  tap(game, BUTTON_UP);
  tap(game, BUTTON_RIGHT);
  tap(game, BUTTON_UP);
  tap(game, BUTTON_UP);
  tap(game, BUTTON_RIGHT);
  expect(strcmp(game.EntryName(), "BCA") == 0 && game.EntryCursor() == 2, "right accepts a letter and starts the next on A");
  tap(game, BUTTON_LEFT);
  expect(strcmp(game.EntryName(), "BC") == 0 && game.EntryCursor() == 1, "left deletes the last letter");
  for (int i = 0; i < 10; i++) {
    tap(game, BUTTON_RIGHT);
  }
  expect(game.EntryCursor() == 6 && strlen(game.EntryName()) == 7, "the name stops at 7 letters");
  uint32_t score = game.Snapshot().score;
  tap(game, BUTTON_A);
  expect(game.State() == GameState::TITLE, "A finishes the entry and shows the title");
  expect(game.TakeScoresChanged(), "a finished entry changes the table");
  expect(!game.TakeScoresChanged(), "the change is reported once");
  const HighScores &t = game.Scores();
  expect(score > 70000 && score < 110000 && named(t, 2, score, "BCAAAAA") && named(t, 1, 110000, "MARTS") &&
             named(t, 3, 70000, "CRYSTAL"),
         "the name lands at the right rank");
  game.Step(BUTTON_A);
  expect(game.State() == GameState::HOW_MANY, "A on the title after an entry starts a new game");
}

static void twoPlayers() {
  Game game = titleGame(2, 80000);
  game.SkipTitle();
  playToGameOver(game, 2);
  expect(game.State() == GameState::GAME_OVER, "two players run out of lives");
  finishGameOver(game);
  expect(game.State() == GameState::NAME_ENTRY && game.EntryPlayer() == 0, "player 1 enters first");
  tap(game, BUTTON_A);
  expect(game.State() == GameState::NAME_ENTRY && game.EntryPlayer() == 1, "player 2 enters next");
  tap(game, BUTTON_UP);
  tap(game, BUTTON_A);
  expect(game.State() == GameState::TITLE, "the title follows the last entry");
  const HighScores &t = game.Scores();
  expect(strcmp(t.At(2).name, "A") == 0 && strcmp(t.At(3).name, "B") == 0 && t.At(2).score == t.At(3).score &&
             strcmp(t.At(4).name, "CRYSTAL") == 0,
         "equal scores rank player 1 above player 2");
}

int main() {
  tableRules();
  saveRoundTrip();
  corruptSaves();
  titleScreens();
  noEntry();
  entry();
  twoPlayers();
  if (failures == 0) {
    puts("high_score_test: ok");
  }
  return failures == 0 ? 0 : 1;
}

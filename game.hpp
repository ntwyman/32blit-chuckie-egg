// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2009-2011 Paul Brook
// 32Blit port Copyright (C) 2020-2026 ntwyman

#pragma once
#include "32blit.hpp"
#ifdef CHUCKIE_PARITY
#include "tools/parity/trace.h"
#endif
#include <cstdint>

enum GameState {HOW_MANY, READY_PLAYER, LEVEL, GAME_OVER};

#define ROWS 25
#define COLUMNS 20
#define TILE_STRIDE 8
#define X_OFFSET 80

#define TILE_WALL 0x01u
#define TILE_LADDER 0x02u
#define TILE_EGG 0x04u
#define TILE_GRAIN 0x08u

#define MAX_DUCKS 5
#define MAX_PLAYERS 4
#define NUM_EGGS 12

/*** Game interface.  */
#define BUTTON_RIGHT 0x01u
#define BUTTON_LEFT 0x02u
#define BUTTON_DOWN 0x04u
#define BUTTON_UP 0x08u
#define BUTTON_A 0x10u
#define BUTTONS_ALL (BUTTON_RIGHT | BUTTON_LEFT | BUTTON_DOWN | BUTTON_UP | BUTTON_A)

// Offset into tile to get on ladder
#define LADDER_PARTIAL_X 3

/* Direction bitflags  */
#define DIR_L 1
#define DIR_R 2
#define DIR_UP 4
#define DIR_DOWN 8
#define DIR_HORIZ (DIR_R | DIR_L)
#define DIR_VERT (DIR_UP | DIR_DOWN)

enum HenryState { WALK, CLIMB, JUMP, FALL, LIFT };

struct Henry {
  blit::Point pos;
  blit::Point tile;
  blit::Point partial;
  blit::Point speed;
  HenryState state;
  HenryState priorState;
  unsigned int dir;
  int falling;
  int sliding;
};

struct Player {
  uint8_t lives;
  uint16_t level;
  uint32_t score;
  uint16_t bonus;
  uint8_t egg[16];
  uint8_t grain[16];
};

// NOTE: EAT1 should never be rendered but is used in the state
// machine for duck eating animation
enum DuckState { BORED, STEP, EAT1, EAT2, EAT3, EAT4 };

struct Duck {
  blit::Point pos;
  blit::Point tile;
  DuckState state;
  unsigned int dir;
};

struct BigDuck {
  blit::Point pos;
  blit::Point dPos;
  unsigned int dir;
  bool frame;
};

class Game {
public:
  explicit Game(unsigned int hudLevel, uint32_t startScore = 0);
  void SetScreenSize(blit::Size &);
  void Render(blit::Surface &);
  void Step(uint8_t buttons);
#ifdef CHUCKIE_PARITY
  FrameTrace Snapshot();
  GameState State() const { return state; }
  void SkipLevel() { skipLevel = true; }
#endif

private:
  unsigned int getTile(int x, int y);
  bool isTileWall(int x, int y);
  inline void setTile(int x, int y, uint8_t tile) {
    tiles[y * COLUMNS + x] = tile;
  }
  inline void addToTile(int x, int y, uint8_t contents) {
    tiles[y * COLUMNS + x] |= contents;
  }

  void startGame();
  void loadLevel();
  void completeLevel();
  bool levelComplete() const;
  void loseLife();
  bool henryDied() const;
  Player &player() { return playerData[currentPlayer]; }
  const Player &player() const { return playerData[currentPlayer]; }
  void renderBackground(blit::Surface &);
  void renderPlayerSlot(blit::Surface &, unsigned int player);
  void renderDucks(blit::Surface &);
  void renderHenry(blit::Surface &);
  void renderLifts(blit::Surface &);
  void renderBigBird(blit::Surface &);
  const blit::Rect &cageSprite() const;
  blit::Point cagePosition();
  void moveHenry();
  void moveBigDuck();
  void moveDucks();
  void moveLifts();
  void detectCollisions();

  bool startJump(Henry &);
  void jumpHenry(Henry &);
  void fallHenry(Henry &);
  void climbHenry(Henry &);
  void walkHenry(Henry &);
  void liftHenry(Henry &);
  void animateHenry(Henry &);

  void addScore(int);
  void reduceBonus();
  void maybeAddExtraLife();
  bool cannotMove(Henry&);
  bool canGrabLadder(Henry&, int16_t);
  bool henryHitLift(Henry&);
  unsigned int frobRandom();


  blit::Point tilePosition(blit::Point &);
  blit::Point tilePosition(int, int);
  blit::Point screenPosition(int, int);
  int upstreamY(int);
#ifdef CHUCKIE_PARITY
  blit::Point upstreamPosition(const blit::Point &);
#endif

  GameState state = GameState::HOW_MANY;
  unsigned int gameOverLock{};

  // Screen
  blit::Size screenSize{};


  // input
  uint8_t buttonsDown{};
  uint8_t rawDown{};
  uint8_t ignored{};
  uint8_t newDown{};

  // Level info
  bool hasLift{};
  uint16_t numGrain{};
  uint16_t numDucks{};
  int liftX{};
  int liftY[2]{};
  uint16_t currentLift{};
  bool hasBigDuck{};

  // state
  bool isDead{};
  bool levelDone{};
  bool skipLevel{};
  bool extraLife{};
  uint16_t startLevel{};
  uint32_t startScore{};
  uint16_t currentLevel{};
  uint8_t numPlayers = 1;
  uint8_t activePlayers{};
  uint8_t currentPlayer{};
  uint8_t eggsLeft{};
  uint8_t duckTimer{};
  uint8_t duckRate{};
  uint8_t pauseDuckBonus{};
  uint8_t randLow{};
  uint8_t currentDuck{};
  uint8_t tiles[ROWS * COLUMNS]{};
  uint16_t timer{};
  uint32_t randHigh{};

  Player playerData[MAX_PLAYERS]{};
  BigDuck bigDuck{};
  Duck ducks[MAX_DUCKS]{};
  Henry henry{};
};

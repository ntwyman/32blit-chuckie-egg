#pragma once
#include "32blit.hpp"
#include <cstdint>

enum GameState {HOW_MANY, READY_PLAYER, LEVEL, GAME_OVER};

// Game frame rate was 3/100ths of a second
#define UPDATE_INTERVAL_MS 60

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

/* extern uint8_t buttons;
extern uint8_t button_ack;
extern int cheat;
extern int skip_frame;
*/

// Offset into tile to get on ladder
#define LADDER_PARTIAL_X 0

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
  uint8_t level;
  uint8_t score[8];
  uint8_t bonus[4];
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
  void SetScreenSize(blit::Size &);
  void Render(blit::Surface &);
  void Tickle(uint32_t);

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
  void renderBackground(blit::Surface &);
  void renderDucks(blit::Surface &);
  void renderHenry(blit::Surface &);
  void renderLifts(blit::Surface &);
  void renderBigBird(blit::Surface &);
  void pollKeys();
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
  bool cannotMove(Henry&);
  bool canGrabLadder(Henry&, int16_t);
  bool henryHitLift(Henry&);
  unsigned int frobRandom();


  blit::Point tilePosition(blit::Point &);
  blit::Point tilePosition(int, int);

  GameState state = GameState::HOW_MANY;

  // Screen
  blit::Size screenSize;


  // Uodate timing
  uint32_t lastTime;

  // input
  uint16_t buttonsDown;
  uint16_t newDown;

  // Level info
  bool hasLift;
  uint16_t numGrain;
  uint16_t numDucks;
  uint16_t liftX;
  uint16_t liftY[2];
  uint16_t currentLift;
  bool hasBigDuck;

  // state
  bool isDead;
  uint8_t currentLevel;
  uint8_t numPlayers = 1;
  uint8_t activePlayers;
  uint8_t currentPlayer;
  uint8_t eggsLeft;
  uint8_t duckTimer;
  uint8_t duckRate;
  uint8_t pauseDuckBonus;
  uint8_t randLow;
  uint8_t currentDuck;
  uint8_t tiles[ROWS * COLUMNS];
  uint16_t timer;
  uint16_t bonus;
  uint32_t score;
  uint32_t randHigh;

  Player playerData[MAX_PLAYERS];
  BigDuck bigDuck;
  Duck ducks[MAX_DUCKS];
  Henry henry;
};

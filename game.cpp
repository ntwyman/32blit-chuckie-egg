#include "game.hpp"
#include "levels.hpp"
#include "sprites.hpp"
#include <cstring>
// #include <iostream>

using namespace blit;

// Gives the top left ofa tile
Point Game::tilePosition(int x, int y) {
    return Point(X_OFFSET + x * TILE_STRIDE, this->screenSize.h - ((y + 1) * TILE_STRIDE));
}

Point Game::tilePosition(Point &tile) {
    return this->tilePosition(tile.x, tile.y);
}

unsigned int Game::getTile(int x, int y) {
    if (x < 0 || x >= COLUMNS || y < 0 || y >= ROWS) {
        return 0;
    }
    return tiles[y * COLUMNS + x];
}

bool Game::isTileWall(int x, int y) {
    return (this->getTile(x, y) & TILE_WALL) != 0;
}


void Game::startGame() {
    this->activePlayers = this->numPlayers;
    for (int i=0; i< this->numPlayers; i++) {
        memset(&this->playerData[i], 0, sizeof(Player));
        this->playerData[i].lives = 5;
    }
    this->currentLevel = 0;
    this->currentPlayer = 0;
    this->state = GameState::READY_PLAYER;
}

void Game::loadLevel() {

    // Clear out the existing tiles
    memset(&this->tiles[0], 0, sizeof(this->tiles));

    Player &player = this->playerData[this->currentPlayer];
    unsigned int levelNumber = player.level;
    this->hasBigDuck = levelNumber > 7;

    unsigned int speed = levelNumber >> 4;
    if (speed > 8) {
        speed = 8;
    }
    this->timer = (9 - speed) * 100;

    // Data for the level
    const uint8_t *p = getLevelData(levelNumber & 7);
    int numWalls = *(p++);
    int numLadders = *(p++);
    this->hasLift = bool(*p++);
    this->numGrain = *(p++);
    this->numDucks = *(p++);

    int x, y;
    while (numWalls--) {
        y = *(p++);       // row
        x = *(p++);       // first column
        int end = *(p++); // last column
        while (x <= end) {
            setTile(x, y, TILE_WALL);
            x++;
        }
    }

    while (numLadders--) {
        x = *(p++);
        y = *(p++);
        int end = *(p++);
        while (y <= end) {
            addToTile(x, y, TILE_LADDER);
            y++;
        }
    }

    if (this->hasLift) {
        this->liftX = X_OFFSET + (*(p++) << 3u);
        this->liftY[0] = 232;
        this->liftY[1] = 142;
    }

    this->eggsLeft = 0;
    for (unsigned int i = 0; i < NUM_EGGS; i++) {
        x = *(p++);
        y = *(p++);
        this->eggsLeft++;
        setTile(x, y, (i << 4u) | TILE_EGG);
        /*    if (player_data->egg[i] == 0) {
              Do_InitTile(x, y, (i << 4) | TILE_EGG);
              eggs_left++;
            }
        */
    }

    for (unsigned int i = 0; i < this->numGrain; i++) {
        x = *(p++);
        y = *(p++);
        setTile(x, y, (i << 4u) | TILE_GRAIN);
        /*        if (player_data->grain[i] == 0) {
                    Do_InitTile(x, y, (i << 4) | TILE_GRAIN);
                }
        */
    }

    for (auto &duck : ducks) {
        duck.tile.x = *(p++);
        duck.tile.y = *(p++);
    }
    this->currentLevel = levelNumber;
    this->duckTimer = 0;
    this->duckRate = levelNumber < 32 ? 8 : 5;
    this->currentDuck = 0;
    this->bigDuck.pos = Point(X_OFFSET + 4, 36);
    this->bigDuck.dPos = Point(0, 0);
    this->bigDuck.frame = false;
    this->bigDuck.dir = 0;

    // First time with the big duck you get a break
    if (levelNumber >> 3u == 1) {
        this->numDucks = 0;
    }
    // Fourth time through the levels you get the full enchilada
    if (levelNumber >= 24) {
        this->numDucks = 5;
    }

    for (int i = 0; i < this->numDucks; i++) {
        auto &duck = this->ducks[i];
        duck.pos = this->tilePosition(duck.tile);
        duck.pos.y -= 12; // Ducks are tall.
        duck.state = BORED;
        duck.dir = DIR_R;
    }

    this->isDead = false;

    auto &h = this->henry;
    h.tile = {7, 2};
    h.pos = tilePosition(this->henry.tile);
    h.partial = {7, 0};
    h.pos.x += 7;
    h.pos.y -= 8;   // Henry is 2 tiles tall
    h.state = HenryState::WALK; // player_mode = PLAYER_WALK
    h.priorState = HenryState::WALK;
    h.dir = DIR_R;
    // this->buttonMask = BUTTONS_ALL;
    debugf("Loaded level %d, Has lift: %s\r\n", this->currentLevel, this->hasLift ? "true" : "false");
    if (this->hasLift) {
        debugf("X: %d, Y0: %d, Y1: %d\r\n", this->liftX, this->liftY[0], this->liftY[1]);
    }

    this->randHigh = 0x767676;
    this->randLow = 0x76;
    int b = currentLevel +1;
    if (b >= 10)
        b = 9;
    this->bonus = b * 1000;
    this->score = 0;
}

static void renderDigit(Surface &s, unsigned int digit, unsigned int x, unsigned int y) {
    s.sprite(SpriteDigits[digit], Point(x + X_OFFSET, y));
}

static void renderNumber(Surface &s, unsigned int number, unsigned int x, unsigned int y) {
    renderDigit(s, number % 10,x, y);
    number /= 10;
    renderDigit(s, number%10,x-5, y);
    x -= 10;
    for(;;) {
        number /= 10;
        if (number == 0)
            break;
        renderDigit(s, number % 10, x, y);
        x -= 5;
    }
}

void Game::renderBackground(Surface &s) {
    // WARNING MAGIC NUMBERS ABOUND
    // Score
    s.sprite(SpriteScore, Point(X_OFFSET, 0));
    s.sprite(SpriteBlank, Point(X_OFFSET + 27 , 0));
    renderNumber(s, this->score, 53,1);

    // Player
    s.sprite(SpritePlayer, Point(X_OFFSET, 12));
    renderDigit(s, this->currentPlayer + 1,27, 13);

    // Level
    s.sprite(SpriteLevel, Point(X_OFFSET + 36, 12));
    renderNumber(s, this->currentLevel + 1, 69, 13);

    // Bonus
    s.sprite(SpriteBonus, Point(X_OFFSET + 78, 12));
    renderNumber(s, this->bonus, 117, 13);
    //s.sprite(SpriteDigits[0], Point(117, 13));

    // Time
    s.sprite(SpriteTime, Point(X_OFFSET + 126, 12));
    renderNumber(s, this->timer, 153, 13);

    // Level deets
    for (int x = 0; x < COLUMNS; x++) {
        for (int y = 0; y < ROWS; y++) {
            const Point &pos = this->tilePosition(x, y);

            uint8_t tile = getTile(x, y);
            if (tile & TILE_WALL) {
                s.sprite(SpriteWall, pos);
            }
            if (tile & TILE_LADDER) {
                s.sprite(SpriteLadder, pos);
            }
            if (tile & TILE_EGG) {
                s.sprite(SpriteEgg, pos);
            }
            if (tile & TILE_GRAIN) {
                s.sprite(SpriteGrain, pos);
            }
        }
    }

    //  Cage
    const Sprite &cageSprite = this->hasBigDuck ? SpriteCageOpen : SpriteCage;
    s.sprite(cageSprite, Point(X_OFFSET, 20));
}

void Game::renderDucks(Surface &s) {

    for (int i = 0; i < this->numDucks; i++) {

        Duck &duck = this->ducks[i];

        Point pos = duck.pos;
        int dir = duck.dir;
        SpriteTransform flip = (dir == DIR_L) ? HORIZONTAL : NONE;
        Sprite sprite = SpriteDuck;

        switch (duck.state) {
            case BORED:
                if (dir & DIR_VERT) { // Going up or down
                    sprite = SpriteDuckUp;
                }
                break;
            case STEP:
                if (dir & DIR_HORIZ) {
                    sprite = SpriteDuckStep;
                } else {
                    sprite = SpriteDuckUpStep;
                }
                break;
            case EAT2:
            case EAT3:
            case EAT4:
                sprite = (duck.state == EAT3) ? SpriteDuckEat2 : SpriteDuckEat;
                if (dir == DIR_L) {
                    pos.x -= 8;
                }
                break;
            default:
                abort();
        }
        s.sprite(sprite, pos, flip);
    }
}

void Game::renderHenry(Surface &s) {

    Henry &h = this->henry;
    SpriteTransform flip = NONE;
    Rect *sequence= nullptr;
    unsigned int spriteIndex = 0;

    if ((h.dir & (DIR_UP | DIR_DOWN)) != 0) { // Not going left or right
        sequence = SpriteHenryClimbs;
        spriteIndex = h.pos.y;
    } else {
        sequence = SpriteHenryWalks;
        spriteIndex = h.pos.x;
        if (h.dir == DIR_L) {
            flip = HORIZONTAL;
        }
    }

    spriteIndex = (spriteIndex >> 1u) & 0x03u; // Change animation every 2 pixels

    if (h.state != CLIMB) {
        if (h.speed.x == 0) {
            spriteIndex = 0;
        }
    } else if (h.speed.y == 0) {
        spriteIndex = 0;
    }
    s.sprite(sequence[spriteIndex], h.pos, flip);
}

void Game::renderLifts(Surface &s) {
    if (this->hasLift) {
        s.sprite(SpriteLift, Point(this->liftX, this->liftY[0]));
        s.sprite(SpriteLift, Point(this->liftX, this->liftY[1]));
    }
}

void Game::renderBigBird(Surface &s) {
    BigDuck &bigBird = this->bigDuck;
    SpriteTransform flip = (bigBird.dir == DIR_L) ? HORIZONTAL : NONE;
    s.sprite(bigBird.frame ? SpriteBigDuckFrame : SpriteBigDuck, bigBird.pos,
             flip);
}

char const *stateToString(HenryState state) {
    char const *pS = nullptr;
    switch (state) {
        case WALK:
            pS = "Walk";
            break;
        case JUMP:
            pS =  "Jump";
            break;
        case CLIMB:
            pS = "Climb";
            break;
        case FALL:
            pS =  "Fall";
            break;
        case LIFT:
            pS = "LIFT";
    }
    return pS;
}
void Game::pollKeys() {

    Henry &h = this->henry;
    if (h.state != h.priorState) {
        debugf("State change: %s\r\n", stateToString(h.state));
        h.priorState = h.state;
    }

    uint16_t down = 0;
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
    uint16_t changed = this->buttonsDown ^ down;
    this->newDown = changed & down;
    this->buttonsDown = down;
}

void Game::moveHenry() {
    Henry &h = this->henry;
    uint16_t down = this->buttonsDown;
    h.speed = {0, 0};
    if (down & BUTTON_RIGHT) {
        h.speed.x++;
    }
    if (down & BUTTON_LEFT) {
        h.speed.x--;
    }
    if (down & BUTTON_DOWN) {
        h.speed.y--;
    }
    if (down & BUTTON_UP) {
        h.speed.y++;
    }
    h.speed.y *= 2;
    switch (h.state) {
        case HenryState::JUMP:
            this->jumpHenry(h);
            break;
        case HenryState::FALL:
            this->fallHenry(h);
            break;
        case HenryState::CLIMB:
            this->climbHenry(h);
            break;
        case HenryState::WALK:
            this->walkHenry(h);
            break;
        case HenryState::LIFT:
            this->liftHenry(h);
            break;
    }
    this->animateHenry(h);
}

bool Game::canGrabLadder(Henry &h, int16_t speedY) {

    int16_t newPartialX  = h.partial.x + h.speed.x;
    if (newPartialX != LADDER_PARTIAL_X) {
        return false;
    }
    if (speedY == 0) {
        return false;
    }
    int16_t newPartialY = h.partial.y + h.speed.y;
    int16_t x = h.tile.x;
    int16_t y = h.tile.y;
    if (speedY > 0) {
        if ((this->getTile(x, y) & TILE_LADDER) == 0) { // Not on a ladder
            if (h.partial.y >=4) {
                // Check in case there's a ladder just above
                if ((this->getTile(x, y + 1) & TILE_LADDER) == 0) {
                    return false;
                }
            }
        }
        h.state = HenryState::CLIMB;
        if (newPartialY & 1) {
            h.speed.y++;
        }
        return true;
    }
    if ((this->getTile(x, y) & TILE_LADDER) == 0) {
        return false;
    }
    if ((this->getTile(x, y-1) & TILE_LADDER) == 0) {
        return false;
    }
    h.state = HenryState::CLIMB;
    if (newPartialY & 1) {
        h.speed.y--;
    }
    return true;
}

bool Game::henryHitLift(Henry &h) {
//        int tmp;
//        int y1;
//        int y2;

        if (!this->hasLift)
            return false;
    return !((this->liftX > h.pos.x) || (this->liftX + 10 < h.pos.x));
/*        ????
        y1 = player_y - 0x11;
        y2 = player_y - 0x13 + move_y;
        tmp = lift_y[0];
        if (tmp > y1 || tmp < y2) {
            tmp = lift_y[1];
            if (tmp != y1)
            {
                if (tmp >= y1)
                    return;
                if (tmp < y2)
                    return;
            }
            if (current_lift == 0)
                tmp++;
        } else {
            if (current_lift != 0)
                tmp++;
        }
        tmp -= y1;
        move_y = tmp + 1;
        player_fall = 0;
        player_mode = PLAYER_LIFT;
    }
*/
}

void Game::jumpHenry(Henry &h) {

    h.speed.x = h.sliding;
    int16_t speedY= h.speed.y;
    int16_t fallRate = h.falling >> 2;
    if (fallRate >= 6)
        fallRate = 6;
    h.speed.y = 2 - fallRate;
    h.falling++;
    if (h.pos.y == 20) { // Top
        h.speed.y = -1;
        h.falling = 10;
    } else if (this->canGrabLadder(h, speedY)) {
        return;
    }

    int16_t newPartialY = h.partial.y + h.speed.y;
    uint8_t x = h.tile.x;
    uint8_t y = h.tile.y;
    if (newPartialY == 0) {
        if (this->isTileWall(x, y-1)) {
            h.state = HenryState::WALK;
        }
    } else if (newPartialY > 0) {
        if (newPartialY == 8 && this->isTileWall(x, y)) {
            h.state = HenryState::WALK;
        }
    } else {
        if (this->isTileWall(x, y-1 )) {
            h.state = HenryState::WALK;
            h.speed.y = -h.partial.y;
        }
    }
    if (this->henryHitLift(h))
        return;

    if (this->cannotMove(h)) {
        h.speed.x = -h.speed.x;
        h.sliding = h.speed.x;
    }

}

void Game::fallHenry(Henry &h) {
    h.falling++;
    int rate = h.falling;
    if (rate < 4) {
        h.speed.x = h.sliding;
        h.speed.y = -1;
    } else {
        h.speed.x = 0;
        rate = h.falling >> 2u;
        if (rate > 3) {
            rate = 3;
        }
        h.speed.y = -(rate + 1);
    }

    // Check what's in the next tile down
    if ((h.speed.y + h.partial.y) <= 0) {
        if (this->isTileWall(h.tile.x, h.tile.y - 1)) {
            h.state = HenryState::WALK;
            h.speed.y = -h.partial.y;
        }
    }
}

bool Game::startJump(Henry &h) {
    if ((this->newDown & BUTTON_A) == 0) {
        return false;
    }
    h.falling = 0;
    h.state = HenryState::JUMP;
    h.sliding = h.speed.x;
    if (h.sliding > 0) {
        h.dir = DIR_R;
    } else if (h.sliding < 0) {
        h.dir = DIR_L;
    }
    this->jumpHenry(h);
    return true;
}

void Game::climbHenry(Henry &h) {
    if (this->startJump(h)) {
        return;
    }
    // Want to get off
    if (h.speed.x != 0 && h.partial.y == 0) {
        if (this->isTileWall(h.tile.x, h.tile.y - 1)) {
            h.speed.y = 0;
            h.state = HenryState::WALK;
        }
    }
    if (h.state != HenryState::WALK) {
        h.speed.x = 0;
        if (h.speed.y != 0 && h.partial.y == 0) {
            Point checkTile = h.tile;
            if (h.speed.y >= 0) {
                checkTile.y += 2;
            } else {
                checkTile.y -= 1;
            }
            if ((this->getTile(checkTile.x, checkTile.y) & TILE_LADDER) == 0) {
                h.speed.y = 0;
            }
        }
    }
    h.dir = h.speed.y >= 0 ? DIR_UP : DIR_DOWN;
}

void Game::walkHenry(Henry &h) {

    if (this->startJump(h)) {
        return;
    }

    if (h.speed.y != 0) { // Trying to climb
        if (h.partial.x == LADDER_PARTIAL_X) {
            int y = h.tile.y + (h.speed.y > 0 ? 2 : -1);
            if (this->getTile(h.tile.x, y) & TILE_LADDER) {
                h.speed.x = 0;
                h.state = HenryState::CLIMB;
                return;
            }
        }
        h.speed.y = 0;
    }

    int newPartialX = h.partial.x + h.speed.x;
    int tileX = h.tile.x;
    if (newPartialX < 0) {
        tileX -= 1;
    } else if (newPartialX >= 8) {
        tileX++;
    }
    if (!this->isTileWall(tileX, h.tile.y - 1) ) {
        if ((newPartialX & 7) < 4) {
            h.sliding = 1;
            h.falling = 1;
        } else {
            h.sliding = -1;
            h.falling = 0;
        }
        h.state = HenryState::FALL;
    }

    if (this->cannotMove(h)) {
        h.speed.x = 0;
    }
    if (h.speed.x > 0) {
        h.dir = DIR_R;
    } else if (h.speed.x < 0) {
        h.dir = DIR_L;
    }
}

void Game::liftHenry(Henry &h) {
    if (this->startJump(h)) {
        return;
    }
}


void Game::moveLifts() {
    if (!this->hasLift)
        return;
    uint16_t y = this->liftY[this->currentLift];
    y -= 2;
    if (y == 20)
        y = 232;
    this->liftY[this->currentLift] = y;
    this->currentLift  = 1 - this->currentLift;
}

void Game::moveBigDuck() {

    this->duckTimer = 0;
    if (!this->hasBigDuck) {
        return;
    }
    BigDuck& bd = this->bigDuck;
    Henry& h = this->henry;
    if (bd.pos.x + 4 < h.pos.x) {
        if (bd.dPos.x < 5)
            bd.dPos.x++;
        bd.dir = DIR_R;
    } else {
        if (bd.dPos.x > -5)
            bd.dPos.x--;
        bd.dir = DIR_L;
    }

    if (h.pos.y - 4 <= bd.pos.y) {
        if (bd.dPos.y > -5)
            bd.dPos.y --;
    } else {
        if (bd.dPos.y < 5)
            bd.dPos.y ++;
    }
    // Don't go off the bottom of the screen
    if ((bd.pos.y + bd.dPos.y ) > 200) {
        bd.dPos.y = -bd.dPos.y;
    }
    int16_t newX = bd.pos.x + bd.dPos.x;
    if (newX < X_OFFSET || newX >= (X_OFFSET + 144)) {
        bd.dPos.x = - bd.dPos.x;
    }
    bd.pos.x += bd.dPos.x;
    bd.pos.y += bd.dPos.y;
    bd.frame = !bd.frame;
}

static int popcount(unsigned int val) {
    return __builtin_popcount(val);
}

unsigned int Game::frobRandom(){
    int carry = (((this->randLow & 0x48) + 0x38) & 0x40) != 0;
    this->randHigh = (this->randHigh << 1) | carry;
    this->randLow = (this->randLow << 1) | ((this->randHigh >> 24) & 1);
    return this->randLow;
}

void Game::moveDucks() {

    this->duckTimer++;
    if (this->duckTimer == 4) {
        if (this->pauseDuckBonus != 0) {
            this->pauseDuckBonus--;
            return;
        }
        this->timer--;
        if (this->timer == 0) {
            this->isDead = true;
        } else if ((this->timer % 5) == 0) {
            this->reduceBonus();
        }
        return;
    }

    if (this->duckTimer == 8) {
        this->moveBigDuck();
    }

    if (this->currentDuck == 0)
        this->currentDuck = this->duckRate;
    else
        this->currentDuck--;
    if (this->currentDuck >= this->numDucks) {
        return;
    }

    auto &thisDuck = this->ducks[this->currentDuck];
    if (thisDuck.state >= DuckState::EAT1) { // nom nom nom
        if (thisDuck.state == DuckState::EAT2) {
            int x = thisDuck.tile.x - 1;
            int y = thisDuck.tile.y;
            if (thisDuck.dir == DIR_R) {
                x += 2;
            }
            unsigned int tile = this->getTile(x, y);
            if ((tile & TILE_GRAIN) != 0) {
                this->playerData[this->currentPlayer].grain[tile >> 4]--;
                setTile(x, y, tile & ~TILE_GRAIN);
            }
        }
    } else if (thisDuck.state == DuckState::BORED) {
        /* Figure out which way to go next.  */
        int x = thisDuck.tile.x;
        int y = thisDuck.tile.y;
        unsigned int newDir = 0;
        if ((this->getTile(x - 1, y - 1) & TILE_WALL) != 0)
            newDir = DIR_L;
        if ((this->getTile(x + 1, y - 1) & TILE_WALL) != 0)
            newDir |= DIR_R;
        if ((this->getTile(x, y - 1) & TILE_LADDER) != 0)
            newDir |= DIR_DOWN;
        if ((this->getTile(x, y + 2) & TILE_LADDER) != 0)
            newDir |= DIR_UP;
        if (popcount(newDir) != 1) { // Choices
            unsigned int options = thisDuck.dir;
            if ((options & DIR_HORIZ) != 0) { // was going along
                options ^= 0xfc;
            } else {
                options ^= 0xf3;
            }
            newDir &= options;
            options = newDir;
            while (popcount(newDir) != 1) { // Still choices
                newDir = this->frobRandom() & options;
            }
        }
        thisDuck.dir = newDir;
        if (newDir & DIR_HORIZ) {
            if (newDir == DIR_L)
                x -= 1;
            else
                x += 1;
            if ((this->getTile(x, y) & TILE_GRAIN) != 0) {
                thisDuck.state = DuckState::EAT1;
            }
        }
    }

    int walkTile = -1;
    switch (thisDuck.state) {
        case DuckState::STEP:
            thisDuck.state = DuckState::BORED;
            walkTile = 1;
            break;
        case DuckState::BORED:
            thisDuck.state = DuckState::STEP;
            walkTile = 0;
            break;
        case DuckState::EAT1:
            thisDuck.state = DuckState::EAT2;
            break;
        case DuckState::EAT2:
            thisDuck.state = DuckState::EAT3;
            break;
        case DuckState::EAT3:
            thisDuck.state = DuckState::EAT4;
            break;
        case DuckState::EAT4:
            thisDuck.state = DuckState::BORED;
            break;
    }
    if (walkTile < 0) {
        return;
    }
    switch (thisDuck.dir) {
        case DIR_L:
            thisDuck.pos.x -= 4;
            thisDuck.tile.x -= walkTile;
            break;
        case DIR_R:
            thisDuck.pos.x += 4;
            thisDuck.tile.x += walkTile;
            break;
        case DIR_UP:
            thisDuck.pos.y -= 4;
            thisDuck.tile.y += walkTile;
            break;
        case DIR_DOWN:
            thisDuck.pos.y += 4;
            thisDuck.tile.y -= walkTile;
            break;
        default:
            abort();
    }
}

void Game::animateHenry(Henry &h) {

    h.pos.x += h.speed.x;
    int16_t newPartialX = h.partial.x + h.speed.x;
    if (newPartialX < 0) {
        h.tile.x--;
    } else if (newPartialX >= 8) {
        h.tile.x++;
    }
    h.partial.x = newPartialX & 7;
    h.pos.y -= h.speed.y; // Screen pos has inverted y/
    int16_t newPartialY = h.partial.y + h.speed.y;
    if (newPartialY < 0) {
        h.tile.y--;
    } else if (newPartialY >= 8) {
        h.tile.y++;
    }
    h.partial.y = newPartialY & 7;

    uint16_t x = h.tile.x;
    uint16_t y = h.tile.y;
    if (h.partial.y >= 4) {
        y++;
    }

    uint8_t tile = this->getTile(x, y);
    if ((tile & (TILE_EGG | TILE_GRAIN)) == 0)
        return;
    Player &player = this->playerData[this->currentPlayer];
    if ((tile & TILE_GRAIN) == 0) {
        this->eggsLeft--;
        debugf("Eggs left: %d\r\n", this->eggsLeft);
        uint8_t eggIndex = tile >> 4;
        //        squidge(6);
        player.egg[eggIndex]--;
        this->setTile(x, y, 0);
        uint16_t score = (this->currentLevel / 4) + 1;
        if (score >= 10) {
            score = 10;
        }
        this->addScore( score * 100);
    } else {
        //        squidge(5);
        uint8_t grainIndex = tile >> 4;
        player.grain[grainIndex]--;
        this->setTile(x, y, 0);
        this->addScore(50);
        this->pauseDuckBonus = 14;
    }
}

bool Game::cannotMove(Henry &h) {
    if (h.speed.x == 0) {
        return false;
    }
    if (h.speed.x < 0) {
        if (h.pos.x <= X_OFFSET+ 2) {
            return true;
        }
        if (h.partial.x >= 2 || h.speed.y == 2) {
            return false;
        }
        uint16_t x = h.tile.x - 1;
        uint16_t y = h.tile.y;
        int16_t partialY = h.partial.y + h.speed.y;
        if (partialY < 0) {
            y--;
        } else if (partialY >= 8) {
            y++;
        }
        if (this->isTileWall(x, y)) {
            return true;
        }
        if (h.speed.y >= 0) {
            return false;
        }
        x = h.tile.x - 1;
        y++;
        return this->isTileWall(x, y);
    }
    if (h.pos.x >= X_OFFSET + 152) {
        return true;
    }
    if (h.partial.x < 5) {
        return false;
    }
    if (h.speed.y == 2) {
        return false;
    }
    uint16_t x = h.tile.x + 1;
    uint16_t y = h.tile.y;
    int16_t partialY = h.partial.y + h.speed.y;
    if (partialY < 0) {
        y--;
    } else if (partialY >= 8) {
        y++;
    }
    if (this->isTileWall(x, y)) {
        return true;
    }
    if (h.speed.y > 0) {
        return false;
    }
    x = h.tile.x + 1;
    y++;
    return this->isTileWall(x, y);
}

void Game::detectCollisions() {
    /* Little ducks */
    for (int n = 0; n < this->numDucks; n++) {
        if ((unsigned)((this->ducks[n].pos.x - this->henry.pos.x) + 5) < 0x0b
            && (unsigned)((this->ducks[n].pos.y - 1) - this->henry.pos.y + 0xe) < 0x1d)
            this->isDead = true;
    }
    /* Big duck */
    if (!this->hasBigDuck)
        return;
    if ((unsigned)(this->bigDuck.pos.x - this->henry.pos.x + 9) >= 0x0b)
        return;
    if ((unsigned)(this->bigDuck.pos.y - this->henry.pos.y + 9) >= 0x1d)
        return;
    this->isDead = true;

}

void Game::addScore(int n) {
    auto oldScore = this->score;
    this->score += n;
}

void Game::reduceBonus() {
    if (this->bonus > 0) {
        this->bonus-=10;
    }
}
void Game::SetScreenSize(blit::Size &size) {
    this->screenSize = size;
}

void Game::Tickle(uint32_t time)
/*
The Update tick - runs roughly every 10 ms
*/
{

    if (this->lastTime == 0) {
        this->lastTime = time;
    }
    if ((time - this->lastTime) < UPDATE_INTERVAL_MS) {
        return;
    }

    this->pollKeys();
    switch (this->state) {
        case GameState::HOW_MANY:
            if ((this->newDown & BUTTON_UP) && (this->numPlayers < MAX_PLAYERS)) {
                this->numPlayers ++;
            } else if ((this->newDown & BUTTON_DOWN) && (this->numPlayers > 1)) {
                this->numPlayers --;
            }
            if (this->newDown & BUTTON_A) {
                debugf("Starting Game\r\n");
                this->startGame();
            }
            break;
        case GameState::READY_PLAYER:
            if (this->newDown & BUTTON_A) {
                this->loadLevel();
                this->state = GameState::LEVEL;
            }
            break;
        case GameState::GAME_OVER:
            if (this->newDown & BUTTON_A) {

                
            }
            break;
        case GameState::LEVEL:
            this->moveHenry();
            this->moveLifts();
            this->moveDucks();
            this->detectCollisions();

            if (this->henry.pos.y > 229 || this->isDead) { // DED
                this->state = GameState::GAME_OVER;
                break;
            }
            if (this->eggsLeft == 0) {
                while (this->bonus > 0) {
                    this->reduceBonus();
                    this->addScore(10);
                }
            }
            break;
        }
        //        /* Level complete */
//        while (!zero_bonus) {
//            AddScore(6, 1);
//            ReduceBonus();
//            MaybeAddExtraLife();
//            tmp = timer_ticks[3];
//            if (tmp == 0 || tmp == 5) {
//                /* sound(0xcb0) - 0010 0001 0004 0001 */
//            }
//            /* Render Screen? */
//        }
//        /* Advance to next level */
//        cheat = 0;
//        zero_bonus = 0;
//        current_level++;
//        SavePlayerState();
//        ResetPlayer();
//        RestorePlayerState();
//        goto next_level;
//
    }

void Game::Render(Surface &s) {
    /*
     Render callback is roughly every 25 ms
    */

    s.pen = Pen(255,255,255);
    char buf[0x20];
    switch (this->state) {
        case GameState::HOW_MANY:
            sprintf(buf, "How many players? %d", this->numPlayers);
            s.text(buf, minimal_font, Point(5, 4));
            break;
        case GameState::READY_PLAYER:
            sprintf(buf, "Ready Player? %d", this->currentPlayer + 1);
            s.text(buf, minimal_font, Point(5, 4));
            break;
        case GameState::LEVEL:
            this->renderBackground(s);
            this->renderDucks(s);
            this->renderHenry(s);
            this->renderLifts(s);
            this->renderBigBird(s);
            break;
        case GameState::GAME_OVER:
            sprintf(buf, "Game Over Player %d", this->currentPlayer + 1);
            s.text(buf, minimal_font, Point(5, 4));
    }
}

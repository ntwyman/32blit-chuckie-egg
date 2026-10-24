// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2009-2011 Paul Brook
// 32Blit port Copyright (C) 2020-2026 ntwyman
// The sprite data comes from spritedata.c in Paul Brook's Chuckie Egg.

#include <cstdint>
#include "32blit.hpp"
#include "sprites.hpp"

// Position of sprites in the Sheet. Expressed in 8x8 pixel strides
const Sprite& SpriteEgg = Sprite(9,2,1,1);
const Sprite& SpriteWall = Sprite(9,0,1,1);
const Sprite& SpriteLadder = Sprite(9,1,1,1);
const Sprite& SpriteGrain = Sprite(9,3,1,1);
const Sprite& SpriteScore = Sprite(4,7,3,2);
const Sprite& SpriteBlank = Sprite(4,10,4,2);
const Sprite& SpritePlayer = Sprite(0,10,4,2);
const Sprite& SpriteLevel = Sprite(0,12,5,2);
const Sprite& SpriteBonus = Sprite(5,12,6,2);
const Sprite& SpriteTime = Sprite(0,14,4,2);
const Sprite& SpriteCage = Sprite(0,0,3,6);
const Sprite& SpriteCageOpen = Sprite(3,0,3,6);
const Sprite& SpriteDuck = Sprite(8,0,1,3);
const Sprite& SpriteDuckStep = Sprite(8,3,1,3);
const Sprite& SpriteDuckUp = Sprite(10,0,1,3);
const Sprite& SpriteDuckUpStep = Sprite(10,3,1,3);
const Sprite& SpriteDuckEat = Sprite(7,6,2,3);
const Sprite& SpriteDuckEat2 = Sprite(9,6,2,3);
const Sprite& SpriteLift = Sprite(4,6,2,1);
const Sprite& SpriteBigDuck = Sprite(0,6,2,3);
const Sprite& SpriteBigDuckFrame = Sprite(2,6,2,3);

Sprite SpriteDigits[] = {
    {0, 9, 1, 1},
    {1, 9, 1, 1},
    {2, 9, 1, 1},
    {3, 9, 1, 1},
    {4, 9, 1, 1},
    {5, 9, 1, 1},
    {6, 9, 1, 1},
    {7, 9, 1, 1},
    {8, 9, 1, 1},
    {9, 9, 1, 1}
};

Sprite SpriteHenryWalks[] = {
    { 6, 0, 1, 2},
    { 6, 2, 1, 2},
    { 6, 0, 1, 2},
    { 6, 4, 1, 2}
};
Sprite SpriteHenryClimbs[] = {
    { 7, 0, 1, 2},
    { 7, 2, 1, 2},
    { 7, 0, 1, 2},
    { 7, 4, 1, 2}
};

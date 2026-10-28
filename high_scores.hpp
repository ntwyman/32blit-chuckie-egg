// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

#pragma once
#include <cstddef>
#include <cstdint>

constexpr int HS_ENTRIES = 10;
constexpr int HS_NAME_LEN = 7;
constexpr size_t HS_SAVE_SIZE = 4 + 2 + HS_ENTRIES * (4 + HS_NAME_LEN + 1) + 4;

struct ScoreEntry {
  uint32_t score;
  char name[HS_NAME_LEN + 1];
};

// The top ten scores. It holds no engine code, so a host test can use it. The save is 130 bytes: the magic
// "CHKE", a version byte, a zero byte, ten entries of a little-endian score and eight name bytes, and an
// FNV-1a checksum of everything before it.
class HighScores {
public:
  HighScores() { Reset(); }
  void Reset();
  // A score of 0 never qualifies. A score equal to the tenth entry does not either, because ties go below.
  bool Qualifies(uint32_t score) const;
  // Where Insert would put the score, from 0, or -1 when it does not qualify.
  int RankFor(uint32_t score) const;
  // Returns the rank the score took, or -1. The name is cut to 7 characters.
  int Insert(uint32_t score, const char *name);
  const ScoreEntry &At(int rank) const { return entries[rank]; }
  static bool ValidChar(char c);
  void Encode(uint8_t *out) const;
  // Returns false and resets to the default table when the data is not a valid save.
  bool Decode(const uint8_t *in, size_t size);

private:
  ScoreEntry entries[HS_ENTRIES];
};

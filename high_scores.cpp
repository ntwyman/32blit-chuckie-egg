// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

#include "high_scores.hpp"
#include <cstring>

namespace {
constexpr uint8_t MAGIC[4] = {'C', 'H', 'K', 'E'};
constexpr uint8_t VERSION = 1;
constexpr uint32_t SCORE_MAX = 99999999;

const ScoreEntry DEFAULTS[HS_ENTRIES] = {
    {325000, "NIK"},    {110000, "MARTS"},  {70000, "CRYSTAL"}, {60000, "SOFT"},    {50000, "EGG-THE"},
    {40000, "UPGRADE"}, {30000, "SAE FOR"}, {20000, "RELEASE"}, {10000, "DETAILS"}, {50, "A&F"},
};

uint32_t checksum(const uint8_t *data, size_t size) {
  uint32_t hash = 2166136261u;
  for (size_t i = 0; i < size; i++) {
    hash = (hash ^ data[i]) * 16777619u;
  }
  return hash;
}

void put32(uint8_t *out, uint32_t v) {
  for (int i = 0; i < 4; i++) {
    out[i] = (uint8_t)(v >> (8 * i));
  }
}

uint32_t get32(const uint8_t *in) {
  return in[0] | (uint32_t)in[1] << 8 | (uint32_t)in[2] << 16 | (uint32_t)in[3] << 24;
}
}

void HighScores::Reset() {
  memcpy(entries, DEFAULTS, sizeof(entries));
}

bool HighScores::ValidChar(char c) {
  return (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == ' ' || c == '-' || c == '&' || c == '.';
}

bool HighScores::Qualifies(uint32_t score) const {
  return score > 0 && score > entries[HS_ENTRIES - 1].score;
}

int HighScores::RankFor(uint32_t score) const {
  if (!Qualifies(score)) {
    return -1;
  }
  int rank = 0;
  while (entries[rank].score >= score) {
    rank++;
  }
  return rank;
}

int HighScores::Insert(uint32_t score, const char *name) {
  int rank = RankFor(score);
  if (rank < 0) {
    return -1;
  }
  for (int i = HS_ENTRIES - 1; i > rank; i--) {
    entries[i] = entries[i - 1];
  }
  ScoreEntry &e = entries[rank];
  e.score = score;
  memset(e.name, 0, sizeof(e.name));
  int n = 0;
  for (; n < HS_NAME_LEN && name[n] != '\0'; n++) {
    e.name[n] = ValidChar(name[n]) ? name[n] : '?';
  }
  while (n > 0 && e.name[n - 1] == ' ') {
    e.name[--n] = '\0';
  }
  if (n == 0) {
    strcpy(e.name, "ANON");
  }
  return rank;
}

void HighScores::Encode(uint8_t *out) const {
  memset(out, 0, HS_SAVE_SIZE);
  memcpy(out, MAGIC, 4);
  out[4] = VERSION;
  uint8_t *p = out + 6;
  for (const ScoreEntry &e : entries) {
    put32(p, e.score);
    memcpy(p + 4, e.name, HS_NAME_LEN + 1);
    p += 4 + HS_NAME_LEN + 1;
  }
  put32(p, checksum(out, HS_SAVE_SIZE - 4));
}

bool HighScores::Decode(const uint8_t *in, size_t size) {
  ScoreEntry parsed[HS_ENTRIES];
  bool ok = size >= HS_SAVE_SIZE && memcmp(in, MAGIC, 4) == 0 && in[4] == VERSION && in[5] == 0 &&
            get32(in + HS_SAVE_SIZE - 4) == checksum(in, HS_SAVE_SIZE - 4);
  const uint8_t *p = in + 6;
  for (int i = 0; ok && i < HS_ENTRIES; i++, p += 4 + HS_NAME_LEN + 1) {
    parsed[i].score = get32(p);
    memcpy(parsed[i].name, p + 4, HS_NAME_LEN + 1);
    const char *end = (const char *)memchr(parsed[i].name, '\0', HS_NAME_LEN + 1);
    size_t len = end ? (size_t)(end - parsed[i].name) : HS_NAME_LEN + 1;
    ok = parsed[i].score <= SCORE_MAX && len > 0 && len <= (size_t)HS_NAME_LEN &&
         (i == 0 || parsed[i].score <= parsed[i - 1].score);
    for (size_t c = 0; ok && c < len; c++) {
      ok = ValidChar(parsed[i].name[c]);
    }
    for (size_t c = len; ok && c <= (size_t)HS_NAME_LEN; c++) {
      ok = parsed[i].name[c] == '\0';
    }
  }
  if (!ok) {
    Reset();
    return false;
  }
  memcpy(entries, parsed, sizeof(entries));
  return true;
}

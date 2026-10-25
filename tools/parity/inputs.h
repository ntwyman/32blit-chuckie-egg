// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

// Reads a parity input script into one button byte per frame. Both drivers
// use it, so they see the same frames. The format is in tools/parity/README.md.

#ifndef CHUCKIE_PARITY_INPUTS_H
#define CHUCKIE_PARITY_INPUTS_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define INPUTS_MAX_LEVEL 256
#define INPUTS_MAX_FRAMES 1000000

typedef struct {
  int level;
  size_t count;
  uint8_t *buttons;
} Inputs;

static inline void inputs_fail(const char *path, int line, const char *what, const char *text) {
  fprintf(stderr, "%s:%d: %s '%s'\n", path, line, what, text);
  exit(2);
}

// Parses a whole number from 1 to max, or returns 0.
static inline long inputs_number(const char *text, long max) {
  char *end;
  long n;
  if (text[0] < '0' || text[0] > '9') {
    return 0;
  }
  n = strtol(text, &end, 10);
  if (*end != '\0' || n < 1 || n > max) {
    return 0;
  }
  return n;
}

static inline int inputs_key(const char *name) {
  static const char *const names[] = {"right", "left", "down", "up", "jump"};
  for (int i = 0; i < 5; i++) {
    if (strcmp(name, names[i]) == 0) {
      return 1 << i;
    }
  }
  return -1;
}

// Parses '-' or keys joined with '+', such as 'left+jump'.
static inline int inputs_buttons(char *keys) {
  int buttons = 0;
  if (strcmp(keys, "-") == 0) {
    return 0;
  }
  for (char *key = strtok(keys, "+"); key != NULL; key = strtok(NULL, "+")) {
    int bit = inputs_key(key);
    if (bit < 0) {
      return -1;
    }
    buttons |= bit;
  }
  return buttons;
}

static inline Inputs inputs_read(const char *path) {
  Inputs in = {1, 0, NULL};
  size_t capacity = 0;
  int line_no = 0;
  int steps = 0;
  char line[256];
  FILE *f = fopen(path, "r");
  if (f == NULL) {
    fprintf(stderr, "%s: cannot open\n", path);
    exit(2);
  }
  while (fgets(line, sizeof line, f) != NULL) {
    char *word[3] = {NULL, NULL, NULL};
    int words = 0;
    char *hash = strchr(line, '#');
    line_no++;
    if (hash != NULL) {
      *hash = '\0';
    }
    for (char *w = strtok(line, " \t\r\n"); w != NULL; w = strtok(NULL, " \t\r\n")) {
      if (words == 2) {
        inputs_fail(path, line_no, "expected '<frames> <keys>' or 'level <n>', got extra word", w);
      }
      word[words++] = w;
    }
    if (words == 0) {
      continue;
    }
    if (strcmp(word[0], "level") == 0) {
      long level = words == 2 ? inputs_number(word[1], INPUTS_MAX_LEVEL) : 0;
      if (steps > 0) {
        inputs_fail(path, line_no, "the level line must come before every frame line", word[0]);
      }
      if (level == 0) {
        inputs_fail(path, line_no, "expected 'level <n>' with n from 1 to 256, got", words == 2 ? word[1] : "");
      }
      in.level = (int)level;
      steps++;
      continue;
    }
    long frames = inputs_number(word[0], INPUTS_MAX_FRAMES);
    int buttons = words == 2 ? inputs_buttons(word[1]) : 0;
    if (frames == 0) {
      inputs_fail(path, line_no, "expected a frame count from 1 to 1000000, got", word[0]);
    }
    if (buttons < 0) {
      inputs_fail(path, line_no, "expected '-' or keys from right, left, down, up, jump joined by '+', got", word[1]);
    }
    if (in.count + (size_t)frames > INPUTS_MAX_FRAMES) {
      inputs_fail(path, line_no, "the script runs past 1000000 frames at", word[0]);
    }
    if (in.count + (size_t)frames > capacity) {
      capacity = (in.count + (size_t)frames) * 2;
      in.buttons = (uint8_t *)realloc(in.buttons, capacity);
      if (in.buttons == NULL) {
        fprintf(stderr, "%s: out of memory\n", path);
        exit(2);
      }
    }
    memset(in.buttons + in.count, buttons, (size_t)frames);
    in.count += (size_t)frames;
    steps++;
  }
  fclose(f);
  if (in.count == 0) {
    fprintf(stderr, "%s: no frames\n", path);
    exit(2);
  }
  return in;
}

// Parses the arguments '[--level <n>] <script>' that both drivers take.
// --level overrides the script's level line. Returns the index of the first
// argument after them.
static inline Inputs inputs_from_args(int argc, char **argv, const char *usage, int *next) {
  int i = 1;
  long level = 0;
  Inputs in;
  if (i + 1 < argc && strcmp(argv[i], "--level") == 0) {
    level = inputs_number(argv[i + 1], INPUTS_MAX_LEVEL);
    if (level == 0) {
      fprintf(stderr, "--level must be a whole number from 1 to 256, got '%s'\n", argv[i + 1]);
      exit(2);
    }
    i += 2;
  }
  if (i >= argc || argv[i][0] == '-') {
    fprintf(stderr, "usage: %s\n", usage);
    exit(2);
  }
  in = inputs_read(argv[i]);
  if (level != 0) {
    in.level = (int)level;
  }
  *next = i + 1;
  return in;
}

#endif

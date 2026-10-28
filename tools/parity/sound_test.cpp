// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2020-2026 ntwyman

// The trace diff sees a sound's note and period, not what Game does with 32Blit's channels. This drives Game and
// checks the channels: the beep's pitch, envelope and trigger, the noise's pitch, hold and release, and that the
// noise ends by itself when no Step releases it.

#include "game.hpp"
#include "engine/api_private.hpp"

#include <cmath>
#include <cstdio>

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

using blit::ADSRPhase;
using blit::AudioChannel;
using blit::Waveform;

static int failures = 0;

static const ADSRPhase MARKER = ADSRPhase::DECAY;

static void silence() {
  blit::channels[0].off();
  blit::channels[1].off();
}

static void expect(bool ok, const char *what, int a = 0, int b = 0) {
  if (!ok) {
    fprintf(stderr, "sound_test: %s (%d, %d)\n", what, a, b);
    failures++;
  }
}

static const int UPSTREAM_HOLD_STEPS = 6;
static const int WALK_NOTE = 64;
static const int WALK_HZ = 259;
static const int EGG_NOISE_HZ = 1696;
static const int GRAIN_NOISE_HZ = 3392;
static const int NOISE_RELEASE_MS = 20;
static const int AUDIO_RATE = 22050;

static int expectedBeepHz(int period) {
  return static_cast<int>(std::lround(44100.0 / (2.0 * (period + 1))));
}

static int expectedNoiseHz(int period) {
  return static_cast<int>(std::lround(44100.0 / (period + 1)));
}

static void checkConfig() {
  Game game(1, 0);
  game.SkipTitle();
  game.InitAudio();
  const AudioChannel &beep = blit::channels[0];
  const AudioChannel &noise = blit::channels[1];
  expect(beep.waveforms == Waveform::SQUARE, "the beep is a square wave on channel 0");
  expect(beep.volume == 0xbfff, "the beep volume", beep.volume);
  expect(beep.attack_ms == 1 && beep.decay_ms == 19 && beep.sustain == 0, "the beep envelope", beep.attack_ms, beep.decay_ms);
  double area = beep.volume / 65535.0 * (beep.attack_ms + beep.decay_ms) / 2.0;
  expect(std::fabs(area - 7.5) < 0.01, "the beep envelope area matches upstream's 7.5", static_cast<int>(area * 1000));
  expect(noise.waveforms == Waveform::NOISE, "the noise is a noise wave on channel 1");
  expect(noise.volume == 0xe80c, "the noise volume", noise.volume);
  expect(noise.attack_ms == 10 && noise.decay_ms == 2000 && noise.sustain == 0, "the noise envelope", noise.attack_ms, noise.decay_ms);
  expect(noise.release_ms == NOISE_RELEASE_MS, "the noise release", noise.release_ms);
  double hold = 0;
  int samples = 0;
  for (double ms = 10; ms < 190; ms += 0.05, samples++) {
    double level = 1.0 - (ms - 10) / noise.decay_ms;
    hold += level * level;
  }
  double rms = 16910.0 * noise.volume / 65536.0 * std::sqrt(hold / samples);
  expect(std::fabs(rms - 14644.0) < 100.0, "the noise rms over the hold is 14,644", static_cast<int>(rms));
}

static void enter(Game &game) {
  blit::Size screen(320, 240);
  game.SetScreenSize(screen);
  game.InitAudio();
  game.Step(BUTTON_A);
  game.Step(0);
  game.Step(BUTTON_A);
}

struct Counts {
  int beeps = 0;
  int noises = 0;
  int walkBeeps = 0;
  int eggs = 0;
  int grains = 0;
  int holds = 0;
};

static void play(Counts &counts, uint8_t direction, int jumpEvery) {
  AudioChannel &beep = blit::channels[0];
  AudioChannel &noise = blit::channels[1];
  silence();
  Game game(1, 0);
  game.SkipTitle();
  enter(game);
  silence();
  int sinceNoise = -1;
  for (int step = 0; step < 220; step++) {
    beep.adsr_phase = ADSRPhase::OFF;
    noise.adsr_phase = MARKER;
    uint8_t buttons = direction;
    if (jumpEvery && step % jumpEvery == 5) {
      buttons |= BUTTON_A;
    }
    game.Step(buttons);
    FrameTrace t = game.Snapshot();
    if (game.BeepNote() != NO_NOTE) {
      counts.beeps++;
      expect(beep.adsr_phase == ADSRPhase::ATTACK, "a beep triggers the channel", step);
      expect(beep.frequency == expectedBeepHz(t.beep_period), "the beep pitch", beep.frequency, expectedBeepHz(t.beep_period));
      if (game.BeepNote() == WALK_NOTE) {
        counts.walkBeeps++;
        expect(beep.frequency == WALK_HZ, "a walking beep plays 259 Hz", beep.frequency);
      }
    } else {
      expect(beep.adsr_phase == ADSRPhase::OFF, "no note, no trigger", step);
    }
    if (game.NoiseNote() != NO_NOTE) {
      counts.noises++;
      int want = game.NoiseNote() == 6 ? EGG_NOISE_HZ : GRAIN_NOISE_HZ;
      counts.eggs += game.NoiseNote() == 6;
      counts.grains += game.NoiseNote() == 5;
      expect(noise.adsr_phase == ADSRPhase::ATTACK, "a noise triggers the channel", step);
      expect(noise.frequency == want, "the noise pitch", noise.frequency, want);
      expect(noise.frequency == expectedNoiseHz(t.noise_period), "the noise pitch follows its period", noise.frequency);
      sinceNoise = 0;
    } else if (sinceNoise >= 0) {
      sinceNoise++;
      if (sinceNoise < UPSTREAM_HOLD_STEPS) {
        expect(noise.adsr_phase == MARKER, "the noise is held", sinceNoise);
      } else if (sinceNoise == UPSTREAM_HOLD_STEPS) {
        counts.holds++;
        expect(noise.adsr_phase == ADSRPhase::RELEASE, "the noise is released after six steps", sinceNoise);
      } else {
        expect(noise.adsr_phase == MARKER, "the noise is not released again", sinceNoise);
      }
    }
  }
}

// A hidden browser tab stops the main loop, so no Step releases the noise. The mixer alone must end it.
static void checkEndsWithoutStep() {
  AudioChannel &noise = blit::channels[1];
  silence();
  Game game(1, 0);
  game.SkipTitle();
  enter(game);
  silence();
  for (int step = 0; step < 220 && noise.adsr_phase == ADSRPhase::OFF; step++) {
    game.Step(BUTTON_RIGHT);
  }
  expect(noise.adsr_phase == ADSRPhase::ATTACK, "the walk takes a grain or egg");
  blit::AudioChannel copy = noise;
  noise.frequency = copy.frequency;
  noise.trigger_attack();
  for (int frame = 0; frame < AUDIO_RATE * 5 / 2; frame++) {
    blit::get_audio_frame();
  }
  expect(noise.adsr_phase == ADSRPhase::OFF, "a noise nothing releases ends within 2.5 s", static_cast<int>(noise.adsr_phase));
}

int main() {
  checkConfig();
  Counts counts;
  play(counts, BUTTON_RIGHT, 0);
  play(counts, BUTTON_LEFT, 0);
  play(counts, BUTTON_RIGHT, 30);
  expect(counts.beeps > 20 && counts.walkBeeps > 10, "the walks beep", counts.beeps, counts.walkBeeps);
  expect(counts.noises >= 2 && counts.holds >= 1, "the walks take items", counts.noises, counts.holds);
  expect(counts.eggs >= 1 && counts.grains >= 1, "an egg and a grain both sound", counts.eggs, counts.grains);
  checkEndsWithoutStep();
  if (failures == 0) {
    printf("sound_test: ok (%d beeps, %d noises)\n", counts.beeps, counts.noises);
  }
  return failures == 0 ? 0 : 1;
}

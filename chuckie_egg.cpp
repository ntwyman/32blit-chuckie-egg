#include "32blit.hpp"
#include "game.hpp"
#include "assets.hpp"

using namespace blit;
uint32_t last_frame = 0;
Game game;

void init() {
  set_screen_mode(ScreenMode::hires);
  game.SetScreenSize(screen.bounds);
  screen.sprites = Surface::load(asset_sprites);
}

void update(uint32_t time) { game.Tickle(time); }

void render(uint32_t time) {
  screen.pen = Pen(0, 0, 0);
  screen.clear();
  game.Render(screen);
}

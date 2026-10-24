# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2009-2011 Paul Brook
# 32Blit port Copyright (C) 2020-2026 ntwyman
cmake_minimum_required(VERSION 3.9)

project(chuckie-egg)

set(PROJECT_SOURCE
  chuckie_egg.cpp
  game.cpp game.hpp
  levels.cpp levels.hpp
  sprites.cpp sprites.hpp
)

# Files shipped in the release archive
set(PROJECT_DISTRIBS LICENSE README.md)

# Build configuration; approach this with caution!
if(MSVC)
  add_compile_options("/W4" "/wd4244" "/wd4324" "/wd4458" "/wd4100")
else()
  add_compile_options("-Wall" "-Wextra" "-Wdouble-promotion" "-Wno-unused-parameter")
endif()

find_package (32BLIT CONFIG REQUIRED PATHS ../32blit-sdk $ENV{PATH_32BLIT_SDK})

blit_executable (${PROJECT_NAME} ${PROJECT_SOURCE})
blit_assets_yaml (${PROJECT_NAME} assets.yml)
blit_metadata (${PROJECT_NAME} metadata.yml)

# The SDK's web shell uses FS and IDBFS from its preRun, but newer Emscripten
# strips them as unused unless exported; without this the page hangs on load.
# (Overrides the SDK's EXPORTED_RUNTIME_METHODS, so its entries are repeated.)
if(EMSCRIPTEN)
  target_link_options(${PROJECT_NAME} PRIVATE
    "-sEXPORTED_RUNTIME_METHODS=['addRunDependency','removeRunDependency','FS','IDBFS']")
endif()
add_custom_target (flash DEPENDS ${PROJECT_NAME}.flash)

# setup release packages
install (FILES ${PROJECT_DISTRIBS} DESTINATION .)
set (CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
set (CPACK_GENERATOR "ZIP" "TGZ")
include (CPack)

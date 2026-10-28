# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2009-2011 Paul Brook
# 32Blit port Copyright (C) 2020-2026 ntwyman
cmake_minimum_required(VERSION 3.9)

project(chuckie-egg)

set(PROJECT_SOURCE
  chuckie_egg.cpp
  frame_clock.hpp
  game.cpp game.hpp
  levels.cpp levels.hpp
  sprites.cpp sprites.hpp
)

set(PROJECT_DISTRIBS LICENSE README.md)

# Build configuration; approach this with caution!
if(MSVC)
  add_compile_options("/W4" "/wd4244" "/wd4324" "/wd4458" "/wd4100")
else()
  add_compile_options("-Wall" "-Wextra" "-Wdouble-promotion" "-Wno-unused-parameter")
endif()

find_package (32BLIT CONFIG REQUIRED PATHS ../32blit-sdk $ENV{PATH_32BLIT_SDK})

set(CHUCKIE_START_LEVEL 1 CACHE STRING "The level a new game starts on, as the HUD numbers it, from 1 to 256")
if(NOT CHUCKIE_START_LEVEL MATCHES "^[1-9][0-9]*$" OR CHUCKIE_START_LEVEL GREATER 256)
  message(FATAL_ERROR "CHUCKIE_START_LEVEL must be a whole number from 1 to 256, got '${CHUCKIE_START_LEVEL}'")
endif()
if(NOT CHUCKIE_START_LEVEL EQUAL 1)
  message(STATUS "A new game starts on level ${CHUCKIE_START_LEVEL} (CHUCKIE_START_LEVEL)")
endif()

set(CHUCKIE_START_SCORE 0 CACHE STRING "The score a new game starts with, from 0 to 99999999")
string(LENGTH "${CHUCKIE_START_SCORE}" CHUCKIE_START_SCORE_LENGTH)
if(NOT CHUCKIE_START_SCORE MATCHES "^(0|[1-9][0-9]*)$" OR CHUCKIE_START_SCORE_LENGTH GREATER 8)
  message(FATAL_ERROR "CHUCKIE_START_SCORE must be a whole number from 0 to 99999999, got '${CHUCKIE_START_SCORE}'")
endif()
if(NOT CHUCKIE_START_SCORE EQUAL 0)
  message(STATUS "A new game starts with score ${CHUCKIE_START_SCORE} (CHUCKIE_START_SCORE)")
endif()

blit_executable (${PROJECT_NAME} ${PROJECT_SOURCE})
blit_assets_yaml (${PROJECT_NAME} assets.yml)
blit_metadata (${PROJECT_NAME} metadata.yml)
target_compile_definitions(${PROJECT_NAME} PRIVATE CHUCKIE_START_LEVEL=${CHUCKIE_START_LEVEL} CHUCKIE_START_SCORE=${CHUCKIE_START_SCORE})

option(CHUCKIE_PARITY "Build the host-only trace diff drivers in tools/parity" OFF)
if(CHUCKIE_PARITY)
  if(CMAKE_CROSSCOMPILING OR EMSCRIPTEN)
    message(FATAL_ERROR "CHUCKIE_PARITY builds host tools; turn it off for device and web builds")
  endif()
  if(NOT CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    message(FATAL_ERROR "CHUCKIE_PARITY needs GCC or Clang, bash, and patch")
  endif()

  set(UPSTREAM ${CMAKE_CURRENT_SOURCE_DIR}/third_party/pbrook-chuckie-egg)
  set(PARITY ${CMAKE_CURRENT_SOURCE_DIR}/tools/parity)
  set(PARITY_GEN ${CMAKE_CURRENT_BINARY_DIR}/parity)
  file(GLOB PARITY_PATCHES CONFIGURE_DEPENDS ${PARITY}/patches/*.patch)
  list(SORT PARITY_PATCHES)

  add_executable(parity-port ${PARITY}/port_driver.cpp game.cpp levels.cpp sprites.cpp)
  target_include_directories(parity-port PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${PARITY})
  target_compile_definitions(parity-port PRIVATE CHUCKIE_PARITY)
  target_link_libraries(parity-port BlitEngine)

  add_custom_command(
    OUTPUT ${PARITY_GEN}/chuckie.c
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PARITY_GEN}
    COMMAND ${PARITY}/apply-patches.sh ${UPSTREAM}/chuckie.c ${PARITY_GEN}/chuckie.c ${PARITY_PATCHES}
    DEPENDS ${UPSTREAM}/chuckie.c ${PARITY}/apply-patches.sh ${PARITY_PATCHES}
    COMMENT "Applying tools/parity/patches to upstream chuckie.c"
  )
  # Upstream's chuckie.h has no include guard, and the driver includes both chuckie.c and audio.c. Copies in
  # the build folder hold a guarded chuckie.h and an audio.c that finds it, so the driver reads audio.c's own
  # sound_start state. Rewriting chuckie.h only when it changes keeps a second configure from recompiling.
  file(READ ${UPSTREAM}/chuckie.h CHUCKIE_H)
  set(CHUCKIE_H_GUARDED "#pragma once\n${CHUCKIE_H}")
  set(CHUCKIE_H_OLD "")
  if(EXISTS ${PARITY_GEN}/chuckie.h)
    file(READ ${PARITY_GEN}/chuckie.h CHUCKIE_H_OLD)
  endif()
  if(NOT CHUCKIE_H_OLD STREQUAL CHUCKIE_H_GUARDED)
    file(WRITE ${PARITY_GEN}/chuckie.h "${CHUCKIE_H_GUARDED}")
  endif()
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${UPSTREAM}/chuckie.h)
  configure_file(${UPSTREAM}/audio.c ${PARITY_GEN}/audio.c COPYONLY)
  add_executable(parity-original ${PARITY}/original_driver.c ${UPSTREAM}/leveldata.c ${PARITY_GEN}/chuckie.c)
  set_source_files_properties(${PARITY_GEN}/chuckie.c PROPERTIES HEADER_FILE_ONLY ON)
  target_include_directories(parity-original PRIVATE ${PARITY_GEN} ${PARITY} ${UPSTREAM})
  # GCC cannot see that upstream's num_ducks is at most 5 and warns on the
  # duck[] writes in StartLevel. The upstream code stays as it is.
  if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
    target_compile_options(parity-original PRIVATE -Wno-stringop-overflow)
  endif()

  add_executable(parity-gameover ${PARITY}/game_over_test.cpp game.cpp levels.cpp sprites.cpp)
  target_include_directories(parity-gameover PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
  target_compile_definitions(parity-gameover PRIVATE CHUCKIE_PARITY)
  target_link_libraries(parity-gameover BlitEngine)

  add_executable(parity-sound ${PARITY}/sound_test.cpp game.cpp levels.cpp sprites.cpp)
  target_include_directories(parity-sound PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
  target_compile_definitions(parity-sound PRIVATE CHUCKIE_PARITY)
  target_link_libraries(parity-sound BlitEngine)

  add_executable(parity-clock ${PARITY}/clock_test.cpp)
  target_include_directories(parity-clock PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

  add_custom_target(parity DEPENDS parity-port parity-original parity-clock parity-gameover parity-sound)
endif()

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

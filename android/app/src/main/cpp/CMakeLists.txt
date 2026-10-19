cmake_minimum_required(VERSION 3.18)
project(pulsar_needle LANGUAGES CXX)

set(NEEDLE_LIB ${CMAKE_CURRENT_SOURCE_DIR}/needle/${ANDROID_ABI}/libneedle.a)

if(EXISTS ${NEEDLE_LIB})
  # Real on-device engine (Cactus Needle 3 + Whistle), arm64-v8a only.
  add_library(needle_static STATIC IMPORTED)
  set_target_properties(needle_static PROPERTIES IMPORTED_LOCATION ${NEEDLE_LIB})

  add_library(pulsar_needle SHARED pulsar_needle.cpp)
  target_include_directories(pulsar_needle PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/needle)
  target_compile_definitions(pulsar_needle PRIVATE PULSAR_HAS_ENGINE=1)
  # whole-archive keeps every needle_* symbol exported for Dart FFI lookups.
  target_link_libraries(pulsar_needle
    -Wl,--whole-archive needle_static -Wl,--no-whole-archive
    log android m dl)
else()
  # No engine binary for this ABI (e.g. x86_64 emulator): build a stub that
  # reports "unsupported" so the Dart side can fall back gracefully.
  add_library(pulsar_needle SHARED pulsar_needle.cpp)
  target_compile_definitions(pulsar_needle PRIVATE PULSAR_HAS_ENGINE=0)
endif()

// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <app.h>
#include <include/fletch_api.h>
#include <include/static_ffi.h>
#include <endian.h>
#include <kernel/thread.h>
#include <lib/gfx.h>
#include <dev/display.h>

int FFITestMagicMeat(void) { return 0xbeef; }
int FFITestMagicVeg(void) { return 0x1eaf; }

#if WITH_LIB_GFX
/*
 * Simple framebuffer stuff.
 */
gfx_surface* GetFullscreenSurface(void) {
  struct display_info info;
  display_get_info(&info);

  return gfx_create_surface_from_display(&info);
}

int GetWidth(gfx_surface* surface) { return surface->width; }
int GetHeight(gfx_surface* surface) { return surface->height; }
#endif

FLETCH_EXPORT_TABLE_BEGIN
  FLETCH_EXPORT_TABLE_ENTRY("magic_meat", FFITestMagicMeat)
  FLETCH_EXPORT_TABLE_ENTRY("magic_veg", FFITestMagicVeg)
#if WITH_LIB_GFX
  FLETCH_EXPORT_TABLE_ENTRY("gfx_create", GetFullscreenSurface)
  FLETCH_EXPORT_TABLE_ENTRY("gfx_width", GetWidth)
  FLETCH_EXPORT_TABLE_ENTRY("gfx_height", GetHeight)
  FLETCH_EXPORT_TABLE_ENTRY("gfx_destroy", gfx_surface_destroy)
  FLETCH_EXPORT_TABLE_ENTRY("gfx_pixel", gfx_putpixel)
  FLETCH_EXPORT_TABLE_ENTRY("gfx_clear", gfx_clear)
  FLETCH_EXPORT_TABLE_ENTRY("gfx_flush", gfx_flush)
#endif  // WITH_LIB_GFX
FLETCH_EXPORT_TABLE_END

extern __attribute__((weak)) char __fletch_lines_heap_start;
extern __attribute__((weak)) char __fletch_lines_heap_end;
extern __attribute__((weak)) char __fletch_lines_start;

int Run(void* ptr) {
  int* pointer = 0xE000E008;
  *pointer = *pointer | 2;
  printf("Set debugging flag to %d\n", *((int *) 0xE000E008));
  printf("STARTING fletch-vm...\n");
  FletchSetup();
  void* program_heap = &__fletch_lines_heap_start;
  size_t size = ((intptr_t) &__fletch_lines_heap_end) - ((intptr_t) &__fletch_lines_heap_start);
  printf("LOADING PROGRAM AT %p size %d...\n", program_heap, size);
  FletchProgram program = FletchLoadProgramFromFlash(program_heap, size);
  printf("RUNNING program...\n");
  int result = FletchRunMain(program);
  printf("EXIT CODE: %i\n", result);
  printf("TEARING DOWN fletch-vm...\n");
  FletchTearDown();
  return result;
}

#if defined(WITH_LIB_CONSOLE)
#include <lib/console.h>

static int FletchRunner(int argc, const cmd_args* argv) {
  // TODO(ajohnsen): Investigate if we can use the 'shell' thread instead of
  // the Dart main thread. Currently, we get stack overflows (into the kernel)
  // when using the shell thread.
  thread_t* thread = thread_create(
      "Dart main thread", Run, NULL, DEFAULT_PRIORITY,
      4096 /* stack size */);
  thread_resume(thread);

  int retcode;
  thread_join(thread, &retcode, INFINITE_TIME);

  return retcode;
}

STATIC_COMMAND_START
{ "fletch", "fletch vm", &FletchRunner },
STATIC_COMMAND_END(fletchrunner);
#endif

APP_START(fletchrunner)
  .entry = (void *)&Run,
  .flags = APP_FLAG_CUSTOM_STACK_SIZE,
  .stack_size = 8192,
APP_END


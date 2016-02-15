// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <app.h>
#include <include/dartino_api.h>
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

DARTINO_EXPORT_TABLE_BEGIN
  DARTINO_EXPORT_TABLE_ENTRY("magic_meat", FFITestMagicMeat)
  DARTINO_EXPORT_TABLE_ENTRY("magic_veg", FFITestMagicVeg)
#if WITH_LIB_GFX
  DARTINO_EXPORT_TABLE_ENTRY("gfx_create", GetFullscreenSurface)
  DARTINO_EXPORT_TABLE_ENTRY("gfx_width", GetWidth)
  DARTINO_EXPORT_TABLE_ENTRY("gfx_height", GetHeight)
  DARTINO_EXPORT_TABLE_ENTRY("gfx_destroy", gfx_surface_destroy)
  DARTINO_EXPORT_TABLE_ENTRY("gfx_pixel", gfx_putpixel)
  DARTINO_EXPORT_TABLE_ENTRY("gfx_clear", gfx_clear)
  DARTINO_EXPORT_TABLE_ENTRY("gfx_flush", gfx_flush)
#endif  // WITH_LIB_GFX
DARTINO_EXPORT_TABLE_END

extern __attribute__((weak)) char __dartino_lines_heap_start;
extern __attribute__((weak)) char __dartino_lines_heap_end;
extern __attribute__((weak)) char __dartino_lines_start;

int Run(void* ptr) {
  int* pointer = 0xE000E008;
  *pointer = *pointer | 2;
  printf("Set debugging flag to %d\n", *((int *) 0xE000E008));
  printf("STARTING dartino-vm...\n");
  DartinoSetup();
  void* program_heap = &__dartino_lines_heap_start;
  size_t size = ((intptr_t) &__dartino_lines_heap_end) - ((intptr_t) &__dartino_lines_heap_start);
  printf("LOADING PROGRAM AT %p size %d...\n", program_heap, size);
  DartinoProgram program = DartinoLoadProgramFromFlash(program_heap, size);
  printf("RUNNING program...\n");
  int result = DartinoRunMain(program, 0, NULL);
  printf("EXIT CODE: %i\n", result);
  printf("TEARING DOWN dartino-vm...\n");
  DartinoTearDown();
  return result;
}

#if defined(WITH_LIB_CONSOLE)
#include <lib/console.h>

static int DartinoRunner(int argc, const cmd_args* argv) {
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
{ "dartino", "dartino vm", &DartinoRunner },
STATIC_COMMAND_END(dartinorunner);
#endif

APP_START(dartinorunner)
  .entry = (void *)&Run,
  .flags = APP_FLAG_CUSTOM_STACK_SIZE,
  .stack_size = 8192,
APP_END


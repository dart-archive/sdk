// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <app.h>
#include <fletch_api.h>
#include <endian.h>
#include <kernel/thread.h>
#include <lib/gfx.h>
#include <dev/display.h>

typedef struct {
  const char* const name;
  const void* const ptr;
} StaticFFISymbol;

int FFITestMagicMeat() { return 0xbeef; }
int FFITestMagicVeg() { return 0x1eaf; }

#if WITH_LIB_GFX
/*
 * Simple framebuffer stuff.
 */
gfx_surface* GetFullscreenSurface() {
  struct display_info info;
  display_get_info(&info);

  return gfx_create_surface_from_display(&info);
}

int GetWidth(gfx_surface* surface) { return surface->width; }
int GetHeight(gfx_surface* surface) { return surface->height; }

#define LIB_GFX_EXPORTS 7
#else  // WITH_LIB_GFX
#define LIB_GFX_EXPORTS 0
#endif  // WITH_LIB_GFX

StaticFFISymbol table[] = { {"magic_meat", &FFITestMagicMeat},
                            {"magic_veg", &FFITestMagicVeg},
#if WITH_LIB_GFX
                            {"gfx_create", &GetFullscreenSurface},
                            {"gfx_width", &GetWidth},
                            {"gfx_height", &GetHeight},
                            {"gfx_destroy", &gfx_surface_destroy},
                            {"gfx_pixel", &gfx_putpixel},
                            {"gfx_clear", &gfx_clear},
                            {"gfx_flush", &gfx_flush},
#endif  // WITH_LIB_GFX
};

const void* const fletch_ffi_table_start = table;
const void* const fletch_ffi_table_end = table + 2 + LIB_GFX_EXPORTS;

int ReadSnapshot(unsigned char** snapshot) {
  printf("READY TO READ SNAPSHOT DATA.\n");
  printf("STEP1: size.\n");
  char size_buf[10];
  int pos = 0;
  while ((size_buf[pos++] = getchar()) != '\n') {
    putchar(size_buf[pos-1]);
  }
  if (pos > 9) abort();
  size_buf[pos] = 0;
  int size = atoi(size_buf);
  unsigned char* result = malloc(size);
  printf("\nSTEP2: reading snapshot of %d bytes.\n", size);
  int status = 0;
  for (pos = 0; pos < size; pos++, status++) {
    result[pos] = getchar();
    if (status == 1024) {
      putchar('.');
      status = 0;
    }
  }
  printf("\nSNAPSHOT READ.\n");
  *snapshot = result;
  return size;
}

int RunSnapshot(unsigned char* snapshot, int size) {
  printf("STARTING fletch-vm...\n");
  FletchSetup();
  printf("LOADING snapshot...\n");
  FletchProgram program = FletchLoadSnapshot(snapshot, size);
  free(snapshot);
  printf("RUNNING program...\n");
  int result = FletchRunMain(program);
  printf("DELETING program...\n");
  FletchDeleteProgram(program);
  printf("TEARING DOWN fletch-vm...\n");
  printf("EXIT CODE: %i\n", result);
  FletchTearDown();
  return result;
}

#if defined(WITH_LIB_CONSOLE)
#include <lib/console.h>

int Run(void* ptr) {
  unsigned char* snapshot;
  int length = ReadSnapshot(&snapshot);
  return RunSnapshot(snapshot, length);
}

static int FletchRunner(int argc, const cmd_args *argv) {
  // TODO(ajohnsen): Investigate if we can use the 'shell' thread instaed of
  // the Dart main thread. Currently, we get stack overflows (into the kernel)
  // when using the shell thread.
  thread_t* thread = thread_create(
      "Dart main thread", Run, NULL, DEFAULT_PRIORITY,
      8192 /* DEFAULT_STACK_SIZE */);
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
.flags = APP_FLAG_CUSTOM_STACK_SIZE,
.stack_size = 8192,
APP_END


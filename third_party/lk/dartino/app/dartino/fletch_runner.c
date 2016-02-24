// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <string.h>
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

#define LIB_GFX_EXPORTS 7
#else  // WITH_LIB_GFX
#define LIB_GFX_EXPORTS 0
#endif  // WITH_LIB_GFX

#if 1
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

#else
DARTINO_EXPORT_STATIC_RENAME(magic_meat, FFITestMagicMeat);
DARTINO_EXPORT_STATIC_RENAME(magic_veg, FFITestMagicVeg);
#ifdef WITH_LIB_GFX
DARTINO_EXPORT_STATIC_RENAME(gfx_create, GetFullscreenSurface);
DARTINO_EXPORT_STATIC_RENAME(gfx_width, GetWidth);
DARTINO_EXPORT_STATIC_RENAME(gfx_height, GetHeight);
DARTINO_EXPORT_STATIC_RENAME(gfx_destroy, gfx_surface_destroy);
DARTINO_EXPORT_STATIC_RENAME(gfx_pixel, gfx_putpixel);
DARTINO_EXPORT_STATIC(gfx_clear);
DARTINO_EXPORT_STATIC(gfx_flush);
#endif
#endif

#ifndef LOADER_BUFFER_SIZE
#define LOADER_BUFFER_SIZE 256
#endif

// static buffer to hold snapshot/heap
static unsigned char buffer[LOADER_BUFFER_SIZE * 1024]
    __attribute__((aligned(4096)));

int ReadBlob(void) {
  printf("READY TO READ DATA.\n");
  printf("STEP1: size.\n");
  char size_buf[10];
  int pos = 0;
  while ((size_buf[pos++] = getchar()) != '\n') {
    putchar(size_buf[pos-1]);
  }
  if (pos > 9) abort();
  size_buf[pos] = 0;
  int size = atoi(size_buf);
  if (size < 0 || (unsigned int) size > sizeof(buffer)) abort();
  printf("\nSTEP2: reading blob of %d bytes.\n", size);
  int status = 0;
  for (pos = 0; pos < size; pos++, status++) {
    buffer[pos] = getchar();
    if (status == 1024) {
      putchar('.');
      status = 0;
    }
  }
  printf("\nSNAPSHOT READ.\n");
  return size;
}

void PrintArgs(unsigned char* buffer);

int RunHeap(int size) {
  printf("STARTING dartino-vm...\n");
  DartinoSetup();
  printf("LOADING program heap...\n");
  DartinoProgram program = DartinoLoadProgramFromFlash(buffer, size);
  printf("RUNNING program...\n");
  int result = DartinoRunMain(program, 0, NULL);
  printf("TEARING DOWN dartino-vm...\n");
  printf("EXIT CODE: %i\n", result);
  DartinoTearDown();
  return result;
}

int RunSnapshot(int size) {
  printf("STARTING dartino-vm...\n");
  DartinoSetup();
  printf("LOADING snapshot...\n");
  DartinoProgram program = DartinoLoadSnapshot(buffer, size);
  printf("RUNNING program...\n");
  int result = DartinoRunMain(program, 0, NULL);
  printf("DELETING program...\n");
  DartinoDeleteProgram(program);
  printf("TEARING DOWN dartino-vm...\n");
  printf("EXIT CODE: %i\n", result);
  DartinoTearDown();
  return result;
}

#if defined(WITH_LIB_CONSOLE)
#include <lib/console.h>

int RunInThread(int (runner)(int), int size) {
  thread_t* thread = thread_create(
      "Dart main thread", (thread_start_routine) runner, (void*) size,
      DEFAULT_PRIORITY, 8 * 1024 /* stack size */);
  thread_resume(thread);

  int retcode;
  thread_join(thread, &retcode, INFINITE_TIME);

  return retcode;
}

static int DartinoRunner(int argc, const cmd_args *argv) {
  if (argc == 2) {
    if (strcmp(argv[1].str, "getinfo") == 0) {
      PrintArgs(buffer);
      return 0;
    } else if (strcmp(argv[1].str, "heap") == 0) {
      int size = ReadBlob();
      return RunInThread(RunHeap, size);
    } else if (strcmp(argv[1].str, "snapshot") == 0) {
      int size = ReadBlob();
      return RunInThread(RunSnapshot, size);
    }
  }
  printf("Illegal arguments to %s. Expected\n\n", argv[0].str);
  printf("  getinfo    : Print commandline arguments to flashtool\n");
  printf("  heap       : Load and run a program heap\n");
  printf("  snapshot   : Load and run a snapshot\n");
  return -1;
}


STATIC_COMMAND_START
STATIC_COMMAND("dartino", "dartino vm", &DartinoRunner)
STATIC_COMMAND_END(dartinorunner);
#endif

APP_START(dartinorunner)
.flags = APP_FLAG_CUSTOM_STACK_SIZE,
APP_END

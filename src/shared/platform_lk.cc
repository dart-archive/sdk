// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_LK)

// We do not include platform_posix.h on purpose. That file
// should never be directly inported. platform.h is always
// the platform header to include.
#include "src/shared/platform.h"  // NOLINT

#include <platform.h>

#include <err.h>
#include <kernel/thread.h>
#include <kernel/semaphore.h>
#include <lib/page_alloc.h>
#include <sys/types.h>

#include <stdlib.h>
#include <stdio.h>

#include "src/shared/utils.h"

namespace dartino {

void GetPathOfExecutable(char* path, size_t path_length) {
  // We are built into the kernel ...
  path[0] = '\0';
}

static uint64 time_launch;

void Platform::Setup() { time_launch = GetMicroseconds(); }

void Platform::TearDown() { }

uint64 Platform::GetMicroseconds() {
  lk_bigtime_t time = current_time_hires();
  return time;
}

uint64 Platform::GetProcessMicroseconds() {
  // Assume now is past time_launch.
  return GetMicroseconds() - time_launch;
}

int Platform::GetNumberOfHardwareThreads() {
  // TODO(herhut): Find a way to get number of hardware threads.
  return 1;
}

// Load file at 'uri'.
List<uint8> Platform::LoadFile(const char* name) {
#ifdef WITH_LIB_FFS
  // Open the file.
  FILE* file = fopen(name, "rb");
  if (file == NULL) {
    printf("ERROR: Cannot open %s\n", name);
    return List<uint8>();
  }

  // Determine the size of the file.
  if (fseek(file, 0, SEEK_END) != 0) {
    printf("ERROR: Cannot seek in file %s\n", name);
    fclose(file);
    return List<uint8>();
  }
  int size = ftell(file);
  fseek(file, 0, SEEK_SET);

  // Read in the entire file.
  uint8* buffer = static_cast<uint8*>(malloc(size));
  int result = fread(buffer, 1, size, file);
  fclose(file);
  if (result != size) {
    printf("ERROR: Unable to read entire file %s\n", name);
    return List<uint8>();
  }
  return List<uint8>(buffer, size);
#else
  printf("ERROR: OS has no filesystem support.");
  return List<uint8>();
#endif
}

bool Platform::StoreFile(const char* uri, List<uint8> bytes) {
#ifdef WITH_LIB_FFS
  // Open the file.
  FILE* file = fopen(uri, "wb");
  if (file == NULL) {
    printf("ERROR: Cannot open %s\n", uri);
    return false;
  }

  int result = fwrite(bytes.data(), 1, bytes.length(), file);
  fclose(file);
  if (result != bytes.length()) {
    printf("ERROR: Unable to write entire file %s\n", uri);
    return false;
  }

  return true;
#else
  printf("ERROR: OS has no filesystem support.");
  return false;
#endif
}

bool Platform::WriteText(const char* uri, const char* text, bool append) {
#ifdef WITH_LIB_FFS
  // Open the file.
  FILE* file = fopen(uri, append ? "a" : "w");
  if (file == NULL) {
    // TODO(wibling): Does it make sense to write an error here? It seems it
    // could go into a loop if it fails to open the log file and we then write
    // again.
    return false;
  }
  int len = strlen(text);
  int result = fwrite(text, 1, len, file);
  fclose(file);
  if (result != len) {
    // TODO(wibling): Same as above.
    return false;
  }

  return true;
#else
  printf("ERROR: OS has no filesystem support.");
  return false;
#endif
}

const char* Platform::GetTimeZoneName(int64_t seconds_since_epoch) {
  // Unsupported. Return an empty string like V8 does.
  return "";
}

int Platform::GetTimeZoneOffset(int64_t seconds_since_epoch) {
  // Unsupported. Return zero like V8 does.
  return 0;
}

int Platform::GetLocalTimeZoneOffset() {
  // Unsupported.
  return 0;
}

// Do nothing for errno handling for now.
int Platform::GetLastError() { return 0; }
void Platform::SetLastError(int value) { }

VirtualMemory::VirtualMemory(int size) : size_(size) {}

VirtualMemory::~VirtualMemory() {}

void Platform::Exit(int exit_code) {
  printf("Exited with code %d.\n", exit_code);
  while (true) {
  }
}

void Platform::ScheduleAbort() {
  printf("Aborted (scheduled)\n");
  while (true) {
  }
}

void Platform::ImmediateAbort() {
  printf("Aborted (immediate)\n");
  while (true) {
  }
}

int Platform::GetPid() {
  // For now just returning 0 here.
  return 0;
}

#ifdef DEBUG
void Platform::WaitForDebugger() { UNIMPLEMENTED(); }
#endif

int Platform::FormatString(char* buffer, size_t length, const char* format,
                           ...) {
  UNIMPLEMENTED();
  return 0;
}

char* Platform::GetEnv(const char* name) { return NULL; }

int Platform::MaxStackSizeInWords() { return 16 * KB; }

void* Platform::AllocatePages(uword size, int arenas) {
  size = Utils::RoundUp(size, PAGE_SIZE);
  void* memory = page_alloc(size >> PAGE_SIZE_SHIFT, arenas);
  return memory;
}

void Platform::FreePages(void* address, uword size) {
  page_free(address, size >> PAGE_SIZE_SHIFT);
}

int Platform::GetHeapMemoryRanges(HeapMemoryRange* ranges,
                                  int number_of_ranges) {
  const int kRanges = 4;
  struct page_range page_ranges[kRanges];
  int arena_count = page_get_arenas(page_ranges, kRanges);
  ASSERT(arena_count < kRanges);
  int i;
  for (i = 0; i < number_of_ranges && i < arena_count; i++) {
    ranges[i].address = page_ranges[i].address;
    ranges[i].size = page_ranges[i].size;
  }
  return i;
}

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_LK)

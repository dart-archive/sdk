// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <cmsis_os.h>
#include <FreeRTOS.h>
#include <task.h>

#include "src/shared/assert.h"

#include "platforms/stm/disco_dartino/src/cmpctmalloc.h"
#include "platforms/stm/disco_dartino/src/dartino_entry.h"
#include "platforms/stm/disco_dartino/src/page_alloc.h"
#include "platforms/stm/disco_dartino/src/page_allocator.h"

extern "C" int InitializeBoard();

// This object is initialized during EarlyInit.
PageAllocator* page_allocator;

#define MAX_STACK_SIZE 0x2000

// Wrapping of the static initialization to configure the C/C++ heap
// first.
void EarlyInit();
extern "C" void __real___libc_init_array();
extern "C" void __wrap___libc_init_array() {
  EarlyInit();
  __real___libc_init_array();
}

// Wrapping of all malloc/free calls in newlib. This should cause the
// newlib malloc to never be used, and sbrk should never be called for
// memory.
extern "C" void *__wrap__malloc_r(struct _reent *reent, size_t size) {
  return pvPortMalloc(size);
}

extern "C" void *suspendingRealloc(void *ptr, size_t size);

extern "C" void *__wrap__realloc_r(
    struct _reent *reent, void *ptr, size_t size) {
  return suspendingRealloc(ptr, size);
}

extern "C" void *__wrap__calloc_r(
    struct _reent *reent, size_t nmemb, size_t size) {
  if (nmemb == 0 || size == 0) return NULL;
  size = nmemb * size;
  void* ptr = pvPortMalloc(size);
  memset(ptr, 0, size);
  return ptr;
}

extern "C" void __wrap__free_r(struct _reent *reent, void *ptr) {
  vPortFree(ptr);
}

// Early initialization before static initialization. This will
// configure the C/C++ heap.
void EarlyInit() {
  // Get the free location in system RAM just after the bss segment.
  extern char end asm("end");
  uintptr_t heap_start = reinterpret_cast<uintptr_t>(&end);

  // Reserve a map for 72 pages (256k + 16k + 16k) in .bss.
  const size_t kDefaultPageMapSize = 72;
  static uint8_t default_page_map[kDefaultPageMapSize];
  // Allocate a PageAllocator in system RAM.
  page_allocator = reinterpret_cast<PageAllocator*>(heap_start);
  page_allocator->Initialize();
  heap_start += sizeof(PageAllocator);
  // Use the NVIC offset register to locate the main stack pointer.
  uintptr_t min_stack_ptr =
      (uintptr_t) (*(unsigned int*) *(unsigned int*) 0xE000ED08);
  // Locate the stack bottom address.
  min_stack_ptr -= MAX_STACK_SIZE;
  // Add the system RAM as the initial arena.
  uint32_t arena_id = page_allocator->AddArena(
      "System RAM", heap_start, min_stack_ptr - heap_start,
      default_page_map, kDefaultPageMapSize);
  ASSERT(arena_id == 1);

  // Initialize the compact C/C++ heap implementation.
  cmpct_init();
}

extern "C" int add_page_arena(char* name, uintptr_t start, size_t size) {
  return page_allocator->AddArena(name, start, size);
}

extern "C" void* page_alloc(size_t pages, int arenas) {
  return page_allocator->AllocatePages(pages, arenas);
}

extern "C" void page_free(void* start, size_t pages) {
  return page_allocator->FreePages(start, pages);
}

extern "C" int get_arena_locations(memory_range_t *ranges_return, int ranges) {
  return page_allocator->GetArenas(ranges_return, ranges);
}

extern "C" size_t get_pages_for_bytes(size_t bytes) {
  return page_allocator->PagesForBytes(bytes);
}

int main() {
  // Initialize the board.
  InitializeBoard();

  // Create the main task.
  osThreadDef(mainTask, DartinoEntry, osPriorityNormal, 0, 1024);
  osThreadId mainTaskHandle = osThreadCreate(osThread(mainTask), NULL);
  USE(mainTaskHandle);

  // Start the scheduler.
  osKernelStart();

  // We should never get as the scheduler should never terminate.
  FATAL("Returned from scheduler");
}

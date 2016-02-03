// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <cinttypes>

#define TESTING
#include "src/shared/assert.h"

#include "platforms/stm/disco_dartino/src/cmpctmalloc.h"
#include "platforms/stm/disco_dartino/src/page_allocator.h"

PageAllocator* page_allocator;

extern "C" void* page_alloc(size_t pages) {
  return page_allocator->AllocatePages(pages);
}

extern "C" void page_free(void* start, size_t pages) {
  return page_allocator->FreePages(start, pages);
}

// Tests in cmpctmalloc.c.
extern "C" void cmpct_test_buckets();
extern "C" void cmpct_test_get_back_newly_freed();
extern "C" void cmpct_test_return_to_os();
extern "C" void cmpct_test_trim();

int main(int argc, char **argv) {
  page_allocator = new PageAllocator();

  // Test that nothing can be allocated in the empty page allocator.
  void *p = cmpct_alloc(1);
  EXPECT(p == NULL);

  // Add an arena to the heap for the rest of the tests.
  size_t heap_size = 60 * PAGE_SIZE;  // TODO(sgjesse): Test with few pages.
  heap_size = 0x800000;
  void* heap_memory;
  int result = posix_memalign(&heap_memory, PAGE_SIZE, heap_size);
  EXPECT_EQ(0, result);
  int arena1_bitmap = page_allocator->AddArena(
      "test", reinterpret_cast<uintptr_t>(heap_memory), heap_size);
  EXPECT_EQ(1, arena1_bitmap);

  cmpct_test_buckets();
#ifdef DARTINO_TARGET_OS_LK
  // TODO(sgjesse): This test crashes.
  cmpct_test_get_back_newly_freed();
#endif
  cmpct_test_return_to_os();
  cmpct_test_trim();
  cmpct_dump();
}

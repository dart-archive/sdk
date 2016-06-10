// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <cinttypes>

#define TESTING
#include "src/shared/assert.h"
#include "src/shared/atomic.h"

#include "src/freertos/page_allocator.h"

void Test() {
  PageAllocator *allocator = new PageAllocator();
  void* arena1;
  int rc = posix_memalign(&arena1, PAGE_SIZE, 10);
  EXPECT_EQ(0, rc);
  uintptr_t start = reinterpret_cast<uintptr_t>(arena1);
  int arena1_bit = allocator->AddArena("test", start, PAGE_SIZE * 10);
  EXPECT_EQ(1, arena1_bit);

  void* allocated[9];
  for (int i = 0; i < 9; i++) {
    void* result = allocator->AllocatePages(1);
    allocated[i] = result;
    EXPECT_EQ(start + (i + 1) * PAGE_SIZE, reinterpret_cast<uintptr_t>(result));
  }
  EXPECT_EQ(reinterpret_cast<void*>(NULL), allocator->AllocatePages(1));
  for (int i = 0; i < 9; i++) {
    allocator->FreePages(allocated[i], 1);
    void* result = allocator->AllocatePages(1);
    EXPECT_EQ(allocated[i], result);
    EXPECT_EQ(reinterpret_cast<void*>(NULL), allocator->AllocatePages(1));
  }
  for (int i = 0; i < 9; i++) {
    allocator->FreePages(allocated[i], 1);
  }
  EXPECT_EQ(reinterpret_cast<void*>(NULL), allocator->AllocatePages(10));
  for (int i = 0; i < 5; i++) {
    void* result = allocator->AllocatePages(9);
    EXPECT_EQ(start + PAGE_SIZE, reinterpret_cast<uintptr_t>(result));
    allocator->FreePages(result, 9);
  }

  free(arena1);
}

void TestExternalMap() {
  const int kMapSize = 10;

  // Allocate memory for an arena.
  void* arena;
  int rc = posix_memalign(&arena, PAGE_SIZE, kMapSize);
  EXPECT_EQ(0, rc);
  uintptr_t start = reinterpret_cast<uintptr_t>(arena);

  uint8_t map[kMapSize + 1];
  memset(map, 0xaa, kMapSize + 1);

  void* page;
  PageAllocator *allocator;
  allocator = new PageAllocator();
  allocator->AddArena("test", start, PAGE_SIZE * kMapSize, map, kMapSize);
  page = allocator->AllocatePages(1);
  EXPECT_EQ(arena, page);
  // This tests that the implementation actually uses the external
  // map. However the way the implementation uses the external map is
  // *not* part if the API contract, and if the implementation is
  // changed this test should be as well.
  EXPECT_EQ(1, map[0]);
  EXPECT_EQ(0, map[1]);
  allocator->FreePages(page, 1);
  EXPECT_EQ(0, map[0]);
  EXPECT_EQ(0, map[1]);

  page = allocator->AllocatePages(kMapSize);
  EXPECT_EQ(arena, page);
  for (int i = 0; i < kMapSize; i++) {
    EXPECT_EQ(1, map[i]);
  }
  EXPECT_EQ(0xaa, map[kMapSize]);

  allocator = new PageAllocator();
  allocator->AddArena("test", start, PAGE_SIZE * kMapSize, map, kMapSize - 1);

  memset(map, 0xaa, kMapSize + 1);
  page = allocator->AllocatePages(1);
  EXPECT_EQ(reinterpret_cast<uint8_t*>(arena) + PAGE_SIZE, page);
  for (int i = 0; i < kMapSize + 1; i++) {
    EXPECT_EQ(0xaa, map[i]);
  }
  allocator->FreePages(page, 1);
  page = allocator->AllocatePages(kMapSize);
  EXPECT(page == NULL);
  for (int i = 0; i < kMapSize + 1; i++) {
    EXPECT_EQ(0xaa, map[i]);
  }

  free(arena);
}

int main(int argc, char** argv) {
  Test();
  TestExternalMap();
}

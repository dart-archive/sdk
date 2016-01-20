// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <cinttypes>

#define TESTING
#include "src/shared/assert.h"
#include "src/shared/atomic.h"

#include "platforms/stm/disco_fletch/src/page_allocator.h"

void test() {
  PageAllocator *allocator = new PageAllocator();
  void* arena1;
  int rc = posix_memalign(&arena1, PAGE_SIZE, 10);
  EXPECT_EQ(0, rc);
  uintptr_t start = reinterpret_cast<uintptr_t>(arena1);
  int arena1_bitmap = allocator->AddArena("test", start, PAGE_SIZE * 10);
  EXPECT_EQ(1, arena1_bitmap);

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
}

int main(int argc, char** argv) {
  test();
}

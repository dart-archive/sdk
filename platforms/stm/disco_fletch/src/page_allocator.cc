// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "platforms/stm/disco_fletch/src/page_allocator.h"

#include "src/shared/assert.h"

#include "platforms/stm/disco_fletch/src/logger.h"

uint32_t PageAllocator::AddArena(const char* name, uintptr_t start,
                                 size_t size, uint8_t* map, size_t map_size) {
  for (int i = 0; i < kMaxArenas; i++) {
    if (arenas_[i].IsFree()) {
      arenas_[i].Initialize(name, start, size, map, map_size);
      return 1 << i;
    }
  }
  FATAL("Too many arenas added");
  return 0;
}

void* PageAllocator::AllocatePages(size_t pages, uint32_t arenas_bitmap) {
  for (int i = 0; i < kMaxArenas; i++) {
    if ((arenas_bitmap & (1 << i)) != 0) {
      void* result = arenas_[i].AllocatePages(pages);
      if (result != NULL) return result;
    }
  }
  return NULL;
}

void PageAllocator::FreePages(void* start, size_t pages) {
  ASSERT(IS_PAGE_ALIGNED(start));
  for (int i = 0; i < kMaxArenas; i++) {
    if (arenas_[i].ContainsPageAt(start)) {
      arenas_[i].FreePages(start, pages);
      return;
    }
  }
  FATAL("Free of unallocated pages");
}

void PageAllocator::Arena::Initialize(const char* name, uintptr_t arena_start,
                                      size_t arena_size,
                                      uint8_t* map, size_t map_size) {
  uintptr_t start = ROUNDUP(arena_start, PAGE_SIZE);
  size_t size = ROUNDDOWN(arena_start + arena_size, PAGE_SIZE) - start;
  ASSERT(IS_PAGE_ALIGNED(start));
  ASSERT(IS_PAGE_ALIGNED(size));
  name_ = name;
  pages_ = size >> PAGE_SIZE_SHIFT;

  if (map != NULL && map_size >= pages_) {
    // There is a supplied map that can hold the state of all the pages.
    map_ = map;
    base_ = reinterpret_cast<uint8_t*>(start);
  } else {
    // Allocate a map with one byte per page from the beginning of the arena.
    map_ = reinterpret_cast<uint8_t*>(start);
    pages_ -= ROUNDUP(pages_, PAGE_SIZE) / PAGE_SIZE;
    base_ = reinterpret_cast<uint8_t*>(PAGE_ALIGN(start + pages_));
  }
  memset(map_, 0, pages_);
}

void* PageAllocator::Arena::AllocatePages(size_t pages) {
  if (pages == 0 || pages > pages_) return NULL;
  for (size_t i = 0; i < pages_ - pages + 1; i++) {
    bool found = true;
    for (size_t j = 0; j < pages; j++) {
      if (map_[i + j] != 0) {
        i += j;
        found = false;
        break;
      }
    }
    if (found) {
      memset(map_ + i, 1, pages);
      return base_ + (i << PAGE_SIZE_SHIFT);  // i * PAGE_SIZE.
    }
  }
  return NULL;
}

void PageAllocator::Arena::FreePages(void* start, size_t pages) {
  size_t index = (reinterpret_cast<uint8_t*>(start) - base_) >> PAGE_SIZE_SHIFT;
  for (int i = 0; i < pages; i++) {
    ASSERT(map_[index + i] != 0);
    map_[index + i] = 0;
  }
}

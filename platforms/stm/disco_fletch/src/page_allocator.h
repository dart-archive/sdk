// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_FLETCH_SRC_PAGE_ALLOCATOR_H_
#define PLATFORMS_STM_DISCO_FLETCH_SRC_PAGE_ALLOCATOR_H_

#include <cinttypes>
#include <cstdlib>
#include <cstring>

#include "platforms/stm/disco_fletch/src/globals.h"

class PageAllocator {
 public:
  PageAllocator() { Initialize(); }

  void Initialize() {
    // The initialization must be simple, as it can be called early
    // during startup before the C++-runtime is fully initialized.
    memset(&arenas_, 0, kMaxArenas * sizeof(Arena));
  }

  // Add a section of memory to the allocator.
  //
  // Returns the bit in the arenas bitmap representing this
  // arena. This bit can be used in the call to AllocatePages.
  uint32_t AddArena(const char* name, uintptr_t start, size_t size);

  // Allocate pages from an arena. The arenas_bitmap specifies the
  // arenas to try. The default is to only allocate in the initial
  // arena added.
  void* AllocatePages(size_t pages, uint32_t arenas_bitmap = 0x1);
  void FreePages(void* start, size_t pages);

  static size_t PagesForBytes(size_t bytes) {
    return ROUNDUP(bytes, PAGE_SIZE) / PAGE_SIZE;
  }

 private:
  class Arena {
   public:
    void Initialize(const char* name, uintptr_t start, size_t size);
    void* AllocatePages(size_t pages);
    void FreePages(void* start, size_t pages);

    bool IsFree() { return pages_ == 0; }
    bool ContainsPageAt(void* start) {
      return base_ <= start && start < base_ + (pages_ << PAGE_SIZE_SHIFT);
    }

   private:
    const char* name_;
    size_t pages_;
    uint8_t* base_;
    uint8_t* map_;
  };

  static const int kMaxArenas = 3;
  Arena arenas_[kMaxArenas];
};

#endif  // PLATFORMS_STM_DISCO_FLETCH_SRC_PAGE_ALLOCATOR_H_

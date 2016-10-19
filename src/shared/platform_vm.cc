// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Platforms that support virtual memory.

#if defined(DARTINO_TARGET_OS_WIN) || defined(DARTINO_TARGET_OS_POSIX)

#include "src/shared/globals.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"

namespace dartino {

namespace Platform {

class Arena {
 public:
  explicit Arena(VirtualMemory* vm)
      : lock_(CreateMutex()), vm_(vm), pages_(vm->size() >> kPageBits) {
    map_ = new uint8[pages_];
    memset(map_, 0, pages_);
  }

  ~Arena() {
    delete lock_;
    lock_ = NULL;
    delete map_;
    map_ = NULL;
  }

  uword Allocate(uword size) {
    uword pages = size >> kPageBits;
    if (pages == 0 || pages > pages_) return 0;

    lock_->Lock();
    for (size_t i = 0; i <= pages_ - pages; i++) {
      if (map_[i + pages - 1] != 0) {
        // This is just an optimization to skip large blocks of allocated pages
        // faster.
        i += pages - 1;
        continue;
      }
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
        lock_->Unlock();
        uword result =
            reinterpret_cast<uword>(vm_->address()) + (i << kPageBits);
        if (!vm_->Commit(reinterpret_cast<void*>(result), size)) {
          memset(map_ + i, 0, pages);
          return 0;
        }
        return result;
      }
    }
    lock_->Unlock();

    return 0;
  }

  void Free(uword address, uword size) {
    uword index =
        (address - reinterpret_cast<uword>(vm_->address())) >> kPageBits;
    ASSERT(index < pages_);
    uword pages = size >> kPageBits;
    ASSERT(pages << kPageBits == size);

    lock_->Lock();
    for (size_t i = 0; i < pages; i++) {
      ASSERT(map_[index + i] != 0);
      map_[index + i] = 0;
    }
    lock_->Unlock();

    vm_->Uncommit(reinterpret_cast<void*>(address), size);
  }

  void GetMemoryRange(void** start, uword* size) {
    *start = vm_->address();
    *size = vm_->size();
  }

 private:
  Mutex* lock_;
  uint8* map_;
  VirtualMemory* vm_;
  size_t pages_;
};

static Arena* arena = NULL;
static VirtualMemory* vm = NULL;

void VirtualMemoryInit() {
  if (arena == NULL) {
    uword size = 512 * MB;
    vm = new VirtualMemory(size);
    arena = new Arena(vm);
  }
}

void* AllocatePages(uword size, int arenas) {
  size = Utils::RoundUp(size, kPageSize);

  return reinterpret_cast<void*>(arena->Allocate(size));
}

void FreePages(void* address, uword size) {
  ASSERT(size == Utils::RoundUp(size, kPageSize));
  arena->Free(reinterpret_cast<uword>(address), size);
}

int GetHeapMemoryRanges(HeapMemoryRange* ranges, int number_of_ranges) {
  arena->GetMemoryRange(&ranges[0].address, &ranges[0].size);
  return 1;
}

}  // namespace Platform
}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_WIN) || defined(DARTINO_TARGET_OS_POSIX)

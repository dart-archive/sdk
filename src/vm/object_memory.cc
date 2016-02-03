// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/object_memory.h"

#include <stdlib.h>
#include <stdio.h>

#include "src/shared/assert.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"

#include "src/vm/frame.h"
#include "src/vm/heap.h"
#include "src/vm/mark_sweep.h"
#include "src/vm/object.h"

#ifdef DARTINO_TARGET_OS_LK
#include "lib/page_alloc.h"
#endif

#ifdef DARTINO_TARGET_OS_CMSIS
// TODO(sgjesse): Put this into an .h file
#define PAGE_SIZE_SHIFT 12
#define PAGE_SIZE (1 << PAGE_SIZE_SHIFT)
extern "C" void* page_alloc(size_t pages);
extern "C" void page_free(void* start, size_t pages);
#endif

namespace dartino {

static Smi* chunk_end_sentinel() { return Smi::zero(); }

static bool HasSentinelAt(uword address) {
  return *reinterpret_cast<Object**>(address) == chunk_end_sentinel();
}

Chunk::~Chunk() {
  // If the memory for this chunk is external we leave it alone
  // and let the embedder deallocate it.
  if (is_external()) return;
#if defined(DARTINO_TARGET_OS_CMSIS) || defined(DARTINO_TARGET_OS_LK)
  page_free(reinterpret_cast<void*>(base()), size() >> PAGE_SIZE_SHIFT);
#elif defined(DARTINO_TARGET_OS_WIN)
  _aligned_free(reinterpret_cast<void*>(base()));
#else
  free(reinterpret_cast<void*>(base()));
#endif
}

Space::~Space() { FreeAllChunks(); }

void Space::FreeAllChunks() {
  Chunk* current = first();
  while (current != NULL) {
    Chunk* next = current->next();
    ObjectMemory::FreeChunk(current);
    current = next;
  }
}

int Space::Size() {
  int result = 0;
  Chunk* chunk = first();
  while (chunk != NULL) {
    result += chunk->size();
    chunk = chunk->next();
  }
  ASSERT(Used() <= result);
  return result;
}

word Space::OffsetOf(HeapObject* object) {
  uword address = object->address();
  uword base = first()->base();

  // Make sure the space consists of exactly one chunk!
  ASSERT(first() == last());
  ASSERT(first()->Includes(address));
  ASSERT(base <= address);

  return address - base;
}

void Space::AdjustAllocationBudget(int used_outside_space) {
  int used = Used() + used_outside_space;
  allocation_budget_ = Utils::Maximum(DefaultChunkSize(used), used);
}

void Space::IncreaseAllocationBudget(int size) { allocation_budget_ += size; }

void Space::DecreaseAllocationBudget(int size) { allocation_budget_ -= size; }

void Space::SetAllocationBudget(int new_budget) {
  allocation_budget_ = Utils::Maximum(DefaultChunkSize(new_budget), new_budget);
}

void Space::IterateObjects(HeapObjectVisitor* visitor) {
  if (is_empty()) return;
  Flush();
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->base();
    while (!HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      current += visitor->Visit(object);
    }
    visitor->ChunkEnd(current);
  }
}

void SemiSpace::CompleteScavenge(PointerVisitor* visitor) {
  Flush();
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->base();
    while (!HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      object->IteratePointers(visitor);
      current += object->Size();
      Flush();
    }
  }
}

#ifdef DEBUG
void Space::Find(uword w, const char* name) {
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    chunk->Find(w, name);
  }
}
#endif

void Space::CompleteTransformations(PointerVisitor* visitor) {
  Flush();
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->base();
    while (!HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      if (object->HasForwardingAddress()) {
        current += Instance::kSize;
      } else {
        object->IteratePointers(visitor);
        current += object->Size();
      }
      Flush();
    }
  }
}

void PageDirectory::Clear() {
  memset(&tables_, 0, kPointerSize * ARRAY_SIZE(tables_));
}

void PageDirectory::Delete() {
  for (unsigned i = 0; i < ARRAY_SIZE(tables_); i++) {
    delete tables_[i];
  }
  Clear();
}

Mutex* ObjectMemory::mutex_;
#ifdef DARTINO32
PageDirectory ObjectMemory::page_directory_;
#else
PageDirectory* ObjectMemory::page_directories_[1 << 13];
#endif
Atomic<uword> ObjectMemory::allocated_;

void ObjectMemory::Setup() {
  mutex_ = Platform::CreateMutex();
  allocated_ = 0;
#ifdef DARTINO32
  page_directory_.Clear();
#else
  memset(&page_directories_, 0, kPointerSize * ARRAY_SIZE(page_directories_));
#endif
}

void ObjectMemory::TearDown() {
#ifdef DARTINO32
  page_directory_.Delete();
#else
  for (unsigned i = 0; i < ARRAY_SIZE(page_directories_); i++) {
    PageDirectory* directory = page_directories_[i];
    if (directory == NULL) continue;
    directory->Delete();
    page_directories_[i] = NULL;
    delete directory;
  }
#endif
  delete mutex_;
}

#ifdef DEBUG
void Chunk::Scramble() {
  void* p = reinterpret_cast<void*>(base());
  memset(p, 0xab, limit() - base());
}

void Chunk::Find(uword word, const char* name) {
  if (word >= base() && word < limit()) {
    fprintf(stderr, "0x%08zx is inside the 0x%08zx-0x%08zx chunk in %s\n",
            static_cast<size_t>(word), static_cast<size_t>(base()),
            static_cast<size_t>(limit()), name);
  }
  for (uword current = base(); current < limit(); current += 4) {
    if (*reinterpret_cast<unsigned*>(current) == (unsigned)word) {
      fprintf(stderr, "Found 0x%08zx in %s at 0x%08zx\n",
              static_cast<size_t>(word), name, static_cast<size_t>(current));
    }
  }
}
#endif

Chunk* ObjectMemory::AllocateChunk(Space* owner, int size) {
  ASSERT(owner != NULL);

  size = Utils::RoundUp(size, kPageSize);
  void* memory;
#if defined(__ANDROID__)
  // posix_memalign doesn't exist on Android. We fallback to
  // memalign.
  memory = memalign(kPageSize, size);
#elif defined(DARTINO_TARGET_OS_WIN)
  memory = _aligned_malloc(size, kPageSize);
#elif defined(DARTINO_TARGET_OS_LK) || defined(DARTINO_TARGET_OS_CMSIS)
  size = Utils::RoundUp(size, PAGE_SIZE);
  memory = page_alloc(size >> PAGE_SIZE_SHIFT);
#else
  if (posix_memalign(&memory, kPageSize, size) != 0) return NULL;
#endif
  if (memory == NULL) return NULL;

  uword base = reinterpret_cast<uword>(memory);
  Chunk* chunk = new Chunk(owner, base, size);

  ASSERT(base == Utils::RoundUp(base, kPageSize));
  ASSERT(size == Utils::RoundUp(size, kPageSize));

#ifdef DEBUG
  chunk->Scramble();
#endif
  SetSpaceForPages(chunk->base(), chunk->limit(), owner);
  allocated_ += size;
  return chunk;
}

Chunk* ObjectMemory::CreateFlashChunk(Space* owner, void* memory, int size) {
  ASSERT(owner != NULL);
  ASSERT(size == Utils::RoundUp(size, kPageSize));

  uword base = reinterpret_cast<uword>(memory);
  ASSERT(base % kPageSize == 0);

  Chunk* chunk = new Chunk(owner, base, size, true);
  SetSpaceForPages(chunk->base(), chunk->limit(), owner);
  return chunk;
}

void ObjectMemory::FreeChunk(Chunk* chunk) {
#ifdef DEBUG
  // Do not touch external memory. It might be read-only.
  if (!chunk->is_external()) chunk->Scramble();
#endif
  SetSpaceForPages(chunk->base(), chunk->limit(), NULL);
  allocated_ -= chunk->size();
  delete chunk;
}

bool ObjectMemory::IsAddressInSpace(uword address, const Space* space) {
  PageTable* table = GetPageTable(address);
  return (table != NULL) ? table->Get((address >> 12) & 0x3ff) == space : false;
}

PageTable* ObjectMemory::GetPageTable(uword address) {
#ifdef DARTINO32
  return page_directory_.Get(address >> 22);
#else
  PageDirectory* directory = page_directories_[address >> 35];
  if (directory == NULL) return NULL;
  return directory->Get((address >> 22) & 0x1fff);
#endif
}

void ObjectMemory::SetPageTable(uword address, PageTable* table) {
#ifdef DARTINO32
  page_directory_.Set(address >> 22, table);
#else
  int index = address >> 35;
  PageDirectory* directory = page_directories_[index];
  if (directory == NULL) {
    page_directories_[index] = directory = new PageDirectory();
    directory->Clear();
  }
  return directory->Set((address >> 22) & 0x1fff, table);
#endif
}

void ObjectMemory::SetSpaceForPages(uword base, uword limit, Space* space) {
  ASSERT(Utils::IsAligned(base, kPageSize));
  ASSERT(Utils::IsAligned(limit, kPageSize));
  for (uword address = base; address < limit; address += kPageSize) {
    PageTable* table = GetPageTable(address);
    if (table == NULL) {
      ASSERT(space != NULL);
      ScopedLock scope(mutex_);
      // Fetch the table again while locked to make sure only one thread
      // gets to initialize the directory entry.
      table = GetPageTable(address);
      if (table == NULL) {
        SetPageTable(address, table = new PageTable(address & ~0x3fffff));
      }
    }
    table->Set((address >> 12) & 0x3ff, space);
  }
}

void OldSpace::RebuildAfterTransformations() {
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword free_start = 0;
    uword current = chunk->base();
    while (!HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      if (object->HasForwardingAddress()) {
        if (free_start == 0) free_start = current;
        current += Instance::kSize;
        while (HeapObject::FromAddress(current)->IsFiller()) {
          current += kPointerSize;
        }
      } else {
        if (free_start != 0) {
          free_list_->AddChunk(free_start, current - free_start);
          free_start = 0;
        }
        current += object->Size();
      }
    }
  }
}

void SemiSpace::RebuildAfterTransformations() {
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->base();
    while (!HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      if (object->HasForwardingAddress()) {
        for (int i = 0; i < Instance::kSize; i += kPointerSize) {
          *reinterpret_cast<Object**>(current + i) =
              StaticClassStructures::one_word_filler_class();
        }
        current += Instance::kSize;
      } else {
        current += object->Size();
      }
    }
  }
}

}  // namespace dartino

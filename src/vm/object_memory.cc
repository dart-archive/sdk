// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
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
#include "src/vm/storebuffer.h"

#ifdef FLETCH_TARGET_OS_LK
#include "lib/page_alloc.h"
#endif

namespace fletch {

static Smi* chunk_end_sentinel() { return Smi::zero(); }

static bool HasSentinelAt(uword address) {
  return *reinterpret_cast<Object**>(address) == chunk_end_sentinel();
}

Chunk::~Chunk() {
#if defined(FLETCH_TARGET_OS_CMSIS)
  free(reinterpret_cast<void*>(allocated_));
#elif defined(FLETCH_TARGET_OS_LK)
  page_free(reinterpret_cast<void*>(base()), size() >> PAGE_SIZE_SHIFT);
#else
  free(reinterpret_cast<void*>(base()));
#endif
}

Space::Space(int maximum_initial_size)
    : first_(NULL),
      last_(NULL),
      used_(0),
      top_(0),
      limit_(0),
      no_allocation_nesting_(0),
      free_list_(NULL),
      active_freelist_chunk_(0),
      active_freelist_chunk_size_(0) {
  if (maximum_initial_size > 0) {
    int size = Utils::Minimum(maximum_initial_size, kDefaultMaximumChunkSize);
    Chunk* chunk = ObjectMemory::AllocateChunk(this, size);
    if (chunk == NULL) FATAL1("Failed to allocate %d bytes.\n", size);
    Append(chunk);
    top_ = chunk->base();
    limit_ = chunk->limit();
  }
}

Space::~Space() {
  delete free_list_;
  Chunk* current = first();
  while (current != NULL) {
    Chunk* next = current->next();
    ObjectMemory::FreeChunk(current);
    current = next;
  }
}

void Space::Flush() {
  if (!using_copying_collector()) {
    if (active_freelist_chunk_ != 0) {
      free_list_->AddChunk(active_freelist_chunk_, active_freelist_chunk_size_);
      active_freelist_chunk_ = 0;
      active_freelist_chunk_size_ = 0;
      used_ -= active_freelist_chunk_size_;
    }
  } else if (!is_empty()) {
    // Set sentinel at allocation end.
    ASSERT(top_ < limit_);
    *reinterpret_cast<Object**>(top_) = chunk_end_sentinel();
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

uword Space::TryAllocate(int size) {
  uword new_top = top_ + size;
  // Make sure there is room for chunk end sentinel.
  if (new_top < limit_) {
    uword result = top_;
    top_ = new_top;
    return result;
  }

  if (!is_empty()) {
    // Make the last chunk consistent with a sentinel.
    Flush();
  }

  return 0;
}

uword Space::AllocateInNewChunk(int size, bool fatal) {
  // Allocate new chunk that is big enough to fit the object.
  int default_chunk_size = DefaultChunkSize(Used());
  int chunk_size = size >= default_chunk_size
      ? (size + kPointerSize)  // Make sure there is room for sentinel.
      : default_chunk_size;

  Chunk* chunk = ObjectMemory::AllocateChunk(this, chunk_size);
  if (chunk != NULL) {
    // Link it into the space.
    Append(chunk);

    // Update limits.
    allocation_budget_ -= chunk->size();
    top_ = chunk->base();
    limit_ = chunk->limit();

    // Allocate.
    uword result = TryAllocate(size);
    if (result != 0) return result;
  }
  if (fatal) FATAL1("Failed to allocate memory of size %d\n", size);
  return 0;
}

uword Space::AllocateFromFreeList(int size, bool fatal) {
  // Flush the active chunk into the free list.
  Flush();

  FreeListChunk* chunk = free_list_->GetChunk(size);
  if (chunk != NULL) {
    active_freelist_chunk_ = chunk->address();
    active_freelist_chunk_size_ = chunk->size();
    // Account all of the chunk memory as used for now. When the
    // rest of the freelist chunk is flushed into the freelist we
    // decrement used_ by the amount still left unused. used_
    // therefore reflects actual memory usage after Flush has been
    // called.
    used_ += active_freelist_chunk_size_;
    return Allocate(size);
  } else {
    // Allocate new chunk that is big enough to fit the object.
    int default_chunk_size = DefaultChunkSize(Used());
    int chunk_size = (size >= default_chunk_size)
        ? (size + kPointerSize)  // Make sure there is room for sentinel.
        : default_chunk_size;

    Chunk* chunk = ObjectMemory::AllocateChunk(this, chunk_size);
    if (chunk != NULL) {
      // Link it into the space.
      Append(chunk);
      uword last_word = chunk->base() + chunk->size() - kPointerSize;
      *reinterpret_cast<Object**>(last_word) = chunk_end_sentinel();
      active_freelist_chunk_ = chunk->base();
      active_freelist_chunk_size_ = chunk->size() - kPointerSize;
      // Account all of the chunk memory as used for now. When the
      // rest of the freelist chunk is flushed into the freelist we
      // decrement used_ by the amount still left unused. used_
      // therefore reflects actual memory usage after Flush has been
      // called.
      used_ += active_freelist_chunk_size_;
      return Allocate(size);
    }
  }

  if (fatal) FATAL1("Failed to allocate memory of size %d\n", size);
  return 0;
}

uword Space::AllocateInternal(int size, bool fatal) {
  ASSERT(size >= HeapObject::kSize);
  ASSERT(Utils::IsAligned(size, kPointerSize));
  if (!in_no_allocation_failure_scope() && needs_garbage_collection()) {
    return 0;
  }

  if (!using_copying_collector()) {
    // Fast case bump allocation.
    if (active_freelist_chunk_size_ >= size) {
      uword result = active_freelist_chunk_;
      active_freelist_chunk_ += size;
      active_freelist_chunk_size_ -= size;
      allocation_budget_ -= size;
      return result;
    }
    // Can't use bump allocation. Allocate from free lists.
    return AllocateFromFreeList(size, fatal);
  } else {
    uword result = TryAllocate(size);
    if (result != 0) return result;
    return AllocateInNewChunk(size, fatal);
  }
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

void Space::TryDealloc(uword location, int size) {
  if (using_copying_collector()) {
    if (top_ == location) top_ -= size;
  } else {
    if (active_freelist_chunk_ == location) {
      active_freelist_chunk_ -= size;
      active_freelist_chunk_size_ += size;
      allocation_budget_ += size;
    }
  }
}

void Space::AdjustAllocationBudget(int used_outside_space) {
  int used = Used() + used_outside_space;
  allocation_budget_ = Utils::Maximum(DefaultChunkSize(used), used);
}

void Space::IncreaseAllocationBudget(int size) {
  allocation_budget_ += size;
}

void Space::DecreaseAllocationBudget(int size) {
  allocation_budget_ -= size;
}

void Space::SetAllocationBudget(int new_budget) {
  allocation_budget_ = new_budget;
}

void Space::set_free_list(FreeList* free_list) {
  free_list_ = free_list;
  uword last_word = first()->base() + first()->size() - kPointerSize;
  *reinterpret_cast<Object**>(last_word) = chunk_end_sentinel();
  free_list->AddChunk(first()->base(), first()->size() - kPointerSize);
}

void Space::PrependSpace(Space* space) {
  bool was_empty = is_empty();

  if (space->is_empty()) return;

  space->Flush();

  Chunk* first = space->first();
  Chunk* chunk = first;
  while (chunk != NULL) {
    ObjectMemory::SetSpaceForPages(chunk->base(), chunk->limit(), this);
    chunk->set_owner(this);
    chunk = chunk->next();
  }

  space->last()->set_next(this->first());
  first_ = first;
  used_ += space->Used();
  if (was_empty) {
    last_ = space->last();
    top_ = space->top_;
    limit_ = space->limit_;
  }

  // NOTE: The destructor of [Space] will use some of the fields, so we just
  // reset all of them.
  space->first_ = NULL;
  space->last_ = NULL;
  space->used_ = 0;
  space->top_ = 0;
  space->limit_ = 0;
  delete space;
}

void Space::Append(Chunk* chunk) {
  ASSERT(chunk->owner() == this);
  if (is_empty()) {
    first_ = last_ = chunk;
  } else {
    // Update the accounting.
    if (using_copying_collector()) {
      used_ += top() - last()->base();
    }
    last_->set_next(chunk);
    last_ = chunk;
  }
  chunk->set_next(NULL);
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

void Space::CompleteScavenge(PointerVisitor* visitor) {
  Flush();
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->base();
    // TODO(kasperl): I don't like the repeated checks to see if p is
    // the last chunk. Can't we just make sure to write the sentinel
    // whenever we've copied over an object, so this check becomes
    // simpler like in IterateObjects?
    while ((chunk == last()) ? (current < top()) : !HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      object->IteratePointers(visitor);
      current += object->Size();
    }
  }
}

void Space::CompleteScavengeMutable(PointerVisitor* visitor,
                                    Space* program_space,
                                    StoreBuffer* store_buffer) {
  ASSERT(store_buffer->is_empty());

  Flush();

  // NOTE: This finder is only called on objects which have been forwarded and
  // whos fields have been forwarded.
  FindImmutablePointerVisitor finder(this, program_space);

  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->base();
    // TODO(kasperl): I don't like the repeated checks to see if p is
    // the last chunk. Can't we just make sure to write the sentinel
    // whenever we've copied over an object, so this check becomes
    // simpler like in IterateObjects?
    while ((chunk == last()) ? (current < top()) : !HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      object->IteratePointers(visitor);

      // We build up a new StoreBuffer, containing all mutable heap objects
      // pointing to the immutable space.
      if (finder.ContainsImmutablePointer(object)) {
        store_buffer->Insert(object);
      }

      current += object->Size();
    }
  }
}

void Space::CompleteTransformations(PointerVisitor* visitor) {
  Flush();
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->base();
    // TODO(kasperl): I don't like the repeated checks to see if p is
    // the last chunk. Can't we just make sure to write the sentinel
    // whenever we've copied over an object, so this check becomes
    // simpler like in IterateObjects?
    while ((chunk == last()) ? (current < top()) : !HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      if (object->forwarding_address() != NULL) {
        current += Instance::kSize;
        while (*reinterpret_cast<uword*>(current) == HeapObject::kTag) {
          current += kPointerSize;
        }
      } else if (object->IsStack()) {
        // We haven't cooked stacks when we perform object transformations.
        // Therefore, we cannot simply iterate pointers in the stack because
        // that would look at the raw bytecode pointers as well. Instead we
        // iterate the actual pointers in each frame directly.
        Frame frame(Stack::cast(object));
        while (frame.MovePrevious()) {
          visitor->VisitBlock(frame.FirstLocalAddress(),
                              frame.LastLocalAddress() + 1);
        }
        current += object->Size();
      } else {
        object->IteratePointers(visitor);
        current += object->Size();
      }
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
#ifdef FLETCH32
PageDirectory ObjectMemory::page_directory_;
#else
PageDirectory* ObjectMemory::page_directories_[1 << 13];
#endif
Atomic<uword> ObjectMemory::allocated_;

void ObjectMemory::Setup() {
  mutex_ = Platform::CreateMutex();
  allocated_ = 0;
#ifdef FLETCH32
  page_directory_.Clear();
#else
  memset(&page_directories_, 0, kPointerSize * ARRAY_SIZE(page_directories_));
#endif
}

void ObjectMemory::TearDown() {
#ifdef FLETCH32
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
#endif

Chunk* ObjectMemory::AllocateChunk(Space* owner, int size) {
  ASSERT(owner != NULL);

  size = Utils::RoundUp(size, kPageSize);
  void* memory;
#if defined(__ANDROID__)
  // posix_memalign doesn't exist on Android. We fallback to
  // memalign.
  memory = memalign(kPageSize, size);
#elif defined(FLETCH_TARGET_OS_LK)
  size = Utils::RoundUp(size, PAGE_SIZE);
  memory = page_alloc(size >> PAGE_SIZE_SHIFT);
#elif defined(FLETCH_TARGET_OS_CMSIS)
  memory = malloc(size + kPageSize);
#else
  if (posix_memalign(&memory, kPageSize, size) != 0) return NULL;
#endif
  if (memory == NULL) return NULL;

#ifdef FLETCH_TARGET_OS_CMSIS
  uword allocated = reinterpret_cast<uword>(memory);
  uword base = (allocated / kPageSize + 1) * kPageSize;
  Chunk* chunk = new Chunk(owner, base, size, allocated);
#else
  uword base = reinterpret_cast<uword>(memory);
  Chunk* chunk = new Chunk(owner, base, size);
#endif

  ASSERT(base == Utils::RoundUp(base, kPageSize));
  ASSERT(size == Utils::RoundUp(size, kPageSize));

#ifdef DEBUG
  chunk->Scramble();
#endif
  SetSpaceForPages(chunk->base(), chunk->limit(), owner);
  allocated_ += size;
  return chunk;
}

Chunk* ObjectMemory::CreateChunk(Space* owner, void* memory, int size) {
  ASSERT(owner != NULL);
  ASSERT(size == Utils::RoundUp(size, kPageSize));

  uword base = reinterpret_cast<uword>(memory);
  ASSERT(base % kPageSize == 0);

#ifdef FLETCH_TARGET_OS_CMSIS
  Chunk* chunk = new Chunk(owner, base, size, base);
#else
  Chunk* chunk = new Chunk(owner, base, size);
#endif
  SetSpaceForPages(chunk->base(), chunk->limit(), owner);
  return chunk;
}

void ObjectMemory::FreeChunk(Chunk* chunk) {
#ifdef DEBUG
  chunk->Scramble();
#endif
  SetSpaceForPages(chunk->base(), chunk->limit(), NULL);
  allocated_ -= chunk->size();
  delete chunk;
}

bool ObjectMemory::IsAddressInSpace(uword address, const Space* space) {
  PageTable* table = GetPageTable(address);
  return (table != NULL)
      ? table->Get((address >> 12) & 0x3ff) == space
      : false;
}

PageTable* ObjectMemory::GetPageTable(uword address) {
#ifdef FLETCH32
  return page_directory_.Get(address >> 22);
#else
  PageDirectory* directory = page_directories_[address >> 35];
  if (directory == NULL) return NULL;
  return directory->Get((address >> 22) & 0x1fff);
#endif
}

void ObjectMemory::SetPageTable(uword address, PageTable* table) {
#ifdef FLETCH32
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

}  // namespace fletch

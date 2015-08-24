// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_OBJECT_MEMORY_H_
#define SRC_VM_OBJECT_MEMORY_H_

#include "src/shared/globals.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"

namespace fletch {

class Heap;
class HeapObject;
class HeapObjectVisitor;
class PointerVisitor;
class Process;
class Space;
class StoreBuffer;

const int kPageSize = 4 * KB;

// A chunk represents a block of memory provided by ObjectMemory.
class Chunk {
 public:
  // The space owning this chunk.
  Space* owner() const { return owner_; }

  // The next chunk in same space.
  Chunk* next() const { return next_; }

  // Returns the first address in this chunk.
  uword base() const { return base_; }

  // Returns the first address past this chunk.
  uword limit() const { return limit_; }

  // Returns the size of this chunk in bytes.
  uword size() const { return limit_ - base_; }

  // Test for inclusion.
  bool Includes(uword address) const {
    return (address >= base()) && (address < limit());
  }

#ifdef DEBUG
  // Fill the space with garbage.
  void Scramble();
#endif

 private:
  Space* owner_;
  const uword base_;
  const uword limit_;

  Chunk* next_;

  Chunk(Space* owner, uword base, uword size)
      : owner_(owner), base_(base), limit_(base + size) { }

  ~Chunk();

  void set_next(Chunk* value) { next_ = value; }
  void set_owner(Space* value) { owner_ = value; }

  friend class ObjectMemory;
  friend class PageTable;
  friend class Space;
};

// Space is a chain of chunks. It supports allocation and traversal.
class Space {
 public:
  static const int kDefaultMinimumChunkSize = 4 * KB;
  static const int kDefaultMaximumChunkSize = 256 * KB;

  explicit Space(int maximum_initial_size = 0);

  ~Space();

  // Allocate raw object.
  uword Allocate(int size);

  // Rewind allocation top by size bytes if location is equal to current
  // allocation top.
  void TryDealloc(uword location, int size);

  // Flush will make the current chunk consistent for iteration.
  void Flush();

  // Returns the total size of allocated objects.
  int Used() {
    int result = used_;
    if (is_empty()) return result;
    return result + (top() - last()->base());
  }

  // Iterate over all objects in this space.
  void IterateObjects(HeapObjectVisitor* visitor);

  // Scavenge loop.
  void CompleteScavenge(PointerVisitor* visitor);
  void CompleteScavengeMutable(PointerVisitor* visitor,
                               Space* program_space,
                               StoreBuffer* store_buffer);

  // Schema change support.
  void CompleteTransformations(PointerVisitor* visitor, Process* process);

  // Returns true if the address is inside this space.
  inline bool Includes(uword address) const;

  // Adjust the allocation budget based on the current heap size.
  void AdjustAllocationBudget();

  void SetAllocationBudget(int new_budget);

  // Tells whether garbage collection is needed.
  bool needs_garbage_collection() { return allocation_budget_ <= 0; }

  bool in_no_allocation_failure_scope() { return no_allocation_nesting_ != 0; }

  // TODO(kasperl): This seems like a bad interface.
  void AppendProgramChunk(Chunk* chunk, uword top) {
    Append(chunk);
    top_ = top;
    limit_ = chunk->limit_;
  }

  // Takes all chunks inside [space] and prepends it to this space.
  // The given [space] will be deleted.
  void PrependSpace(Space* space);

  bool is_empty() const { return first_ == NULL; }

  static int DefaultChunkSize(int heap_size) {
    // We return a value between kDefaultMinimumChunkSize and
    // kDefaultMaximumChunkSize - and try to keep the chunks smaller than 20% of
    // the heap.
    return Utils::Minimum(
        Utils::Maximum(kDefaultMinimumChunkSize, heap_size / 5),
        kDefaultMaximumChunkSize);
  }

 private:
  friend class NoAllocationFailureScope;

  uword TryAllocate(int size);
  uword AllocateInNewChunk(int size);

  void Append(Chunk* chunk);

  Chunk* first() { return first_; }
  Chunk* last() { return last_; }
  uword top() { return top_; }

  void IncrementNoAllocationNesting() { ++no_allocation_nesting_; }
  void DecrementNoAllocationNesting() { --no_allocation_nesting_; }

  Chunk* first_;  // First chunk in this space.
  Chunk* last_;   // Last chunk in this space.
  int used_;  // Allocated bytes, excluding last chunk.
  uword top_;  // Allocation top in last chunk.
  uword limit_;  // Allocation limit in last chunk.
  int allocation_budget_;  // Budget before needing a GC.
  int no_allocation_nesting_;
};

class NoAllocationFailureScope {
 public:
  explicit NoAllocationFailureScope(Space* space) : space_(space) {
    space->IncrementNoAllocationNesting();
  }

  ~NoAllocationFailureScope() {
    space_->DecrementNoAllocationNesting();
  }

 private:
  Space* space_;
};

class PageTable {
 public:
  explicit PageTable(uword base) : base_(base) {
    memset(spaces_, 0, kPointerSize * ARRAY_SIZE(spaces_));
  }

  uword base() const { return base_; }

  Space* Get(int index) const { return spaces_[index]; }
  void Set(int index, Space* space) { spaces_[index] = space; }

 private:
  Space* spaces_[1 << 10];
  uword base_;
};

class PageDirectory {
 public:
  void Clear();
  void Delete();

  PageTable* Get(int index) const { return tables_[index]; }
  void Set(int index, PageTable* table) { tables_[index] = table; }

 private:
#ifdef FLETCH32
  PageTable* tables_[1 << 10];
#else
  PageTable* tables_[1 << 13];
#endif
};

// ObjectMemory controls all memory used by object heaps.
class ObjectMemory {
 public:
  // Allocate a new chunk for a given space. All chunk sizes are
  // rounded up the page size and the allocated memory is aligned
  // to a page boundary.
  static Chunk* AllocateChunk(Space* space, int size);

  // Release the chunk.
  static void FreeChunk(Chunk* chunk);

  // Determine if the address is in the given space using page tables
  // mapping an address to the space containing it.
  //
  // The page tables rely on 4k size-aligned chunks which makes the
  // least significant 12 bits of a chunk zero. An address is mapped
  // to its chunk address by masking out the least significant 12
  // bits. Then that chunk address is mapped to a space using tables.
  //
  // On 32-bit systems, the remaining 20 bits of the chunk address are
  // used as indices into two table. The most significant 10 bits
  // identify a page table in a page directory. The least significant
  // 10 bits identify a space in that page table:
  //
  // 32-bit: [ 10: table | 10: space | 12: zeros ]
  //
  // On 64-bit systems we rely on the virtual address space only being
  // 48 bits. This is true for x64 and for arm64 as well.  With 4k
  // alignment that leaves 36 bits of the chunk address which are used
  // as indices into three tables. The most significant 13 bits identify
  // a page directory. The next 13 bits identify a page table in the
  // page directory. The least significant 10 bits identify a space in
  // that page table:
  //
  // 64-bit: [ 16: zeros | 13: directory | 13: table | 10 space | 12: zeros ]
  static bool IsAddressInSpace(uword address, const Space* space);

  // Setup and tear-down support.
  static void Setup();
  static void TearDown();

 private:
  // Low-level access to the page table associated with a given
  // address.
  static PageTable* GetPageTable(uword address);
  static void SetPageTable(uword address, PageTable* table);

  // Associate a range of pages with a given space.
  static void SetSpaceForPages(uword base, uword limit, Space* space);

#ifdef FLETCH32
  static PageDirectory page_directory_;
#else
  static PageDirectory* page_directories_[1 << 13];
#endif
  static Mutex* mutex_;    // Mutex used for synchronized chunk allocation.

  friend class Space;
};

inline bool Space::Includes(uword address) const {
  return ObjectMemory::IsAddressInSpace(address, this);
}

}  // namespace fletch

#endif  // SRC_VM_OBJECT_MEMORY_H_

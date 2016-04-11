// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Maintains data outside the heap that the garbage collector needs. Because
// the heap is always allocated from a restricted contiguous address area, the
// tables of the metadata can also be contiguous without needing complicated
// mapping.

#ifndef SRC_VM_GC_METADATA_H_
#define SRC_VM_GC_METADATA_H_

#include <stdint.h>

#include "src/vm/object_memory.h"

namespace dartino {

class GCMetadata {
 public:
  static void Setup();
  static void TearDown();

  static const int kCardSizeLog2 = 7;
  // Number of bytes per remembered-set card.
  static const int kCardSize = 1 << kCardSizeLog2;

  static const int kCardSizeInBitsLog2 = kCardSizeLog2 + 3;

  static const int kWordShift = (sizeof(uword) == 8 ? 3 : 2);

  // There is a byte per card, and any two byte values would work here.
  static const int kNoNewSpacePointers = 0;
  static const int kNewSpacePointers = 1;  // Actually any non-zero value.

  // One bit per word of mark bits, so the size in bytes is 1/8th of that.
  static const int kMarkBitsShift = 3 + kWordShift;

  static void InitializeStartsForChunk(Chunk* chunk) {
    uint8* from = StartsFor(chunk->base());
    uint8* to = StartsFor(chunk->limit());
    memset(from, kNoObjectStart, to - from);
  }

  static void InitializeRememberedSetForChunk(Chunk* chunk) {
    uint8* from = RememberedSetFor(chunk->base());
    uint8* to = RememberedSetFor(chunk->limit());
    memset(from, GCMetadata::kNoNewSpacePointers, to - from);
  }

  static void InitializeOverflowBitsForChunk(Chunk* chunk) {
    uint8* from = OverflowBitsFor(chunk->base());
    uint8* to = OverflowBitsFor(chunk->limit());
    memset(from, 0, to - from);
  }

  static void ClearMarkBitsFor(Chunk* chunk) {
    uword base = chunk->base();
    uword size = (chunk->limit() - base) >> kMarkBitsShift;
    base = (base >> kMarkBitsShift) + singleton_.mark_bits_bias_;
    memset(reinterpret_cast<uint8*>(base), 0, size);
  }

  static inline uint8* StartsFor(uword address) {
    return reinterpret_cast<uint8*>((address >> kCardSizeLog2) +
                                    singleton_.starts_bias_);
  }

  static inline uint8* RememberedSetFor(uword address) {
    return reinterpret_cast<uint8*>((address >> kCardSizeLog2) +
                                    singleton_.remembered_set_bias_);
  }

  static inline uint8* OverflowBitsFor(uword address) {
    return reinterpret_cast<uint8*>((address >> kCardSizeInBitsLog2) +
                                    singleton_.overflow_bits_bias_);
  }

  static inline uint32* MarkBitsFor(HeapObject* object) {
    uword address = reinterpret_cast<uword>(object);
    uword result =
        (singleton_.mark_bits_bias_ + (address >> kMarkBitsShift)) & ~3;
    return reinterpret_cast<uint32*>(result);
  }

  // Returns true if the object is grey (queued) or black(scanned).
  static bool IsMarked(HeapObject* object) {
    uword address = reinterpret_cast<uword>(object);
    address = (singleton_.mark_bits_bias_ + (address >> kMarkBitsShift)) & ~3;
    uint32 mask = 1 << ((reinterpret_cast<uword>(object) >> kWordShift) & 31);
    return (*reinterpret_cast<uint32*>(address) & mask) != 0;
  }

  // Returns true if the object is grey (queued), but not black (scanned).
  // This is used when scanning the heap after mark stack overflow, looking for
  // objects that are conceptually queued, but which are missing from the
  // explicit marking queue.
  static bool IsGrey(HeapObject* object) {
    return IsMarked(object) &&
           !IsMarked(reinterpret_cast<HeapObject*>(
               reinterpret_cast<uword>(object) + sizeof(uword)));
  }

  // Marks an object grey, which normally means it has been queued on the mark
  // stack.
  static void Mark(HeapObject* object) {
    uint32* bits = MarkBitsFor(object);
    uint32 mask = 1 << ((reinterpret_cast<uword>(object) >> kWordShift) & 31);
    *bits |= mask;
  }

  // Marks all the bits (1 bit per word) that correspond to a live object.
  // This marks the object black (scanned) and sets up the bitmap data we need
  // for compaction.
  static void MarkAll(HeapObject* object, size_t size) {
    // If there were 1-word live objects we could not see the difference
    // between grey objects (only first word is marked) and black objects (all
    // words are marked).
    ASSERT(size > sizeof(uword));
    int mask_shift = ((reinterpret_cast<uword>(object) >> kWordShift) & 31);
    size_t size_in_words = size >> kWordShift;
    // Jump to the slow case routine to handle crossing an int32_t boundary.
    if (mask_shift + size_in_words > 31) return SlowMark(object, size);

    uint32 mask = ((1 << size_in_words) - 1) << mask_shift;

    uint32* bits = MarkBitsFor(object);
    *bits |= mask;
  }

  static int heap_allocation_arena() {
    return singleton_.heap_allocation_arena_;
  }

  static uword lowest_old_space_address() { return singleton_.lowest_address_; }

  static uword heap_extent() { return singleton_.heap_extent_; }

  static bool InMetadataRange(uword start) {
    uword lowest = singleton_.lowest_address_;
    return start >= lowest && start - lowest < singleton_.heap_extent_;
  }

  static uword remembered_set_bias() { return singleton_.remembered_set_bias_; }

  // Unaligned, so cannot clash with a real object start.
  static const int kNoObjectStart = 2;

  // We need to track the start of an object for each card, so that we can
  // iterate just part of the heap.  This does that for newly allocated objects
  // in old-space.  The cards are less than 256 bytes large (see the assert
  // below), so writing the last byte of the object start address is enough to
  // uniquely identify the address.
  inline static void RecordStart(uword address) {
    uint8* start = StartsFor(address);
    ASSERT(kCardSizeLog2 <= 8);
    *start = static_cast<uint8>(address);
  }

  // An object at this address may contain a pointer from old-space to
  // new-space.
  inline static void InsertIntoRememberedSet(uword address) {
    address >>= kCardSizeLog2;
    address += singleton_.remembered_set_bias_;
    *reinterpret_cast<uint8*>(address) = kNewSpacePointers;
  }

  // May this card contain pointers from old-space to new-space?
  inline static bool IsMarkedDirty(uword address) {
    address >>= kCardSizeLog2;
    address += singleton_.remembered_set_bias_;
    return *reinterpret_cast<uint8*>(address) != kNoNewSpacePointers;
  }

  // The object was marked grey and we tried to push it on the mark stack, but
  // the stack overflowed. Here we record enough information that we can find
  // these objects later.
  static void MarkStackOverflow(HeapObject* object);

 private:
  GCMetadata() {}
  ~GCMetadata() {}

  static GCMetadata singleton_;

  void SetupSingleton();

  static void SlowMark(HeapObject* object, size_t size);

  // Heap metadata (remembered set etc.).
  uword lowest_address_;
  uword heap_extent_;
  uword number_of_cards_;
  uword metadata_size_;
  int heap_allocation_arena_;
  unsigned char* metadata_;
  unsigned char* remembered_set_;
  unsigned char* object_starts_;
  uint32* mark_bits_;
  uint8_t* mark_stack_overflow_bits_;
  uword starts_bias_;
  uword remembered_set_bias_;
  uword mark_bits_bias_;
  uword overflow_bits_bias_;
};

}  // namespace dartino

#endif  // SRC_VM_GC_METADATA_H_

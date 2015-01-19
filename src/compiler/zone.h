// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_ZONE_H_
#define SRC_COMPILER_ZONE_H_

#include "src/compiler/allocation.h"
#include "src/shared/utils.h"

namespace fletch {

// Zones support very fast allocation of small chunks of memory. The
// chunks cannot be deallocated individually, but instead zones
// support deallocating all chunks in one fast operation.
class Zone : public StackResource {
 public:
  // Create an empty zone and set is at the default zone in the thread.
  Zone();

  // Delete all memory associated with the zone.
  ~Zone();

  // Allocate 'size' bytes of memory in the zone; expands the zone by
  // allocating new segments of memory on demand using malloc().
  inline void* Allocate(int size);

  // Allocate an object in the zone.
  template<typename T> T* New() { return static_cast<T*>(Allocate(sizeof(T))); }

  // Delete all objects and free all memory allocated in the zone.
  void DeleteAll();

  // Get the number of total zone-allocated bytes.
  // This is always 0 in release mode.
  static uword allocated() { return allocated_; }

 private:
  // Zone segments are internal data structures used to hold information
  // about the memory segmentations that constitute a zone. The entire
  // implementation is in zone.cc.
  class Segment;

  // The current head segment; may be NULL.
  Segment* head_;

  // The free region in the current (head) segment is represented as
  // the half-open interval [position, limit). The 'position' variable
  // is guaranteed to be aligned as dictated by kAlignment.
  uword position_;
  uword limit_;

  // All pointers returned from New() have this alignment.
  static const int kAlignment = kPointerSize;

  // Never expand with segments smaller than this size in bytes.
  static const int kMinimumSegmentSize = 64 * KB;

  // Do not allocate segments larger than this size in bytes unless
  // explicitly requested to do so for a single large allocation.
  static const int kMaximumSegmentSize = 1 * MB;

  // Expand the zone to accommodate an allocation of 'size' bytes.
  uword AllocateExpand(int size);

  static uword allocated_;
};

inline void* Zone::Allocate(int size) {
  // Round up the requested size to fit the alignment.
  size = Utils::RoundUp(size, kAlignment);

  // Check if the requested size is available without expanding.
  uword result = position_;
  if ((position_ += size) > limit_) result = AllocateExpand(size);

#ifdef DEBUG
  allocated_ += size;
#endif

  // Check that the result has the proper alignment and return it.
  ASSERT(Utils::IsAligned(result, kAlignment));
  return reinterpret_cast<void*>(result);
}

}  // namespace fletch

#endif  // SRC_COMPILER_ZONE_H_

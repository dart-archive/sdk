// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/zone.h"

#include <stdlib.h>
#include <string.h>

#include "src/shared/assert.h"
#include "src/shared/utils.h"

namespace fletch {

uword Zone::allocated_ = 0;

// Zone segments represent chunks of memory: They have starting
// address encoded in the this pointer and a size in bytes. They are
// chained together to form the backing storage for an expanding zone.
class Zone::Segment {
 public:
  Segment* next() const { return next_; }
  int size() const { return size_; }

  uword start() { return address(sizeof(Segment)); }
  uword end() { return address(size_); }

  // Allocate or delete individual segments.
  static Segment* New(int size, Segment* next);
  static void Delete(Segment* segment) { free(segment); }

 private:
  Segment* next_;
  int size_;

  // Computes the address of the nth byte in this segment.
  uword address(int n) { return reinterpret_cast<uword>(this) + n; }

  DISALLOW_IMPLICIT_CONSTRUCTORS(Segment);
};

Zone::Segment* Zone::Segment::New(int size, Zone::Segment* next) {
  Segment* result = reinterpret_cast<Segment*>(malloc(size));
  if (result != NULL) {
    result->next_ = next;
    result->size_ = size;
  }
  return result;
}

Zone::Zone()
    : head_(NULL),
      position_(0),
      limit_(0) {
}

Zone::~Zone() {
  DeleteAll();
}

void Zone::DeleteAll() {
#ifdef DEBUG
  if (position_ < limit_) {
    allocated_ -= position_ - Utils::RoundUp(head_->start(), kAlignment);
  }
#endif
  // Traverse the chained list of segments, zapping (in debug mode)
  // and freeing every zone segment.
  Segment* current = head_;
  while (current != NULL) {
    Segment* next = current->next();
#ifdef DEBUG
    if (current != head_) {
      allocated_ -=
          current->end() - Utils::RoundUp(current->start(), kAlignment);
    }
    // Zap the entire current segment (including the header).
    static const unsigned char kZapDeadByte = 0xcd;
    memset(current, kZapDeadByte, current->size());
#endif
    Segment::Delete(current);
    current = next;
  }

  // Reset zone state.
  head_ = NULL;
  position_ = limit_ = 0;
}

uword Zone::AllocateExpand(int size) {
  // Make sure the requested size is already properly aligned and that
  // there isn't enough room in the Zone to satisfy the request.
  ASSERT(size == Utils::RoundDown(size, kAlignment));
  ASSERT(position_ > limit_);

#ifdef DEBUG
  // The remaining of the segment will continue to be unused.
  if ((position_ - size) < limit_) {
    allocated_ += limit_ - (position_ - size);
  }
#endif

  // Compute the new segment size. We use a 'high water mark'
  // strategy, where we increase the segment size every time we
  // expand. This is to avoid excessive malloc() and free() overhead.
  static const int kSegmentOverhead = sizeof(Segment) + kAlignment;
  Segment* head = head_;
  int old_size = (head == NULL) ? 0 : head->size();
  int new_size = kSegmentOverhead + size + (old_size << 1);
  if (new_size < kMinimumSegmentSize) {
    new_size = kMinimumSegmentSize;
  } else if (new_size > kMaximumSegmentSize) {
    // Do not allocate too large segments unless explicitly requested.
    new_size = Utils::Maximum(kMaximumSegmentSize, size + kSegmentOverhead);
  }

  // Create a new head segment and replace the old one.
  head_ = head = Segment::New(new_size, head);

  // Recompute 'top' and 'limit' based on the new head segment.
  uword result = Utils::RoundUp(head->start(), kAlignment);
  position_ = result + size;
  limit_ = head->end();
  ASSERT(position_ <= limit_);
  return result;
}

}  // namespace fletch

// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_STOREBUFFER_H_
#define SRC_VM_STOREBUFFER_H_

#include "src/vm/object.h"
#include "src/vm/object_memory.h"

namespace fletch {

class StoreBuffer;

class StoreBufferChunk {
 public:
  static const int kStoreBufferSize = 1024;

  explicit StoreBufferChunk(StoreBufferChunk* chunk = NULL)
      : next_(chunk), pos_(0) {}

  void IteratePointersToImmutableSpace(PointerVisitor* visitor);

  void IterateObjects(HeapObjectVisitor* visitor);

  StoreBufferChunk* next() { return next_; }
  void set_next(StoreBufferChunk* next) { ASSERT(next_ == NULL); next_ = next; }

  bool is_empty() const { return pos_ == 0; }

 private:
  friend class StoreBuffer;

  bool Insert(HeapObject* object) {
    ASSERT(pos_ < kStoreBufferSize);
    objects_[pos_++] = object;
    return pos_ == kStoreBufferSize;
  }

  void Scramble();

  StoreBufferChunk* next_;
  HeapObject* objects_[kStoreBufferSize];
  int pos_;
};

class StoreBuffer {
 public:
  explicit StoreBuffer(bool empty = false)
      : current_chunk_(empty ? NULL : new StoreBufferChunk()),
        last_chunk_(current_chunk_),
        number_of_chunks_(empty ? 0 : 1),
        number_of_chunks_in_last_gc_(empty ? 0 : 1) {}

  ~StoreBuffer();

  void Insert(HeapObject* object) {
    bool is_full = current_chunk_->Insert(object);
    if (is_full) {
      current_chunk_ = new StoreBufferChunk(current_chunk_);
      number_of_chunks_++;
    }
  }

  void IteratePointersToImmutableSpace(PointerVisitor* visitor);

  void IterateObjects(HeapObjectVisitor* visitor);

  // After a mutable GC this function will replace the current storebuffer
  // entries with the ones collected during a mutable GC.
  void ReplaceAfterMutableGC(StoreBuffer* new_store_buffer);

  // Prepend all entries in [store_buffer] to [this] store buffer.
  void Prepend(StoreBuffer* store_buffer);

  // Deduplicate the storebuffer (does not necessarily produce a minimal set).
  // WARNING: This uses forwarding words.
  void Deduplicate();

  // If the references from mutable to immutable heap have doubled since
  // the last GC we will signal that another Mutable GC would be good.
  bool ShouldDeduplicate() {
    return number_of_chunks_ > 2 * number_of_chunks_in_last_gc_;
  }

  bool is_empty() const {
    if (number_of_chunks_ == 0) return true;
    return number_of_chunks_ == 1 &&
           current_chunk_->is_empty();
  }

 private:
  StoreBufferChunk* TakeChunks() {
    StoreBufferChunk* chunk = current_chunk_;
    current_chunk_ = NULL;
    last_chunk_ = NULL;
    number_of_chunks_ = 0;
    number_of_chunks_in_last_gc_ = 0;
    return chunk;
  }

  StoreBufferChunk* current_chunk_;
  StoreBufferChunk* last_chunk_;
  int number_of_chunks_;
  int number_of_chunks_in_last_gc_;
};

// Records pointers to an immutable space.
class FindImmutablePointerVisitor: public PointerVisitor {
 public:
  FindImmutablePointerVisitor(Space* mutable_space, Space* program_space)
      : mutable_space_(mutable_space),
        program_space_(program_space),
        had_immutable_pointer_(false) {}

  bool ContainsImmutablePointer(HeapObject* object) {
    had_immutable_pointer_ = false;
    object->IteratePointers(this);
    return had_immutable_pointer_;
  }

  virtual void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) {
      Object* object = *p;
      if (object->IsHeapObject()) {
        uword address = HeapObject::cast(object)->address();
        if (!mutable_space_->Includes(address) &&
            !program_space_->Includes(address)) {
          ASSERT(object->IsImmutable());
          had_immutable_pointer_ = true;
          return;
        }
      }
    }
  }

 private:
  Space* mutable_space_;
  Space* program_space_;
  bool had_immutable_pointer_;
};

}  // namespace fletch

#endif  // SRC_VM_STOREBUFFER_H_

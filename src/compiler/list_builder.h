// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_LIST_BUILDER_H_
#define SRC_COMPILER_LIST_BUILDER_H_

#include <string.h>
#include "src/compiler/allocation.h"
#include "src/compiler/list.h"
#include "src/compiler/zone.h"

namespace fletch {

// The list builder is used to build zone-allocated lists. It allows
// appending elements in constant time, and constructing the resulting
// list in linear time. The template parameter N is used to indicate
// the chunk size and it must be a power of two. If it is one, the
// implementation is a simple linked list of elements.
template<typename T, int N>
class ListBuilder : public StackAllocated {
 public:
  explicit ListBuilder(Zone* zone)
      : zone_(zone), length_(0), cursor_(locals_.elements) {
    ASSERT(Utils::IsPowerOfTwo(N));
    locals_.next = locals_.previous = NULL;
  }

  Zone* zone() const { return zone_; }
  bool is_empty() const { return length_ == 0; }
  int length() const { return length_; }
  T last() const { ASSERT(length() > 0); return *(cursor_ - 1); }

  // Appends an element to the builder. The first N elements will go
  // into the local stack-allocated chunk, but further elements will
  // be allocated in the zone in chunks of N elements.
  void Add(T element);

  // Removes the last element from the builder.
  T RemoveLast();

  // Slow operations for random access.
  T Get(int index) { return *ComputeSlot(index); }
  void Set(int index, T element) { *ComputeSlot(index) = element; }

  // Constructs a list of the current elements in the builder. It's
  // safe to call this operation multiple times on the same builder.
  List<T> ToList(Zone* zone = NULL);

  // Clears the list builder, but keeps the currently allocated
  // chunks around for reuse.
  void Clear();

  // Clears and reset the list builder to a new zone.
  void Reset(Zone* zone);

 private:
  struct Chunk {
    Chunk* next;
    Chunk* previous;
    T elements[N];
  };

  Zone* zone_;        // Zone used for allocating chunks.
  int length_;        // Number of elements in the builder.
  T* cursor_;         // Points to the next element slot to be written to.

  // To avoid allocating all elements in the zone, we keep the first
  // chunk of elements locally in the builder object.
  Chunk locals_;

  // Given an element index in the current chunk, we can compute the
  // current chunk from the cursor.
  Chunk* ComputeCurrentFromCursor(int index) {
    uword cursor = reinterpret_cast<uword>(cursor_);
    uword chunk = cursor - OFFSET_OF(Chunk, elements[index]);
    return reinterpret_cast<Chunk*>(chunk);
  }

  // Compute the slot for the given index.
  T* ComputeSlot(int index);

  DISALLOW_COPY_AND_ASSIGN(ListBuilder);
};

template<typename T, int N>
void ListBuilder<T, N>::Add(T value) {
  // If the length is a multiple of N and not zero, we know that the
  // current chunk is full. Go ahead and allocate a new chunk and
  // start adding elements to that one instead.
  if (length_ != 0 && Utils::IsAligned(length_, N)) {
    Chunk* current = ComputeCurrentFromCursor(N);
    Chunk* next = current->next;
    if (next == NULL) {
      next = zone_->New<Chunk>();
      next->next = NULL;
      next->previous = current;
      current->next = next;
    }
    cursor_ = next->elements;
  }
  // Set the value through the cursor and update both the length and
  // the cursor to be ready for the next element.
  *cursor_++ = value;
  length_++;
}

template<typename T, int N>
T ListBuilder<T, N>::RemoveLast() {
  ASSERT(length_ > 0);
  length_--;
  T result = *(--cursor_);
  if (length_ != 0 && Utils::IsAligned(length_, N)) {
    Chunk* current = ComputeCurrentFromCursor(0);
    Chunk* previous = current->previous;
    ASSERT(previous != NULL);
    cursor_ = &previous->elements[N];
  }
  return result;
}

template<typename T, int N>
List<T> ListBuilder<T, N>::ToList(Zone* zone) {
  if (zone == NULL) zone = zone_;
  // Allocate array of elements with just the right size in the zone.
  T* result = static_cast<T*>(zone->Allocate(length_ * sizeof(T)));
  // Traverse the chain of chunks and copy all the elements into the
  // resulting array.
  Chunk* chunk = &locals_;
  int index = 0;
  while (index + N < length_) {
    memcpy(&result[index], chunk->elements, N * sizeof(T));
    chunk = chunk->next;
    index += N;
  }
  // Copy the remaining elements to the last part of the result and
  // return a list.
  int remaining = length_ - index;
  memcpy(&result[index], chunk->elements, remaining * sizeof(T));
  return List<T>(result, length_);
}

template<typename T, int N>
void ListBuilder<T, N>::Clear() {
  length_ = 0;
  cursor_ = locals_.elements;
}

template<typename T, int N>
void ListBuilder<T, N>::Reset(Zone* zone) {
  length_ = 0;
  cursor_ = locals_.elements;
  locals_.next = NULL;
  locals_.previous = NULL;
  zone_ = zone;
}

template<typename T, int N>
T* ListBuilder<T, N>::ComputeSlot(int index) {
  ASSERT(0 <= index && index < length_);
  Chunk* chunk;
  // Check if the requested element closer to the first chunk or
  // the last chunk and start the chunk search from the right end.
  int start = Utils::RoundDown(length_ - 1, N);
  if (index > (start >> 1)) {
    chunk = ComputeCurrentFromCursor(length_ - start);
    for (int i = start; index < i; i -= N) chunk = chunk->previous;
  } else {
    chunk = &locals_;
    for (int i = 0; index >= i + N; i += N) chunk = chunk->next;
  }
  // Return a pointer to the requested element. Here we rely on N
  // being a power of two to make the modulo operation efficient.
  ASSERT(Utils::IsPowerOfTwo(N));
  return &chunk->elements[index & (N - 1)];
}

}  // namespace fletch

#endif  // SRC_COMPILER_LIST_BUILDER_H_

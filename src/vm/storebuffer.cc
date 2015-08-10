// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/storebuffer.h"

namespace fletch {

void StoreBufferChunk::IteratePointersToImmutableSpace(
    PointerVisitor* visitor) {
  for (int i = 0; i < pos_; i++) {
    objects_[i]->IteratePointers(visitor);
  }
}

void StoreBufferChunk::IterateObjects(HeapObjectVisitor* visitor) {
  for (int i = 0; i < pos_; i++) {
    visitor->Visit(objects_[i]);
  }
}

void StoreBufferChunk::Scramble() {
  memset(static_cast<void*>(objects_),
         0xbe,
         kStoreBufferSize * sizeof(HeapObject *));
}

StoreBuffer::~StoreBuffer() {
  StoreBufferChunk* chunk = current_chunk_;
  while (chunk != NULL) {
    StoreBufferChunk* next = chunk->next();
#ifdef DEBUG
    chunk->Scramble();
#endif
    delete chunk;
    chunk = next;
  }
}

void StoreBuffer::Prepend(StoreBuffer* store_buffer) {
  number_of_chunks_ += store_buffer->number_of_chunks_;
  number_of_chunks_in_last_gc_ += store_buffer->number_of_chunks_in_last_gc_;

  StoreBufferChunk* last = store_buffer->last_chunk_;
  ASSERT(last->next() == NULL);
  StoreBufferChunk* chunks = store_buffer->TakeChunks();
  if (current_chunk_ == NULL) {
    ASSERT(last_chunk_ == NULL);
    last_chunk_ = last;
  } else {
    ASSERT(last_chunk_ != NULL);
    last->set_next(current_chunk_);
  }
  current_chunk_ = chunks;
}

void StoreBuffer::IteratePointersToImmutableSpace(PointerVisitor* visitor) {
  StoreBufferChunk* chunk = current_chunk_;
  while (chunk != NULL) {
    chunk->IteratePointersToImmutableSpace(visitor);
    chunk = chunk->next();
  }
}

void StoreBuffer::IterateObjects(HeapObjectVisitor* visitor) {
  StoreBufferChunk* chunk = current_chunk_;
  while (chunk != NULL) {
    chunk->IterateObjects(visitor);
    chunk = chunk->next();
  }
}

void StoreBuffer::ReplaceAfterMutableGC(StoreBuffer* new_store_buffer) {
  StoreBufferChunk* current = current_chunk_;
  while (current != NULL) {
    StoreBufferChunk* next = current->next();
#ifdef DEBUG
    current->Scramble();
#endif
    delete current;
    current = next;
  }
  number_of_chunks_ = new_store_buffer->number_of_chunks_;
  number_of_chunks_in_last_gc_ = number_of_chunks_;
  last_chunk_ = new_store_buffer->last_chunk_;
  ASSERT(last_chunk_->next() == NULL);
  current_chunk_ = new_store_buffer->TakeChunks();
}

}  // namespace fletch

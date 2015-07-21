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
  number_of_chunks_in_last_gc = number_of_chunks_;
  current_chunk_ = new_store_buffer->TakeChunks();
}

}  // namespace fletch

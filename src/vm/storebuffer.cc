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

static bool IsMarked(Class* klass) {
  uword value = reinterpret_cast<uword>(klass);
  return ((value & HeapObject::kTagMask) != HeapObject::kTag);
}

static Class* Mark(Class* klass) {
  uword value = reinterpret_cast<uword>(klass);
  return reinterpret_cast<Class*>(value & ~HeapObject::kTag);
}

static Class* Unmark(Class* untagged_klass) {
  uword value = reinterpret_cast<uword>(untagged_klass);
  return reinterpret_cast<Class*>(value | HeapObject::kTag);
}

void StoreBuffer::Deduplicate() {
  ASSERT(current_chunk_ != NULL);

  StoreBufferChunk* read = current_chunk_;
  StoreBufferChunk* write = current_chunk_;
  int read_offset = 0;
  int write_offset = 0;
  int written_chunks = 1;

  // Deduplicate all objects - uses tagging bit of class pointer as marking
  // bit.
  while (read != NULL) {
    if (read_offset >= read->pos_) {
      read_offset = 0;
      read = read->next();
      if (read == NULL) break;
    }

    HeapObject* current = read->objects_[read_offset++];
    Class* klass = current->raw_class();

    // If this object is not yet in the write buffer, add it.
    if (!IsMarked(klass)) {
      current->set_class(Mark(klass));

      if (write_offset >= StoreBufferChunk::kStoreBufferSize) {
        write->pos_ = write_offset;
        write = write->next();
        write_offset = 0;
        written_chunks++;
      }

      // Add the object to the de-duplicated list.
      write->objects_[write_offset++] = current;
    }
  }

  // Free the tail of unused chunks.
  StoreBufferChunk* to_be_freed = write->next();
  while (to_be_freed != NULL) {
    StoreBufferChunk* next = to_be_freed->next();
    delete to_be_freed;
    to_be_freed = next;
  }

  // Update metadata of last chunk & metadata of storebuffer.
  write->pos_ = write_offset;
  write->next_ = NULL;
  last_chunk_ = write;
  number_of_chunks_ = written_chunks;
  number_of_chunks_in_last_gc_ = written_chunks;

  // Tag class pointers again.
  read = current_chunk_;
  read_offset = 0;
  while (read != NULL) {
    if (read_offset >= read->pos_) {
      read_offset = 0;
      read = read->next();
      if (read == NULL) break;
    }
    HeapObject* current = read->objects_[read_offset++];
    Class* marked_klass = current->raw_class();

    // Restore the original class pointer again.
    ASSERT(IsMarked(marked_klass));
    current->set_class(Unmark(marked_klass));
  }

  // In case the storebuffer is full now, we need to allocate a new chunk.
  // TODO(kustermann): Try avoid allocating a new chunk and instead use the
  // last one (if there is space). Most likely we should just allocate at the
  // end, not at the front.
  if (current_chunk_->pos_ >= StoreBufferChunk::kStoreBufferSize) {
    current_chunk_ = new StoreBufferChunk(current_chunk_);
    number_of_chunks_++;
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
  number_of_chunks_in_last_gc_ = number_of_chunks_;
  last_chunk_ = new_store_buffer->last_chunk_;
  ASSERT(last_chunk_->next() == NULL);
  current_chunk_ = new_store_buffer->TakeChunks();
}

}  // namespace fletch

// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "struct.h"

#include <stdlib.h>
#include <stddef.h>

MessageBuilder::MessageBuilder(int space)
    : first_(this, 0, space),
      last_(&first_),
      segments_(1) {
}

int MessageBuilder::ComputeUsed() const {
  int result = 0;
  const BuilderSegment* current = &first_;
  while (current != NULL) {
    result += current->used();
    current = current->next();
  }
  return result;
}

Builder MessageBuilder::InternalInitRoot(int size) {
  int offset = first_.Allocate(32 + 8 + size);
  return Builder(&first_, offset + 32 + 8);
}

BuilderSegment* MessageBuilder::FindSegmentForBytes(int bytes) {
  if (last_->HasSpaceForBytes(bytes)) return last_;
  int capacity = (bytes > 8192) ? bytes : 8192;
  BuilderSegment* segment = new BuilderSegment(this, segments_++, capacity);
  last_->set_next(segment);
  last_ = segment;
  return segment;
}

MessageReader::MessageReader(int segments, char* memory)
    : segment_count_(segments),
      segments_(new Segment*[segments]) {
  for (int i = 0; i < segments; i++) {
    int64_t address = *reinterpret_cast<int64_t*>(memory + (i * 16));
    int size = *reinterpret_cast<int*>(memory + 8 + (i * 16));
    segments_[i] = new Segment(this, reinterpret_cast<char*>(address), size);
  }
}

MessageReader::~MessageReader() {
  for (int i = 0; i < segment_count_; ++i) {
    delete segments_[i];
  }
  delete[] segments_;
}

Segment* MessageReader::GetRootSegment(char* memory) {
  // TODO(ager): Just have the segment count instead of a separate
  // segmented marker.
  bool segmented = (*reinterpret_cast<int*>(memory) == 1);
  if (segmented) {
    int segments = *reinterpret_cast<int*>(memory + 4);
    MessageReader* reader = new MessageReader(segments, memory + 8);
    return new Segment(reader);
  } else {
    int size = *reinterpret_cast<int*>(memory + 4);
    return new Segment(memory, size);
  }
}

Segment::Segment(char* memory, int size)
    : reader_(NULL),
      memory_(memory),
      size_(size),
      is_root_(false) {
}

Segment::Segment(MessageReader* reader, char* memory, int size)
    : reader_(reader),
      memory_(memory),
      size_(size),
      is_root_(false) {
}

Segment::Segment(MessageReader* reader)
    : reader_(reader),
      is_root_(true) {
  Segment* first = reader->GetSegment(0);
  memory_ = first->memory();
  size_ = first->size();
}

Segment::~Segment() {
  if (is_root_) {
    delete reader_;
  } else {
    free(memory_);
  }
}

BuilderSegment::BuilderSegment(MessageBuilder* builder, int id, int capacity)
    : Segment(reinterpret_cast<char*>(calloc(capacity, 1)), capacity),
      builder_(builder),
      id_(id),
      next_(NULL),
      used_(0) {
}

BuilderSegment::~BuilderSegment() {
  if (next_ != NULL) {
    delete next_;
    next_ = NULL;
  }
}

int BuilderSegment::Allocate(int bytes) {
  if (!HasSpaceForBytes(bytes)) return -1;
  int result = used_;
  used_ += bytes;
  return result;
}

int64_t Builder::InvokeMethod(ServiceId service, MethodId method) {
  BuilderSegment* segment = this->segment();
  if (!segment->HasNext()) {
    int offset = this->offset() - 40;
    char* buffer = reinterpret_cast<char*>(segment->At(offset));

    // Mark the request as being non-segmented.
    *reinterpret_cast<int64_t*>(buffer + 32) = 0;
    ServiceApiInvoke(service, method, buffer, segment->used());
    return *reinterpret_cast<int64_t*>(buffer + 32);
  }

  // The struct consists of multiple segments, so we send a
  // memory block that contains the addresses and sizes of
  // all of them.
  int segments = segment->builder()->segments();
  int size = 40 + 8 + (segments * 16);
  char* buffer = reinterpret_cast<char*>(malloc(size));
  *reinterpret_cast<int64_t*>(buffer + 40) = segments;
  int offset = 40 + 8;
  do {
    *reinterpret_cast<void**>(buffer + offset) = segment->At(0);
    *reinterpret_cast<int*>(buffer + offset + 8) = segment->used();
    segment = segment->next();
    offset += 16;
  } while (segment != NULL);

  // Mark the request as being segmented.
  *reinterpret_cast<int64_t*>(buffer + 32) = 1;
  ServiceApiInvoke(service, method, buffer, size);
  int64_t result = *reinterpret_cast<int64_t*>(buffer + 32);
  free(buffer);
  return result;
}

Builder Builder::NewStruct(int offset, int size) {
  offset += this->offset();
  BuilderSegment* segment = this->segment();
  while (true) {
    int* lo = reinterpret_cast<int*>(segment->At(offset + 0));
    int* hi = reinterpret_cast<int*>(segment->At(offset + 4));
    int result = segment->Allocate(size);
    if (result >= 0) {
      *lo = (result << 2) | 1;
      *hi = 0;
      return Builder(segment, result);
    }

    BuilderSegment* other = segment->builder()->FindSegmentForBytes(size + 8);
    int target = other->Allocate(8);
    *lo = (target << 2) | 3;
    *hi = other->id();

    segment = other;
    offset = target;
  }
}

Reader Builder::NewList(int offset, int length, int size) {
  offset += this->offset();
  size *= length;
  BuilderSegment* segment = this->segment();
  while (true) {
    int* lo = reinterpret_cast<int*>(segment->At(offset + 0));
    int* hi = reinterpret_cast<int*>(segment->At(offset + 4));
    int result = segment->Allocate(size);
    if (result >= 0) {
      *lo = (result << 2) | 2;
      *hi = length;
      return Reader(segment, result);
    }

    BuilderSegment* other = segment->builder()->FindSegmentForBytes(size + 8);
    int target = other->Allocate(8);
    *lo = (target << 2) | 3;
    *hi = other->id();

    segment = other;
    offset = target;
  }
}

int Reader::ComputeUsed() const {
  MessageReader* reader = segment_->reader();
  int used = 0;
  for (int i = 0; i < reader->segment_count(); i++) {
    used += reader->GetSegment(i)->size();
  }
  return used;
}

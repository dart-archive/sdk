// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#include "person_counter.h"
#include "include/service_api.h"
#include <stdlib.h>

static ServiceId _service_id = kNoServiceId;

void PersonCounter::Setup() {
  _service_id = ServiceApiLookup("PersonCounter");
}

void PersonCounter::TearDown() {
  ServiceApiTerminate(_service_id);
  _service_id = kNoServiceId;
}

static const MethodId _kGetAgeId = reinterpret_cast<MethodId>(1);
static const MethodId _kCountId = reinterpret_cast<MethodId>(2);

static int InvokeHelper(PersonBuilder person, MethodId id) {
  BuilderSegment* segment = person.segment();
  if (!segment->HasNext()) {
    int offset = person.offset() - 40;
    char* buffer = reinterpret_cast<char*>(segment->At(offset));

    // Mark the request as being non-segmented.
    *reinterpret_cast<int*>(buffer + 32) = 0;
    ServiceApiInvoke(_service_id, id, buffer, segment->size());
    return *reinterpret_cast<int*>(buffer + 32);
  }

  // The struct consists of multiple segments, so we send a
  // memory block that contains the addresses and sizes of
  // all of them.
  MessageBuilder* builder = segment->builder();
  int segments = builder->segments();
  int size = 40 + 8 + (segments * 16);
  char* buffer = reinterpret_cast<char*>(malloc(size));
  *reinterpret_cast<int*>(buffer + 40) = segments;
  int offset = 40 + 8;
  do {
    *reinterpret_cast<void**>(buffer + offset) = segment->At(0);
    *reinterpret_cast<int*>(buffer + offset + 8) = segment->size();
    segment = segment->next();
    offset += 16;
  } while (segment != NULL);

  // Mark the request as being segmented.
  *reinterpret_cast<int*>(buffer + 32) = 1;
  ServiceApiInvoke(_service_id, id, buffer, size);
  int result = *reinterpret_cast<int*>(buffer + 32);
  free(buffer);
  return result;
}

int PersonCounter::GetAge(PersonBuilder person) {
  return InvokeHelper(person, _kGetAgeId);
}

int PersonCounter::Count(PersonBuilder person) {
  return InvokeHelper(person, _kCountId);
}

MessageBuilder::MessageBuilder(int space)
    : first_(this, 0, space),
      last_(&first_),
      segments_(1) {
}

Person MessageBuilder::Root() {
  // TODO(kasperl): Mark the person as a root somehow so we know
  // it has a "header" before it.
  return Person(&first_, 40);
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

PersonBuilder MessageBuilder::NewRoot() {
  int offset = first_.Allocate(32 + 8 + Person::kSize);
  return PersonBuilder(&first_, offset + 32 + 8);
}

BuilderSegment* MessageBuilder::FindSegmentForBytes(int bytes) {
  if (last_->HasSpaceForBytes(bytes)) return last_;
  int capacity = (bytes > 8192) ? bytes : 8192;
  BuilderSegment* segment = new BuilderSegment(this, segments_++, capacity);
  last_->set_next(segment);
  last_ = segment;
  return segment;
}

Segment::Segment(char* memory, int size)
    : memory_(memory),
      size_(size) {
}

BuilderSegment::BuilderSegment(MessageBuilder* builder, int id, int capacity)
    : Segment(static_cast<char*>(calloc(capacity, 1)), capacity),
      builder_(builder),
      id_(id),
      next_(NULL),
      used_(0) {
}

BuilderSegment::~BuilderSegment() {
  free(memory());
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

List<PersonBuilder> PersonBuilder::NewChildren(int length) {
  int bytes = PersonBuilder::kSize * length;
  int offset = offset_ + Person::kChildrenOffset;
  BuilderSegment* segment = segment_;
  while (true) {
    int* lo = reinterpret_cast<int*>(segment->At(offset + 0));
    int* hi = reinterpret_cast<int*>(segment->At(offset + 4));
    int list = segment->Allocate(bytes);
    if (list >= 0) {
      *lo = (list << 1) | 0;
      *hi = length;
      return List<PersonBuilder>(segment, list);
    }

    BuilderSegment* other = segment->builder()->FindSegmentForBytes(bytes + 8);
    int target = other->Allocate(8);
    *lo = (target << 1) | 1;
    *hi = other->id();

    segment = other;
    offset = target;
  }
}

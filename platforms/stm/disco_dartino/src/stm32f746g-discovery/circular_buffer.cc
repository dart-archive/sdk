// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "platforms/stm/disco_dartino/src/stm32f746g-discovery/circular_buffer.h"

#include <stdlib.h>
#include <string.h>

CircularBuffer::CircularBuffer(size_t capacity) {
  // One additional byte needed to distinguish between empty and full.
  capacity_ = capacity + 1;
  buffer_ = new uint8_t[capacity_];
  head_ = tail_ = 0;
}

CircularBuffer::~CircularBuffer() {
  delete[] buffer_;
}

bool CircularBuffer::IsEmpty() {
  return head_ == tail_;
}

bool CircularBuffer::IsFull() {
  return ((head_ + 1) % capacity_) == tail_;
}

size_t CircularBuffer::Read(uint8_t* data, size_t count) {
  int bytes;
  int read = 0;

  if (tail_ > head_) {
    bytes = MIN(capacity_ - tail_, count);
    memcpy(data, buffer_ + tail_, bytes);
    read = bytes;
    tail_ = (tail_ + bytes) % capacity_;
  }

  if (tail_ < head_) {
    bytes = MIN(head_ - tail_, count - read);
    memcpy(data + read, buffer_ + tail_, bytes);
    read += bytes;
    tail_ = (tail_ + bytes) % capacity_;
  }

  return read;
}

size_t CircularBuffer::Write(const uint8_t* data, size_t count) {
  int bytes;
  int written = 0;

  if (head_ >= tail_) {
    bytes = (capacity_ - head_) - (tail_ == 0 ? 1 : 0);
    bytes = MIN(bytes, count);
    memcpy(buffer_ + head_, data, bytes);
    written = bytes;
    head_ = (head_ + bytes) % capacity_;
  }

  if (head_ < tail_) {
    bytes =  MIN(tail_ - head_ - 1, count - written);
    memcpy(buffer_ + head_, data + written, bytes);
    written += bytes;
    head_ = (head_ + bytes) % capacity_;
  }

  return written;
}

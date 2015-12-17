// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_FLETCH_SRC_CIRCULAR_BUFFER_H_
#define PLATFORMS_STM_DISCO_FLETCH_SRC_CIRCULAR_BUFFER_H_

#include <inttypes.h>
#include <stdlib.h>

#include "src/shared/platform.h"

#define MIN(a, b) ((a) < (b) ? (a) : (b))

// Circular buffer holding bytes.
class CircularBuffer {
 public:
  enum Blocking {
    kDontBlock,
    kBlock,
  };

  // Create a new circular buffer holding up to 'capacity' bytes of
  // data.
  explicit CircularBuffer(size_t capacity);
  ~CircularBuffer();

  // Returns whether the buffer is empty.
  bool IsEmpty();

  // Returns whether the buffer is full.
  bool IsFull();

  // Read up to count bytes into buffer. If block is kBlock the call
  // will not return until at least one byte is read.
  size_t Read(uint8_t* buffer, size_t count, Blocking block);

  // Write up to count bytes from buffer. If block is kBlock the call
  // will not return until at least one byte is written.
  size_t Write(uint8_t* buffer, size_t count, Blocking block);

 private:
  fletch::Monitor* monitor_;
  int waiting_;
  uint8_t* buffer_;
  size_t capacity_;
  int head_;
  int tail_;
};

#endif  // PLATFORMS_STM_DISCO_FLETCH_SRC_CIRCULAR_BUFFER_H_

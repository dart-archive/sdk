// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_CIRCULAR_BUFFER_H_
#define SRC_FREERTOS_CIRCULAR_BUFFER_H_

#include <inttypes.h>
#include <stdlib.h>

#include "src/shared/platform.h"

#define MIN(a, b) ((a) < (b) ? (a) : (b))

// Circular buffer holding bytes.
// TODO(sigurdm): Make lock free with atomic head and tail.
class CircularBuffer {
 public:
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
  size_t Read(uint8_t* buffer, size_t count);

  // Write up to count bytes from buffer. If block is kBlock the call
  // will not return until at least one byte is written.
  size_t Write(const uint8_t* buffer, size_t count);

 private:
  int waiting_;
  uint8_t* buffer_;
  size_t capacity_;
  size_t  head_;
  size_t  tail_;
};

#endif  // SRC_FREERTOS_CIRCULAR_BUFFER_H_

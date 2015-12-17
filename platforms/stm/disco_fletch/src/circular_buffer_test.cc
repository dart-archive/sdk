// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <cinttypes>

#define TESTING
#include "src/shared/assert.h"
#include "src/shared/atomic.h"

#include "circular_buffer.h"

void compare_buffers(uint8_t* buffer1, uint8_t* buffer2, int size) {
  for (int i = 0; i < size; i++) {
    EXPECT_EQ(buffer1[i], buffer2[i]);
  }
}

// This test will alternate between write and read, and always try to write
// 'to_write' bytes and read 'to_read' bytes. This will continue until 1000
// bytes have been both written and read.
void write_read_test(int to_write, int to_read) {
  const int size = 1000;
  uint8_t* write_data = new uint8_t[size];
  uint8_t* read_data = new uint8_t[size];
  for (int i = 0; i < size; i++) {
    write_data[i] = i % 0xff;
  }

  const int buffer_size = 100;
  CircularBuffer* cb = new CircularBuffer(buffer_size + 1);

  for (int i = 0; i < size; i++) {
    read_data[i] = 0;
  }

  int buffer_content = 0;
  int total_written = 0;
  int total_read = 0;
  while (total_written < size || total_read < size) {
    int bytes = MIN(to_write, size - total_written);
    int written = cb->Write(
        write_data + total_written, bytes, CircularBuffer::kDontBlock);
    EXPECT_LE(written, bytes);
    EXPECT_LE(written, buffer_size - buffer_content);
    total_written += written;
    buffer_content += written;
    EXPECT_LE(buffer_content, buffer_size);
    if (buffer_content == buffer_size) {
      EXPECT(cb->IsFull());
      EXPECT_EQ(0, cb->Write(write_data + total_written,
                             bytes,
                             CircularBuffer::kDontBlock));
    }

    int read =
        cb->Read(read_data + total_read, to_read, CircularBuffer::kDontBlock);
    EXPECT_LE(read, to_read);
    EXPECT_LE(read, buffer_content);
    total_read += read;
    buffer_content -= read;
    EXPECT_GE(buffer_content, 0);
    if (buffer_content == 0) {
      EXPECT(cb->IsEmpty());
      EXPECT_EQ(0, cb->Read(read_data + total_read,
                            to_read,
                            CircularBuffer::kDontBlock));
    }
  }
  compare_buffers(write_data, read_data, size);
}

// This test will alternate between writing and reading the full
// capacity of the buffer.
void write_test() {
  const int buffer_size = 100;
  uint8_t* write_data = new uint8_t[buffer_size];
  uint8_t* read_data = new uint8_t[buffer_size];
  for (int i = 0; i < buffer_size; i++) {
    write_data[i] = i % 0xff;
  }
  for (int i = 0; i < buffer_size; i++) {
    read_data[i] = 0;
  }

  CircularBuffer* cb = new CircularBuffer(buffer_size + 1);

  for (int i = 0; i < buffer_size; i++) {
    EXPECT_EQ(buffer_size,
              cb->Write(write_data, buffer_size, CircularBuffer::kDontBlock));
    EXPECT(cb->IsFull());
    EXPECT_EQ(buffer_size,
              cb->Read(read_data, buffer_size, CircularBuffer::kDontBlock));
    EXPECT(cb->IsEmpty());

    compare_buffers(write_data, read_data, buffer_size);
  }
}

int main(int argc, char** argv) {
  write_test();

  for (int i = 1; i < 10; i++) {
    for (int j = 1; j < 10; j++) {
      write_read_test(i, j);
    }
  }
}

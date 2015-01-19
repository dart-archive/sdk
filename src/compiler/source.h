// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_SOURCE_H_
#define SRC_COMPILER_SOURCE_H_

#include "src/compiler/list_builder.h"
#include "src/compiler/zone.h"

namespace fletch {

class Location {
  static const uint32 kInvalid = 0xFFFFFFFF;

 public:
  Location() : value_(kInvalid) {
  }

  Location operator+(uint32 offset) {
    return Location(value_ + offset);
  }

  uint32 raw() const { return value_; }

  bool IsInvalid() const { return value_ == kInvalid; }

 private:
  explicit Location(uint32 value) : value_(value) {
  }

  uint32 value_;

  friend class Source;
};

class Source : public StackAllocated {
  static const int kChunkBits = 12;
  static const int kChunkSize = 1 << kChunkBits;

 public:
  explicit Source(Zone* zone);

  Location LoadFile(const char* path);
  Location LoadFromBuffer(const char* path, const char* source, uint32 size);

  const char* GetSource(Location location);
  const char* GetFilePath(Location location);
  const char* GetLine(Location location, int* line_length);

 private:
  class Chunk {
   public:
    const char* file_path;
    const char* file_start;
    uint32 chunk_offset;
  };

  ListBuilder<Chunk, 8> chunks_;
};

}  // namespace fletch

#endif  // SRC_COMPILER_SOURCE_H_

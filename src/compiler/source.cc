// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <cstdlib>
#include <cstdarg>

#include "src/shared/assert.h"
#include "src/compiler/os.h"
#include "src/compiler/builder.h"
#include "src/compiler/parser.h"

namespace fletch {

Source::Source(Zone* zone)
    : chunks_(zone) {
}

Location Source::LoadFile(const char* path) {
  uint32 size = 0;
  const char* data = OS::LoadFile(path, NULL, &size);
  if (data == NULL) return Location();
  return LoadFromBuffer(path, data, size);
}

Location Source::LoadFromBuffer(const char* path,
                                const char* source,
                                uint32 size) {
  Location location(chunks_.length() * kChunkSize);
  for (uint32 i = 0; i < size; i += kChunkSize) {
    Chunk chunk;
    chunk.file_path = path;
    chunk.file_start = source;
    chunk.chunk_offset = i;
    chunks_.Add(chunk);
  }
  return location;
}

const char* Source::GetSource(Location location) {
  if (location.IsInvalid()) return "<Invalid location>";
  uint32 index = location.raw() >> kChunkBits;
  Chunk chunk = chunks_.Get(index);
  return chunk.file_start +
      chunk.chunk_offset +
      (location.raw() & (kChunkSize - 1));
}

const char* Source::GetFilePath(Location location) {
  if (location.IsInvalid()) return "<Invalid location>";
  uint32 index = location.raw() >> kChunkBits;
  Chunk chunk = chunks_.Get(index);
  return chunk.file_path;
}

const char* Source::GetLine(Location location, int* line_length) {
  if (location.IsInvalid()) return "<Invalid location>";
  // TODO(ajohnsen): Cache this.
  uint32 index = location.raw() >> kChunkBits;
  Chunk chunk = chunks_.Get(index);
  const char* pos = chunk.file_start + chunk.chunk_offset;
  pos += location.raw() & (kChunkSize - 1);
  const char* start = pos;
  while (start > chunk.file_start && start[-1] != '\n' && start[-1] != '\r') {
    start--;
  }
  const char* end = pos;
  while (end[0] != 0 && end[0] != '\n' && end[0] != '\r') {
    end++;
  }
  if (line_length != NULL) *line_length = end - start;
  return start;
}

}  // namespace fletch

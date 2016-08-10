// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/freertos/read_only_file_system.h"

#include <errno.h>
#include <stdio.h>

#include <cstdlib>
#include <cstring>

#include "src/freertos/globals.h"

namespace dartino {

ReadOnlyFileSystemDriver::ReadOnlyFileSystemDriver(const uint8_t* data)
    : data_(data) {
  for (int handle = 0; handle < kMaxOpenFiles; handle++) {
    open_files_[handle].MarkClosed();
  }
}

int ReadOnlyFileSystemDriver::Open(const char* path) {
  int path_length = strlen(path);

  // Search for the file.
  uint32_t length;
  size_t file_size;
  const char* file_path;
  uint8_t* p = const_cast<uint8_t*>(data_);

  while (true) {
    // Read length of path.
    length = *reinterpret_cast<uint32_t*>(p);
    if (length == 0) return -ENOENT;
    p += sizeof(uint32_t);
    file_path = reinterpret_cast<const char*>(p);

    // Skip the path.
    p += length;
    p = reinterpret_cast<uint8_t*>(ROUNDUP(reinterpret_cast<uintptr_t>(p), 4));

    // Read the length of the file.
    ASSERT(sizeof(size_t) == 4);
    file_size = *reinterpret_cast<size_t*>(p);
    p += sizeof(size_t);

    // The passed in path has a leading /.
    if (length == static_cast<uint32_t>(path_length) - 1 &&
        memcmp(path + 1, file_path, length) == 0) {
      for (int handle = 0; handle < kMaxOpenFiles; handle++) {
        if (!open_files_[handle].IsOpen()) {
          open_files_[handle].MarkOpen(path, file_size, p);
          return handle;
        }
      }
      // Ran out of open file slots.
      return -EMFILE;
    }

    // Skip the file data.
    p += file_size;
    p = reinterpret_cast<uint8_t*>(ROUNDUP(reinterpret_cast<uintptr_t>(p), 4));
  }
}

int ReadOnlyFileSystemDriver::Close(int handle) {
  if (!IsValidOpenHandle(handle)) return -EBADF;
  open_files_[handle].MarkClosed();
  return 0;
}

int ReadOnlyFileSystemDriver::Read(int handle, void* buffer, size_t length) {
  if (!IsValidOpenHandle(handle)) return -EBADF;
  OpenFile* file = &open_files_[handle];
  size_t bytes_read = MIN(length, file->size - file->position);
  memcpy(buffer, file->data + file->position, bytes_read);
  file->position += bytes_read;
  return bytes_read;
}

int ReadOnlyFileSystemDriver::Write(
    int handle, const void* buffer, size_t length) {
  if (!IsValidOpenHandle(handle)) return -EBADF;
  // Write not supported.
  return -EACCES;
}

int ReadOnlyFileSystemDriver::Seek(int handle, int offset, int direction) {
  if (!IsValidOpenHandle(handle)) return -EBADF;
  OpenFile* file = &open_files_[handle];
  int new_position;
  switch (direction) {
    case SEEK_SET:
      new_position = offset;
      break;
    case SEEK_CUR:
      new_position = file->position + offset;
      break;
    case SEEK_END:
      new_position = file->size - offset;
      break;
    default:
      return -EINVAL;
  }
  if (new_position < 0 || new_position > static_cast<int>(file->size)) {
    return -EINVAL;
  }
  file->position = new_position;
  return new_position;
}

bool ReadOnlyFileSystemDriver::IsValidOpenHandle(int handle) {
  return (handle < kMaxOpenFiles) && (open_files_[handle].IsOpen());
}

void ReadOnlyFileSystemDriver::OpenFile::MarkOpen(
    const char* path, size_t size, uint8_t* data) {
  this->path = path;
  this->size = size;
  this->data = data;
  position = 0;
}

void ReadOnlyFileSystemDriver::OpenFile::MarkClosed() {
  path = NULL;
}

bool ReadOnlyFileSystemDriver::OpenFile::IsOpen() {
  return path != NULL;
}

}  // namespace dartino

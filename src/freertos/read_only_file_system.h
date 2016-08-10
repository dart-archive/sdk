// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_READ_ONLY_FILE_SYSTEM_H_
#define SRC_FREERTOS_READ_ONLY_FILE_SYSTEM_H_

#include "src/freertos/file_system.h"
#include "src/shared/platform.h"

namespace dartino {

class ReadOnlyFileSystemDriver : public FileSystemDriver {
 public:
  explicit ReadOnlyFileSystemDriver(const uint8_t* data);
  int Open(const char* path);
  int Close(int handle);
  int Read(int handle, void* buffer, size_t length);
  int Write(int handle, const void* buffer, size_t length);
  int Seek(int handle, int offset, int direction);

 private:
  bool IsValidOpenHandle(int handle);

  class OpenFile {
   public:
    void MarkOpen(const char* path, size_t size, uint8_t* data);
    void MarkClosed();
    bool IsOpen();

    const char* path;
    size_t size;
    uint8_t* data;
    size_t position;
  };

  static const int kMaxOpenFiles = 20;
  OpenFile open_files_[kMaxOpenFiles];

  // Data for the RO file system. This is in the following format for each file:
  //
  // 4 bytes of path length
  // bytes for the path (aligned to 4 byte boundary)
  // 4 bytes for file length
  // bytes for the file (aligned to 4 byte boundary)
  //
  // Data ends with 4 zero bytes.
  const uint8_t* data_;
};

}  // namespace dartino

#endif  // SRC_FREERTOS_READ_ONLY_FILE_SYSTEM_H_

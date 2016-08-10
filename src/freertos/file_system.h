// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_FILE_SYSTEM_H_
#define SRC_FREERTOS_FILE_SYSTEM_H_

#include "src/shared/platform.h"

namespace dartino {

class FileSystemDriver;

// File system where file system implementations can be mounted.
//
// All methods return a negative errno on failure. The file
// descriptors returned will start at number 3.
class FileSystem {
  class FileSystemMount;

 public:
  static const int kMaxMounts = 3;
  static const int kMaxOpenFiles = 20;

  FileSystem();

  // Mount a file system at the given root path.
  int Mount(const char* path, FileSystemDriver* driver);

  // Open a file in the file system.
  //
  // Returns the file descriptor for the opened file.
  int Open(const char* path);

  // Close a file in the file system.
  int Close(int handle);

  // Read from an open file.
  //
  // Returns the number of bytes copied into buffer. Returns 0 at EOF.
  int Read(int handle, void* buffer, size_t length);

  // Read to an open file.
  //
  // Returns the number of bytes written to the file.
  int Write(int handle, const void* buffer, size_t length);

  // Seek in an open file.
  //
  // Returns the new position in the file.
  int Seek(int handle, int offset, int direction);

 private:
  FileSystemMount* FindMount(const char* path,
                             bool full_match,
                             const char** remaining_path);
  bool IsValidOpenHandle(int handle);

  class FileSystemMount {
   public:
    char* path;
    FileSystemDriver* driver;
  };

  class OpenFile {
   public:
    FileSystemMount* mount;
    int handle;
  };

  Mutex* mutex_;

  FileSystemMount mounts_[kMaxMounts];

  static const int kFdOffset = 3;  // Skip stdin, stdout and stderr.
  OpenFile open_files_[kMaxOpenFiles];
};

// A file system that can be mounted must implement this interface.
//
// Right now all calls to a file system driver are protected by a
// global file system lock, so no concurency control is required in
// the file system driver.
class FileSystemDriver {
 public:
  virtual ~FileSystemDriver() {}

  // Open a file in the file system. The path is always an absolute
  // path with a leading /. Returns a handle local t this driver.
  virtual int Open(const char* path) = 0;

  virtual int Close(int handle) = 0;
  virtual int Read(int handle, void* buffer, size_t length) = 0;
  virtual int Write(int handle, const void* buffer, size_t length) = 0;
  virtual int Seek(int handle, int offset, int direction) = 0;
};

}  // namespace dartino

#endif  // SRC_FREERTOS_FILE_SYSTEM_H_

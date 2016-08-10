// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>

#include "src/freertos/file_system.h"
#include "src/freertos/globals.h"
#include "src/shared/assert.h"
#include "src/shared/test_case.h"

namespace dartino {

TEST_CASE(EmptyFileSystem) {
  FileSystem* fs = new FileSystem();
  EXPECT_EQ(-ENOENT, fs->Open("test"));
  delete fs;
}

class DymmyFileSystemDriver : public FileSystemDriver {
 public:
  DymmyFileSystemDriver() {}
  int Open(const char* path) {
    return -ENOENT;
  }

  int Close(int handle) {
    return -EBADF;
  }

  int Read(int handle, void* buffer, size_t length) {
    UNREACHABLE();
    return -1;
  }

  int Write(int handle, const void* buffer, size_t length) {
    UNREACHABLE();
    return -1;
  }

  int Seek(int handle, int offset, int direction) {
    UNREACHABLE();
    return -1;
  }
};

TEST_CASE(MountArguments) {
  FileSystem* fs = new FileSystem();
  FileSystemDriver* driver = new DymmyFileSystemDriver();
  EXPECT_EQ(-EINVAL, fs->Mount("/", driver));
  EXPECT_EQ(-EINVAL, fs->Mount("test", driver));
  EXPECT_EQ(-EINVAL, fs->Mount("/test", NULL));
  delete fs;
  delete driver;
}

TEST_CASE(MountConflictingPath) {
  FileSystem* fs = new FileSystem();
  FileSystemDriver* dummy_driver = new DymmyFileSystemDriver();
  EXPECT_EQ(0, fs->Mount("/test", dummy_driver));
  EXPECT_EQ(-EEXIST, fs->Mount("/test", dummy_driver));
  delete fs;
  delete dummy_driver;
}

TEST_CASE(MountLimit) {
  const int kPathBufferSize = 32;
  char path[kPathBufferSize];

  FileSystem* fs = new FileSystem();
  FileSystemDriver* dummy_driver = new DymmyFileSystemDriver();
  for (int i = 0; i < FileSystem::kMaxMounts; i++) {
    snprintf(path, kPathBufferSize, "/test%d", i);
    EXPECT_EQ(0, fs->Mount(path, dummy_driver));
  }
  for (int i = FileSystem::kMaxMounts + 1;
       i < FileSystem::kMaxMounts + 10;
       i++) {
    snprintf(path, kPathBufferSize, "/test%d", i);
    EXPECT_EQ(-EMFILE, fs->Mount(path, dummy_driver));
  }
  delete fs;
  delete dummy_driver;
}

TEST_CASE(DummyFileSystem) {
  FileSystem* fs = new FileSystem();
  FileSystemDriver* dummy_driver = new DymmyFileSystemDriver();
  EXPECT_EQ(0, fs->Mount("/test", dummy_driver));
  EXPECT_EQ(-ENOENT, fs->Open("test"));
  delete fs;
  delete dummy_driver;
}

class FixedOneFileFileSystemDriver : public FileSystemDriver {
 public:
  FixedOneFileFileSystemDriver() : handle_(-1) {}

  int Open(const char* path) {
    if (handle_ == 1) return -EMFILE;
    if (strcmp(path, "/file1") == 0 && handle_ == -1) {
      handle_ = 1;
      return handle_;
    }
    return -ENOENT;
  }

  int Close(int handle) {
    if (handle == 1 && handle_ == 1) {
      handle_ = -1;
      return 0;
    }
    return -EBADF;
  }

  int Read(int handle, void* buffer, size_t length) {
    const char* data = "data";
    int actual_length = MIN(length, strlen(data));
    memcpy(buffer, data, actual_length);
    return actual_length;
  }

  int Write(int handle, const void* buffer, size_t length) {
    return -EACCES;
  }

  int Seek(int handle, int offset, int direction) {
    return -EACCES;
  }

 private:
  // Only one open file supported.
  int handle_;
};

TEST_CASE(OpenCloseFile) {
  int fd;
  FileSystem* fs = new FileSystem();
  FileSystemDriver* driver = new FixedOneFileFileSystemDriver();
  EXPECT_EQ(0, fs->Mount("/fs", driver));
  fd = fs->Open("/non_existing_file");
  EXPECT_EQ(-ENOENT, fd);
  fd = fs->Open("/fs/non_existing_file");
  EXPECT_EQ(-ENOENT, fd);
  fd = fs->Open("/fs/file1");
  EXPECT_EQ(3, fd);
  int other_fd = fs->Open("/fs/file1");
  EXPECT_EQ(-EMFILE, other_fd);
  EXPECT_EQ(0, fs->Close(fd));
  fd = fs->Open("/fs/file1");
  EXPECT_EQ(3, fd);
  delete fs;
  delete driver;
}

TEST_CASE(ReadFile) {
  int fd;
  FileSystem* fs = new FileSystem();
  FileSystemDriver* driver = new FixedOneFileFileSystemDriver();
  EXPECT_EQ(0, fs->Mount("/fs", driver));
  fd = fs->Open("/fs/file1");
  EXPECT_EQ(3, fd);
  const int kDataSize = 4;
  char buffer[kDataSize];
  for (int i = 0; i < kDataSize; i++) {
    int result = fs->Read(fd, buffer, i);
    EXPECT_EQ(i, result);
    EXPECT(memcmp(buffer, "data", i) == 0)
  }
  for (int i = kDataSize; i < kDataSize + 10; i++) {
    int result = fs->Read(fd, buffer, i);
    EXPECT_EQ(kDataSize, result);
    EXPECT(memcmp(buffer, "data", kDataSize) == 0)
  }
  EXPECT_EQ(0, fs->Close(fd));
  delete fs;
  delete driver;
}

TEST_CASE(WriteFile) {
  int fd;
  FileSystem* fs = new FileSystem();
  FileSystemDriver* driver = new FixedOneFileFileSystemDriver();
  EXPECT_EQ(0, fs->Mount("/fs", driver));
  fd = fs->Open("/fs/file1");
  EXPECT_EQ(3, fd);
  EXPECT_EQ(-EACCES, fs->Write(fd, "data", 4));
  EXPECT_EQ(0, fs->Close(fd));
  delete fs;
  delete driver;
}

}  // namespace dartino

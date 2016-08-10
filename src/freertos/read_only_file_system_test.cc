// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>

#include "src/freertos/file_system.h"
#include "src/freertos/read_only_file_system.h"
#include "src/shared/assert.h"
#include "src/shared/test_case.h"

namespace dartino {

static const uint8_t ro_file_system[] = {
  0x03, 0x00, 0x00, 0x00,  // ABC
  0x41, 0x42, 0x43, 0x00,
  0x03, 0x00, 0x00, 0x00,  // 012
  0x30, 0x31, 0x32, 0x00,

  0x05, 0x00, 0x00, 0x00,  // empty
  0x65, 0x6d, 0x70, 0x74,
  0x79, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,

  0x04, 0x00, 0x00, 0x00,  // ABCD
  0x41, 0x42, 0x43, 0x44,
  0x04, 0x00, 0x00, 0x00,  // 0123
  0x30, 0x31, 0x32, 0x33,

  0x05, 0x00, 0x00, 0x00,  // ABCDE
  0x41, 0x42, 0x43, 0x44,
  0x45, 0x00, 0x00, 0x00,
  0x06, 0x00, 0x00, 0x00,  // 012345
  0x30, 0x31, 0x32, 0x33,
  0x34, 0x35, 0x00, 0x00,

  0x06, 0x00, 0x00, 0x00,  // ABC/DE
  0x41, 0x42, 0x43, 0x2f,
  0x44, 0x45, 0x00, 0x00,
  0x08, 0x00, 0x00, 0x00,  // 01234567
  0x30, 0x31, 0x32, 0x33,
  0x34, 0x35, 0x36, 0x37,

  // End of files.
  0x00, 0x00, 0x00, 0x00,
};

static const int kRoFileSystemFiles = 5;
static const char* ro_file_system_file_names[kRoFileSystemFiles] = {
  "/ABC",
  "/empty",
  "/ABCD",
  "/ABCDE",
  "/ABC/DE"
};

static const char* ro_file_system_content[kRoFileSystemFiles] = {
  "012",
  "",
  "0123",
  "012345",
  "01234567"
};

static uint8_t* GetAlignedReadOnlyFileSystemData() {
  uint8_t* aligned = reinterpret_cast<uint8_t*>(malloc(sizeof(ro_file_system)));
  memcpy(aligned, ro_file_system, sizeof(ro_file_system));
  return aligned;
}

TEST_CASE(ReadOnlyFileSystemDriverOpen) {
  uint8_t* data = GetAlignedReadOnlyFileSystemData();
  FileSystemDriver* driver = new ReadOnlyFileSystemDriver(data);
  int expected_handle = 0;
  for (int i = 0; i < 2; i++) {
    for (int j = 0; j < kRoFileSystemFiles; j++) {
      int handle = driver->Open(ro_file_system_file_names[j]);
      EXPECT_EQ(expected_handle, handle);
      expected_handle++;
    }
  }
  delete driver;
  free(data);
}

TEST_CASE(ReadOnlyFileSystemDriverOpenClose) {
  uint8_t* data = GetAlignedReadOnlyFileSystemData();
  FileSystemDriver* driver = new ReadOnlyFileSystemDriver(data);
  int expected_handle = 0;
  for (int i = 0; i < 10; i++) {
    for (int j = 0; j < kRoFileSystemFiles; j++) {
      int handle = driver->Open(ro_file_system_file_names[j]);
      EXPECT_EQ(expected_handle, handle);
      expected_handle++;
    }
    for (int j = 0; j < kRoFileSystemFiles; j++) {
      EXPECT_EQ(0, driver->Close(j));
    }
    expected_handle = 0;
  }
  delete driver;
  free(data);
}

TEST_CASE(ReadOnlyFileSystemOpenClose) {
  FileSystem* fs = new FileSystem();
  uint8_t* data = GetAlignedReadOnlyFileSystemData();
  FileSystemDriver* driver = new ReadOnlyFileSystemDriver(data);
  EXPECT_EQ(0, fs->Mount("/fs", driver));

  const int kFdOffset = 3;
  const int kPathBufferSize = 32;
  char path[kPathBufferSize];
  int expected_handle = kFdOffset;
  for (int i = 0; i < 1; i++) {
    for (int j = 0; j < kRoFileSystemFiles; j++) {
      snprintf(path, kPathBufferSize, "/fs%s", ro_file_system_file_names[j]);
      int handle = fs->Open(path);
      EXPECT_EQ(expected_handle, handle);
      expected_handle++;
    }
    for (int j = 0; j < kRoFileSystemFiles; j++) {
      EXPECT_EQ(0, fs->Close(j + kFdOffset));
    }
    expected_handle = kFdOffset;
  }
  delete fs;
  delete driver;
  free(data);
}

TEST_CASE(ReadOnlyFileSystemEmptyFile) {
  int fd;
  FileSystem* fs = new FileSystem();
  uint8_t* data = GetAlignedReadOnlyFileSystemData();
  FileSystemDriver* driver = new ReadOnlyFileSystemDriver(data);
  EXPECT_EQ(0, fs->Mount("/fs", driver));

  fd = fs->Open("/fs/empty");
  EXPECT(fd > 0);
  EXPECT_EQ(0, fs->Read(fd, NULL, 0));
  EXPECT_EQ(0, fs->Read(fd, NULL, 1));
  EXPECT_EQ(0, fs->Read(fd, NULL, 42));
  EXPECT_EQ(0, fs->Seek(fd, 0, SEEK_SET));
  EXPECT_EQ(0, fs->Seek(fd, 0, SEEK_CUR));
  EXPECT_EQ(0, fs->Seek(fd, 0, SEEK_END));

  EXPECT_EQ(-EINVAL, fs->Seek(fd, 1, SEEK_SET));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, -1, SEEK_SET));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, 1, SEEK_CUR));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, -1, SEEK_CUR));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, 1, SEEK_END));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, -1, SEEK_END));
  EXPECT_EQ(0, fs->Read(fd, NULL, 42));
  EXPECT_EQ(0, fs->Close(fd));

  delete driver;
  delete fs;
  free(data);
}

TEST_CASE(ReadOnlyFileSystemNonExistingFile) {
  int fd;
  FileSystem* fs = new FileSystem();
  uint8_t* data = GetAlignedReadOnlyFileSystemData();
  FileSystemDriver* driver = new ReadOnlyFileSystemDriver(data);
  EXPECT_EQ(0, fs->Mount("/fs", driver));

  fd = fs->Open("/fs/");
  EXPECT_EQ(-ENOENT, fd);
  fd = fs->Open("/fs/n");
  EXPECT_EQ(-ENOENT, fd);
  fd = fs->Open("/fs/non_existing_file");
  EXPECT_EQ(-ENOENT, fd);
  fd = fs->Open("/fs/non/existing/file");
  EXPECT_EQ(-ENOENT, fd);

  delete driver;
  delete fs;
  free(data);
}

static void TestReadFile(
    FileSystem* fs, const char* path, const char* content) {
  int file_size = strlen(content);
  int bytes_read;

  int fd = fs->Open(path);
  EXPECT(fd > 0);

  const int kBufferSize = 1024;
  uint8_t buffer[kBufferSize];
  bytes_read = fs->Read(fd, buffer, kBufferSize);
  EXPECT_EQ(file_size, bytes_read);
  EXPECT(memcmp(buffer, content, file_size) == 0);
  for (int i = 0; i < 2; i++) {
    bytes_read = fs->Read(fd, buffer, kBufferSize);
    EXPECT_EQ(0, bytes_read);
  }

  int fd2 = fs->Open(path);
  EXPECT(fd2 > 0);
  EXPECT_GT(fd2, fd);
  for (int i = 0; i < file_size; i++) {
    bytes_read = fs->Read(fd2, buffer, 1);
    EXPECT_EQ(1, bytes_read);
    EXPECT_EQ(*buffer, content[i]);
  }
  for (int i = 0; i < 2; i++) {
    bytes_read = fs->Read(fd2, buffer, kBufferSize);
    EXPECT_EQ(0, bytes_read);
  }

  for (int block_size = 1; block_size < file_size + 1; block_size++) {
    int fd = fs->Open(path);
    EXPECT(fd > 0);
    int remaining = file_size;
    uint8_t* p = buffer;
    while (remaining > 0) {
      bytes_read = fs->Read(fd, p, block_size);
      remaining -= bytes_read;
      p += bytes_read;
    }
    EXPECT(memcmp(buffer, content, file_size) == 0);
    EXPECT_EQ(0, fs->Close(fd));
  }

  EXPECT_EQ(0, fs->Close(fd));
  EXPECT_EQ(0, fs->Close(fd2));
}

TEST_CASE(ReadOnlyFileSystemRead) {
  FileSystem* fs = new FileSystem();
  uint8_t* data = GetAlignedReadOnlyFileSystemData();
  FileSystemDriver* driver = new ReadOnlyFileSystemDriver(data);
  EXPECT_EQ(0, fs->Mount("/fs", driver));

  const int kPathBufferSize = 32;
  char path[kPathBufferSize];
  for (int i = 0; i < kRoFileSystemFiles; i++) {
    snprintf(path, kPathBufferSize, "/fs%s", ro_file_system_file_names[i]);
    TestReadFile(fs, path, ro_file_system_content[i]);
  }

  delete driver;
  delete fs;
  free(data);
}

static void TestSeekFile(
    FileSystem* fs, const char* path, const char* content) {
  int file_size = strlen(content);

  int fd = fs->Open(path);
  EXPECT(fd > 0);

  EXPECT_EQ(-EINVAL, fs->Seek(fd, file_size + 1, SEEK_SET));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, -1, SEEK_SET));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, file_size + 1, SEEK_CUR));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, -1, SEEK_CUR));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, file_size + 1, SEEK_END));
  EXPECT_EQ(-EINVAL, fs->Seek(fd, -1, SEEK_END));

  for (int i = 0; i < file_size; i++) {
    EXPECT_EQ(i, fs->Seek(fd, i, SEEK_SET));
    EXPECT_EQ(i, fs->Seek(fd, file_size - i, SEEK_END));
  }
  EXPECT_EQ(0, fs->Seek(fd, 0, SEEK_SET));
  for (int i = 1; i < file_size; i++) {
    EXPECT_EQ(i, fs->Seek(fd, 1, SEEK_CUR));
  }

  if (file_size > 2) {
    EXPECT_EQ(2, fs->Seek(fd, 2, SEEK_SET));
    char byte;
    fs->Read(fd, &byte, 1);
    EXPECT_EQ(content[2], byte);
  }

  EXPECT_EQ(0, fs->Close(fd));
}

TEST_CASE(ReadOnlyFileSystemSeek) {
  FileSystem* fs = new FileSystem();
  uint8_t* data = GetAlignedReadOnlyFileSystemData();
  FileSystemDriver* driver = new ReadOnlyFileSystemDriver(data);
  EXPECT_EQ(0, fs->Mount("/fs", driver));

  const int kPathBufferSize = 32;
  char path[kPathBufferSize];
  for (int i = 0; i < kRoFileSystemFiles; i++) {
    snprintf(path, kPathBufferSize, "/fs%s", ro_file_system_file_names[i]);
    TestSeekFile(fs, path, ro_file_system_content[i]);
  }

  delete driver;
  delete fs;
  free(data);
}

}  // namespace dartino

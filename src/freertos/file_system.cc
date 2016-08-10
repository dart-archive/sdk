// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/freertos/file_system.h"

#include <errno.h>
#include <stdio.h>

#include <cstdlib>
#include <cstring>

#include "src/freertos/globals.h"

namespace dartino {

FileSystem::FileSystem() : mutex_(new Mutex()) {
  memset(&mounts_, 0, sizeof(mounts_));
  memset(&open_files_, 0, sizeof(open_files_));
}

int FileSystem::Mount(const char* path, FileSystemDriver* driver) {
  ScopedLock locker(mutex_);

  if (path[0] != '/' || driver == NULL) return -EINVAL;
  if (path[1] == '\0') return -EINVAL;
  if (FindMount(path, true, NULL) != NULL) return -EEXIST;

  for (int i = 0; i < kMaxMounts; i++) {
    if (mounts_[i].driver == NULL) {
      mounts_[i].path = strdup(path);
      mounts_[i].driver = driver;
      return 0;
    }
  }
  return -EMFILE;
}

int FileSystem::Open(const char* path) {
  ScopedLock locker(mutex_);

  const char* fs_path;
  FileSystemMount* mount = FindMount(path, false, &fs_path);
  if (mount == NULL) return -ENOENT;
  if (fs_path[0] != '/') return -ENOENT;
  int handle = mount->driver->Open(fs_path);
  if (handle < 0) return handle;

  for (int i = kFdOffset; i < kMaxOpenFiles; i++) {
    if (open_files_[i].mount == NULL) {
      open_files_[i].mount = mount;
      open_files_[i].handle = handle;
      return i;
    }
  }

  // TODO(sgjesse) close the file in the fs.
  return -ENFILE;
}

int FileSystem::Close(int handle) {
  ScopedLock locker(mutex_);

  if (!IsValidOpenHandle(handle)) return -EBADF;

  int driver_handle = open_files_[handle].handle;
  int result = open_files_[handle].mount->driver->Close(driver_handle);
  if (result == 0) {
    open_files_[handle].mount = NULL;
  }
  return result;
}

int FileSystem::Read(int handle, void* buffer, size_t length) {
  ScopedLock locker(mutex_);

  if (!IsValidOpenHandle(handle)) return -EBADF;
  int driver_handle = open_files_[handle].handle;
  return open_files_[handle].mount->driver->Read(driver_handle, buffer, length);
}

int FileSystem::Write(int handle, const void* buffer, size_t length) {
  ScopedLock locker(mutex_);

  if (!IsValidOpenHandle(handle)) return -EBADF;
  int driver_handle = open_files_[handle].handle;
  return open_files_[handle].mount->driver->Write(
      driver_handle, buffer, length);
}

int FileSystem::Seek(int handle, int offset, int direction) {
  ScopedLock locker(mutex_);

  if (!IsValidOpenHandle(handle)) return -EBADF;
  int driver_handle = open_files_[handle].handle;
  return open_files_[handle].mount->driver->Seek(
      driver_handle, offset, direction);
}

FileSystem::FileSystemMount* FileSystem::FindMount(
    const char* path,
    bool full_match,
    const char** remaining_path) {
  int path_len = strlen(path);
  for (int i = 0; i < kMaxMounts; i++) {
    if (mounts_[i].driver == NULL) continue;
    int mount_len = strlen(mounts_[i].path);
    if (path_len < mount_len) continue;
    if (memcmp(path, mounts_[i].path, mount_len) == 0) {
      if ((full_match && path[mount_len] != '\0') ||
          (!full_match && path[mount_len] != '/')) {
        continue;
      }
      if (remaining_path != NULL) {
        *remaining_path = path + mount_len;
      }
      return &mounts_[i];
    }
  }
  return NULL;
}

bool FileSystem::IsValidOpenHandle(int handle) {
  return (handle < kMaxOpenFiles) && (open_files_[handle].mount != NULL);
}

}  // namespace dartino

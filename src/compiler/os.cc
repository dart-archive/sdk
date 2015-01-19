// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>
#include <sys/time.h>

#include "src/shared/assert.h"
#include "src/compiler/os.h"
#include "src/compiler/zone.h"

namespace fletch {

int64 OS::CurrentTime() {
  struct timeval tv;
  if (gettimeofday(&tv, NULL) < 0) {
    UNREACHABLE();
    return 0;
  }
  return (static_cast<int64>(tv.tv_sec) * 1000000) + tv.tv_usec;
}

static char* AllocateBuffer(Zone* zone, intptr_t length) {
  if (zone == NULL) return reinterpret_cast<char*>(malloc(length));
  return reinterpret_cast<char*>(zone->Allocate(length));
}

const char* OS::UriResolve(const char* uri, const char* path, Zone* zone) {
  const char* index = strrchr(uri, '/');
  const intptr_t path_length = strlen(path);
  if (index == NULL) {
    // Return a copy of 'path'.
    char* path_copy = AllocateBuffer(zone, path_length + 1);
    memmove(path_copy, path, path_length + 1);
    return path_copy;
  }
  const intptr_t uri_length = (index - uri) + 1;
  const intptr_t new_uri_length = uri_length + path_length;
  char* new_uri = AllocateBuffer(zone, new_uri_length + 1);
  memmove(new_uri, uri, uri_length);
  memmove(new_uri + uri_length, path, path_length);
  new_uri[new_uri_length] = '\0';
  return new_uri;
}

char* OS::LoadFile(const char* uri, Zone* zone, uint32* file_size) {
  // Open the file.
  FILE* file = fopen(uri, "rb");
  if (file == NULL) {
    printf("ERROR: Cannot open %s\n", uri);
    return NULL;
  }

  // Determine the size of the file.
  if (fseek(file, 0, SEEK_END) != 0) {
    printf("ERROR: Cannot seek in file %s\n", uri);
    fclose(file);
    return NULL;
  }
  int size = ftell(file);
  rewind(file);

  // Read in the entire file.
  char* buffer = AllocateBuffer(zone, size + 1);
  int result = fread(buffer, 1, size, file);
  fclose(file);
  if (result != size) {
    printf("ERROR: Unable to read entire file %s\n", uri);
    return NULL;
  }
  buffer[size] = '\0';
  if (file_size != NULL) *file_size = size;
  return buffer;
}

bool OS::StoreFile(const char* uri, List<uint8> bytes) {
  // Open the file.
  FILE* file = fopen(uri, "wb");
  if (file == NULL) {
    printf("ERROR: Cannot open %s\n", uri);
    return false;
  }

  int result = fwrite(bytes.data(), 1, bytes.length(), file);
  fclose(file);
  if (result != bytes.length()) {
    printf("ERROR: Unable to write entire file %s\n", uri);
    return false;
  }

  return true;
}

}  // namespace fletch

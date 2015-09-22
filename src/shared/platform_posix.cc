// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

// We do not include platform_posix.h on purpose. That file
// should never be directly inported. platform.h is always
// the platform header to include.
#include "src/shared/platform.h"  // NOLINT

#include <errno.h>
#include <pthread.h>
#include <semaphore.h>
#include <sys/types.h>  // mmap & munmap
#include <sys/mman.h>   // mmap & munmap
#include <sys/time.h>
#include <time.h>
#include <signal.h>
#include <unistd.h>

#include "src/shared/utils.h"

namespace fletch {

static uint64 time_launch;

void Platform::Setup() {
  time_launch = GetMicroseconds();

  // Make functions return EPIPE instead of getting SIGPIPE signal.
  struct sigaction sa;
  sa.sa_flags = 0;
  sigemptyset(&sa.sa_mask);
  sa.sa_handler = SIG_IGN;
  sigaction(SIGPIPE, &sa, NULL);
}

uint64 Platform::GetMicroseconds() {
  struct timeval tv;
  if (gettimeofday(&tv, NULL) < 0) return -1;
  uint64 result = tv.tv_sec * 1000000LL;
  result += tv.tv_usec;
  return result;
}

uint64 Platform::GetProcessMicroseconds() {
  // Assume now is past time_launch.
  return GetMicroseconds() - time_launch;
}

int Platform::GetNumberOfHardwareThreads() {
  static int hardware_threads_cache_ = -1;
  if (hardware_threads_cache_ == -1) {
    hardware_threads_cache_ = sysconf(_SC_NPROCESSORS_ONLN);
  }
  return hardware_threads_cache_;
}

// Load file at 'uri'.
List<uint8> Platform::LoadFile(const char* name) {
  // Open the file.
  FILE* file = fopen(name, "rb");
  if (file == NULL) {
    Print::Error("ERROR: Cannot open %s\n", name);
    return List<uint8>();
  }

  // Determine the size of the file.
  if (fseek(file, 0, SEEK_END) != 0) {
    Print::Error("ERROR: Cannot seek in file %s\n", name);
    fclose(file);
    return List<uint8>();
  }
  int size = ftell(file);
  rewind(file);

  // Read in the entire file.
  uint8* buffer = static_cast<uint8*>(malloc(size));
  int result = fread(buffer, 1, size, file);
  fclose(file);
  if (result != size) {
    Print::Error("ERROR: Unable to read entire file %s\n", name);
    return List<uint8>();
  }
  return List<uint8>(buffer, size);
}

bool Platform::StoreFile(const char* uri, List<uint8> bytes) {
  // Open the file.
  FILE* file = fopen(uri, "wb");
  if (file == NULL) {
    Print::Error("ERROR: Cannot open %s\n", uri);
    return false;
  }

  int result = fwrite(bytes.data(), 1, bytes.length(), file);
  fclose(file);
  if (result != bytes.length()) {
    Print::Error("ERROR: Unable to write entire file %s\n", uri);
    return false;
  }

  return true;
}

bool Platform::WriteText(const char* uri, const char* text, bool append) {
  // Open the file.
  FILE* file = fopen(uri, append ? "a" : "w");
  if (file == NULL) {
    // TODO(wibling): Does it make sense to write an error here? It seems it
    // could go into a loop if it fails to open the log file and we then write
    // again.
    return false;
  }
  int len = strlen(text);
  int result = fwrite(text, 1, len, file);
  fclose(file);
  if (result != len) {
    // TODO(wibling): Same as above.
    return false;
  }

  return true;
}

static bool LocalTime(int64_t seconds_since_epoch, tm* tm_result) {
  time_t seconds = static_cast<time_t>(seconds_since_epoch);
  if (seconds != seconds_since_epoch) return false;
  struct tm* error_code = localtime_r(&seconds, tm_result);
  return error_code != NULL;
}

const char* Platform::GetTimeZoneName(int64_t seconds_since_epoch) {
  tm decomposed;
  bool succeeded = LocalTime(seconds_since_epoch, &decomposed);
  // If unsuccessful, return an empty string like V8 does.
  return (succeeded && (decomposed.tm_zone != NULL)) ? decomposed.tm_zone : "";
}

int Platform::GetTimeZoneOffset(int64_t seconds_since_epoch) {
  tm decomposed;
  bool succeeded = LocalTime(seconds_since_epoch, &decomposed);
  // Even if the offset was 24 hours it would still easily fit into 32 bits.
  // If unsuccessful, return zero like V8 does.
  return succeeded ? static_cast<int>(decomposed.tm_gmtoff) : 0;
}

void Platform::Exit(int exit_code) {
  exit(exit_code);
}

void Platform::ScheduleAbort() {
  static bool failed = false;
  if (!failed) atexit(abort);
  failed = true;
}

void Platform::ImmediateAbort() {
  abort();
}

int Platform::GetPid() {
  return static_cast<int>(getpid());
}

// Constants used for mmap.
static const int kMmapFd = -1;
static const int kMmapFdOffset = 0;

VirtualMemory::VirtualMemory(int size) : size_(size) {
  void* result = mmap(reinterpret_cast<void*>(0xcafe0000), size, PROT_NONE,
                      MAP_PRIVATE | MAP_ANON | MAP_NORESERVE,
                      kMmapFd, kMmapFdOffset);
  address_ = reinterpret_cast<uword>(result);
}

VirtualMemory::~VirtualMemory() {
  if (IsReserved() &&
      munmap(reinterpret_cast<void*>(address()), size()) == 0) {
    address_ = reinterpret_cast<uword>(MAP_FAILED);
  }
}

bool VirtualMemory::IsReserved() const {
  return address_ != reinterpret_cast<uword>(MAP_FAILED);
}

bool VirtualMemory::Commit(uword address, int size, bool executable) {
  int prot = PROT_READ | PROT_WRITE | (executable ? PROT_EXEC : 0);
  return mmap(reinterpret_cast<void*>(address), size, prot,
              MAP_PRIVATE | MAP_ANON | MAP_FIXED,
              kMmapFd, kMmapFdOffset) != MAP_FAILED;
}

bool VirtualMemory::Uncommit(uword address, int size) {
  return mmap(reinterpret_cast<void*>(address), size, PROT_NONE,
              MAP_PRIVATE | MAP_ANON | MAP_NORESERVE,
              kMmapFd, kMmapFdOffset) != MAP_FAILED;
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_POSIX)

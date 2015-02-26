// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/platform.h"

#include <pthread.h>
#include <semaphore.h>
#include <sys/types.h>  // mmap & munmap
#include <sys/mman.h>   // mmap & munmap
#include <sys/time.h>
#include <time.h>
#include <signal.h>
#include <unistd.h>

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
    printf("ERROR: Cannot open %s\n", name);
    return List<uint8>();
  }

  // Determine the size of the file.
  if (fseek(file, 0, SEEK_END) != 0) {
    printf("ERROR: Cannot seek in file %s\n", name);
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
    printf("ERROR: Unable to read entire file %s\n", name);
    return List<uint8>();
  }
  return List<uint8>(buffer, size);
}

bool Platform::StoreFile(const char* uri, List<uint8> bytes) {
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

class PosixMutex : public Mutex {
 public:
  PosixMutex() { pthread_mutex_init(&mutex_, NULL);  }
  ~PosixMutex() { pthread_mutex_destroy(&mutex_); }

  int Lock() { return pthread_mutex_lock(&mutex_); }
  int Unlock() { return pthread_mutex_unlock(&mutex_); }

  bool IsLocked() {
    if (pthread_mutex_trylock(&mutex_) == 0) {
      pthread_mutex_unlock(&mutex_);
      return false;
    }
    return true;
  }

 private:
  pthread_mutex_t mutex_;   // Pthread mutex for POSIX platforms.
};

Mutex* Platform::CreateMutex() {
  return new PosixMutex();
}

class PosixMonitor : public Monitor {
 public:
  PosixMonitor() {
    pthread_mutex_init(&mutex_, NULL);
    pthread_cond_init(&cond_, NULL);
  }

  ~PosixMonitor() {
    pthread_mutex_destroy(&mutex_);
    pthread_cond_destroy(&cond_);
  }

  int Lock() { return pthread_mutex_lock(&mutex_); }
  int Unlock() { return pthread_mutex_unlock(&mutex_); }

  int Wait() { return pthread_cond_wait(&cond_, &mutex_); }

  int Wait(uint64 microseconds) {
    uint64 us = Platform::GetMicroseconds() + microseconds;
    return WaitUntil(us);
  }

  int WaitUntil(uint64 microseconds_since_epoch) {
    timespec ts;
    ts.tv_sec = microseconds_since_epoch / 1000000;
    ts.tv_nsec = (microseconds_since_epoch % 1000000) * 1000;
    return pthread_cond_timedwait(&cond_, &mutex_, &ts);
  }

  int Notify() { return pthread_cond_signal(&cond_); }
  int NotifyAll() { return pthread_cond_broadcast(&cond_); }

 private:
  pthread_mutex_t mutex_;   // Pthread mutex for POSIX platforms.
  pthread_cond_t cond_;   // Pthread condition for POSIX platforms.
};

Monitor* Platform::CreateMonitor() {
  return new PosixMonitor();
}

}  // namespace fletch

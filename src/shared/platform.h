// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_PLATFORM_H_
#define SRC_SHARED_PLATFORM_H_

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/list.h"

#if defined(DARTINO_TARGET_OS_POSIX)
#include "src/shared/platform_posix.h"
#elif defined(DARTINO_TARGET_OS_WIN)
#include "src/shared/platform_windows.h"
#elif defined(DARTINO_TARGET_OS_LK)
#include "src/shared/platform_lk.h"
#elif defined(DARTINO_TARGET_OS_CMSIS)
#include "src/shared/platform_cmsis.h"
#else
#error "Platform not implemented for target os."
#endif

namespace dartino {

// Computes the path of of this executable. This is similar to argv[0], but
// since argv[0] is provided by the calling process, argv[0] may be an
// arbitrary value where as this method uses an OS-dependent method of finding
// the real path.
void GetPathOfExecutable(char* path, size_t path_length);

class Thread;
class Mutex;
class Semaphore;
class Monitor;

// Interface to the underlying platform.
namespace Platform {
enum OperatingSystem {
  kUnknownOS = 0,
  kLinux = 1,
  kMacOS = 2,
  kAndroid = 3,
  kWindows = 4,
};

enum Architecture {
  kUnknownArch = 0,
  kIA32 = 1,
  kX64 = 2,
  kARM = 3,
};

// Initialize the platform services.
void Setup();

// Tear down the platform services.
void TearDown();

// Set thread in thread local storage.
void SetCurrentThread(Thread* thread);

// Get thread from thread local storage.
Thread* GetCurrentThread();

// Factory method for creating platform dependent Mutex.
// Use delete to reclaim the storage for the returned Mutex.
Mutex* CreateMutex();

// Use delete to reclaim the storage for the returned Monitor.
Monitor* CreateMonitor();

// Returns the number of microseconds since epoch.
uint64 GetMicroseconds();

// Returns the number of microseconds since this process got started.
uint64 GetProcessMicroseconds();

// Returns the number of available hardware threads.
int GetNumberOfHardwareThreads();

// Load file at 'uri'.
List<uint8> LoadFile(const char* name);

// Store file at 'uri'.
bool StoreFile(const char* uri, List<uint8> bytes);

// Write text to file, append if the bool append is true.
bool WriteText(const char* uri, const char* text, bool append);

#if DEBUG
void WaitForDebugger(const char* executable_name);
#endif

const char* GetTimeZoneName(int64_t seconds_since_epoch);

int GetTimeZoneOffset(int64_t seconds_since_epoch);

int GetLocalTimeZoneOffset();

void Exit(int exit_code);

void ScheduleAbort();

void ImmediateAbort();

int GetPid();

char* GetEnv(const char* name);

int FormatString(char* buffer, size_t length, const char* format, ...);

int GetLastError();
void SetLastError(int value);

// Platform dependent max Dart stack size.
// TODO(ager): Make this configurable through the embedding API?
int MaxStackSizeInWords();

inline OperatingSystem OS() {
#if defined(__ANDROID__)
  return kAndroid;
#elif defined(__linux__)
  return kLinux;
#elif defined(__APPLE__)
  return kMacOS;
#elif defined(_WINNT)
  return kWindows;
#else
  return kUnknownOS;
#endif
}

inline Architecture Arch() {
#if defined(DARTINO_TARGET_IA32)
  return kIA32;
#elif defined(DARTINO_TARGET_X64)
  return kX64;
#elif defined(DARTINO_TARGET_ARM)
  return kARM;
#else
  return kUnknownArch;
#endif
}
}  // namespace Platform

// Interface for manipulating virtual memory.
class VirtualMemory {
 public:
  // Reserves virtual memory with size.
  explicit VirtualMemory(int size);
  ~VirtualMemory();

  // Returns whether the memory has been reserved.
  bool IsReserved() const;

  // Returns the start address of the reserved memory.
  uword address() const {
    ASSERT(IsReserved());
    return address_;
  }

  // Returns the size of the reserved memory.
  int size() const { return size_; }

  // Commits real memory. Returns whether the operation succeeded.
  bool Commit(uword address, int size, bool executable);

  // Uncommit real memory.  Returns whether the operation succeeded.
  bool Uncommit(uword address, int size);

 private:
  uword address_;   // Start address of the virtual memory.
  const int size_;  // Size of the virtual memory.
};

// ----------------------------------------------------------------------------
// Mutexes are used for serializing access to non-reentrant sections of code.
// The implementations of mutex should allow for nested/recursive locking.
class Mutex {
 public:
  virtual ~Mutex() {}

  // Locks the given mutex. If the mutex is currently unlocked, it becomes
  // locked and owned by the calling thread, and immediately. If the mutex
  // is already locked by another thread, suspends the calling thread until
  // the mutex is unlocked.
  int Lock() { return impl_.Lock(); }

  // Locks the given mutex. If the mutex is currently unlocked, it becomes
  // locked and owned by the calling thread. If the mutex is currently
  // locked, a value other than 0 is returned.
  int TryLock() { return impl_.TryLock(); }

  // Unlocks the given mutex. The mutex is assumed to be locked and owned by
  // the calling thread on entrance.
  int Unlock() { return impl_.Unlock(); }

 private:
  MutexImpl impl_;
};

// Stack-allocated ScopedLocks provide block-scoped locking and unlocking
// of a mutex.
class ScopedLock {
 public:
  explicit ScopedLock(Mutex* mutex) : mutex_(mutex) { mutex_->Lock(); }
  ~ScopedLock() { mutex_->Unlock(); }

 private:
  Mutex* const mutex_;
  DISALLOW_COPY_AND_ASSIGN(ScopedLock);
};

class Monitor {
 public:
  Monitor() {}

  int Lock() { return impl_.Lock(); }
  int Unlock() { return impl_.Unlock(); }
  int Wait() { return impl_.Wait(); }
  bool Wait(uint64 microseconds) { return impl_.Wait(microseconds); }
  bool WaitUntil(uint64 microseconds_since_epoch) {
    return impl_.WaitUntil(microseconds_since_epoch);
  }
  int Notify() { return impl_.Notify(); }
  int NotifyAll() { return impl_.NotifyAll(); }

 private:
  MonitorImpl impl_;
};

class ScopedMonitorLock {
 public:
  explicit ScopedMonitorLock(Monitor* monitor) : monitor_(monitor) {
    monitor_->Lock();
  }

  ~ScopedMonitorLock() { monitor_->Unlock(); }

 private:
  Monitor* const monitor_;
  DISALLOW_COPY_AND_ASSIGN(ScopedMonitorLock);
};

class ScopedMonitorUnlock {
 public:
  explicit ScopedMonitorUnlock(Monitor* monitor) : monitor_(monitor) {
    monitor_->Unlock();
  }

  ~ScopedMonitorUnlock() { monitor_->Lock(); }

 private:
  Monitor* const monitor_;
  DISALLOW_COPY_AND_ASSIGN(ScopedMonitorUnlock);
};

inline Mutex* Platform::CreateMutex() { return new Mutex(); }

inline Monitor* Platform::CreateMonitor() { return new Monitor(); }

// TODO(kustermann): We should use native sempahores instead of basing them on
// monitors.
class Semaphore {
 public:
  explicit Semaphore(int count)
      : monitor_(Platform::CreateMonitor()), count_(count) {
  }

  ~Semaphore() {
    delete monitor_;
  }

  void Down() {
    ScopedMonitorLock locker(monitor_);
    while (count_ <= 0) {
      monitor_->Wait();
    }
    count_--;
  }

  void Up() {
    ScopedMonitorLock locker(monitor_);
    if (++count_ == 1) {
      monitor_->Notify();
    }
  }

 private:
  Monitor* monitor_;
  int count_;
};

}  // namespace dartino

#endif  // SRC_SHARED_PLATFORM_H_

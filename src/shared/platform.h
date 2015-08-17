// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_PLATFORM_H_
#define SRC_SHARED_PLATFORM_H_

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/list.h"

namespace fletch {

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
class Platform {
 public:
  enum OperatingSystem {
    kUnknownOS = 0,
    kLinux     = 1,
    kMacOS     = 2,
    kAndroid   = 3,
  };

  enum Architecture {
    kUnknownArch = 0,
    kIA32        = 1,
    kX64         = 2,
    kARM         = 3,
  };

  // Initialize the Platform class.
  static void Setup();

  // Set thread in thread local storage.
  static void SetCurrentThread(Thread* thread);

  // Get thread from thread local storage.
  static Thread* GetCurrentThread();

  // Factory method for creating platform dependent Mutex.
  // Use delete to reclaim the storage for the returned Mutex.
  static Mutex* CreateMutex();

  // Use delete to reclaim the storage for the returned Monitor.
  static Monitor* CreateMonitor();

  // Returns the number of microseconds since epoch.
  static uint64 GetMicroseconds();

  // Returns the number of microseconds since this process got started.
  static uint64 GetProcessMicroseconds();

  // Returns the number of available hardware threads.
  static int GetNumberOfHardwareThreads();

  // Load file at 'uri'.
  static List<uint8> LoadFile(const char* name);

  // Store file at 'ur'.
  static bool StoreFile(const char* uri, List<uint8> bytes);

  static const char* GetTimeZoneName(int64_t seconds_since_epoch);

  static int GetTimeZoneOffset(int64_t seconds_since_epoch);

  static int GetLocalTimeZoneOffset();

  static OperatingSystem OS() {
#if defined(__ANDROID__)
    return kAndroid;
#elif defined(__linux__)
    return kLinux;
#elif defined(__APPLE__)
    return kMacOS;
#else
    return kUnknownOS;
#endif
  }

  static Architecture Arch() {
#if defined(FLETCH_TARGET_IA32)
    return kIA32;
#elif defined(FLETCH_TARGET_X64)
    return kX64;
#elif defined(FLETCH_TARGET_ARM)
    return kARM;
#else
    return kUnknownArch;
#endif
  }
};

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
  virtual int Lock() = 0;

  // Unlocks the given mutex. The mutex is assumed to be locked and owned by
  // the calling thread on entrance.
  virtual int Unlock() = 0;

  // Returns true if the Mutex is currently locked by any thread.
  virtual bool IsLocked() = 0;
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
  virtual ~Monitor() {}
  virtual int Lock() = 0;
  virtual int Unlock() = 0;
  virtual int Wait() = 0;
  virtual bool Wait(uint64 microseconds) = 0;
  virtual bool WaitUntil(uint64 microseconds_since_epoch) = 0;
  virtual int Notify() = 0;
  virtual int NotifyAll() = 0;
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

}  // namespace fletch

#endif  // SRC_SHARED_PLATFORM_H_

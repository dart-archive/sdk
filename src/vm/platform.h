// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PLATFORM_H_
#define SRC_VM_PLATFORM_H_

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/vm/list.h"

namespace fletch {

class Thread;
class Mutex;
class Semaphore;
class Monitor;

// Interface to the underlying platform.
class Platform {
 public:
  enum OperatingSystem {
    kUnknown = 0,
    kLinux   = 1,
    kMacOS   = 2,
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

  static OperatingSystem OS() {
#if defined(__linux__)
    return kLinux;
#elif defined(__APPLE__)
    return kMacOS;
#else
    return kUnknown;
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
  virtual int Wait(int milliseconds) = 0;
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


#endif  // SRC_VM_PLATFORM_H_

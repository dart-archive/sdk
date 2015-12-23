// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_PLATFORM_WINDOWS_H_
#define SRC_SHARED_PLATFORM_WINDOWS_H_

#ifndef SRC_SHARED_PLATFORM_H_
#error Do not include platform_win.h directly; use platform.h instead.
#endif

#if defined(FLETCH_TARGET_OS_WIN)

// Prevent the windows.h header from including winsock.h and others.
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

#include "src/shared/globals.h"

#define snprintf _snprintf
#define MAXPATHLEN MAX_PATH

namespace fletch {

// Forward declare [Platform::GetMicroseconds].
namespace Platform {
uint64 GetMicroseconds();
}  // namespace Platform

class MutexImpl {
 public:
  MutexImpl() : srwlock_(SRWLOCK_INIT) { }
  ~MutexImpl() { }

  int Lock() {
    AcquireSRWLockExclusive(&srwlock_);
    return 0;
  }

  int TryLock() {
    return TryAcquireSRWLockExclusive(&srwlock_) ? 0 : 1;
  }

  int Unlock() {
    ReleaseSRWLockExclusive(&srwlock_);
    return 0;
  }

 private:
  SRWLOCK srwlock_;
};

class MonitorImpl {
 public:
  MonitorImpl() {
    InitializeSRWLock(&srwlock_);
    InitializeConditionVariable(&cond_);
  }

  ~MonitorImpl() { }

  int Lock() {
    AcquireSRWLockExclusive(&srwlock_);
    return 0;
  }

  int Unlock() {
    ReleaseSRWLockExclusive(&srwlock_);
    return 0;
  }

  int Wait() {
    AcquireSRWLockExclusive(&srwlock_);
    SleepConditionVariableSRW(&cond_, &srwlock_, INFINITE, 0);
    return 0;
  }

  bool Wait(uint64 microseconds) {
    DWORD miliseconds = microseconds / 1000;
    AcquireSRWLockExclusive(&srwlock_);
    SleepConditionVariableSRW(&cond_, &srwlock_, miliseconds, 0);
    return 0;
  }

  bool WaitUntil(uint64 microseconds_since_epoch) {
    uint64 now = Platform::GetMicroseconds();
    return Wait(microseconds_since_epoch - now);
  }

  int Notify() {
    WakeConditionVariable(&cond_);
    return 0;
  }

  int NotifyAll() {
    WakeAllConditionVariable(&cond_);
    return 0;
  }

 private:
  SRWLOCK srwlock_;
  CONDITION_VARIABLE cond_;
};

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_WIN)

#endif  // SRC_SHARED_PLATFORM_WINDOWS_H_

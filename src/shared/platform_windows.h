// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_PLATFORM_WINDOWS_H_
#define SRC_SHARED_PLATFORM_WINDOWS_H_

#ifndef SRC_SHARED_PLATFORM_H_
#error Do not include platform_win.h directly; use platform.h instead.
#endif

#if defined(FLETCH_TARGET_OS_WIN)

#include <windows.h>

#include "src/shared/globals.h"

#define snprintf _snprintf

namespace fletch {

// Forward declare [Platform::GetMicroseconds].
namespace Platform {
uint64 GetMicroseconds();
}  // namespace Platform

class MutexImpl {
 public:
  MutexImpl() : mutex_(CreateMutex(NULL, FALSE, NULL)) {}
  ~MutexImpl() { CloseHandle(mutex_); }

  int Lock() { return WaitForSingleObject(mutex_, INFINITE); }
  int TryLock() { return WaitForSingleObject(mutex_, 0); }
  int Unlock() { return ReleaseMutex(mutex_); }

 private:
  HANDLE mutex_;
};

class MonitorImpl {
 public:
  MonitorImpl() {
    InitializeCriticalSection(&mutex_);
    InitializeConditionVariable(&cond_);
  }

  ~MonitorImpl() { DeleteCriticalSection(&mutex_); }

  int Lock() {
    EnterCriticalSection(&mutex_);
    return 0;
  }

  int Unlock() {
    LeaveCriticalSection(&mutex_);
    return 0;
  }

  int Wait() {
    EnterCriticalSection(&mutex_);
    SleepConditionVariableCS(&cond_, &mutex_, INFINITE);
    return 0;
  }

  bool Wait(uint64 microseconds) {
    DWORD miliseconds = microseconds / 1000;
    EnterCriticalSection(&mutex_);
    SleepConditionVariableCS(&cond_, &mutex_, miliseconds);
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
  CRITICAL_SECTION mutex_;
  CONDITION_VARIABLE cond_;
};

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_WIN)

#endif  // SRC_SHARED_PLATFORM_WINDOWS_H_

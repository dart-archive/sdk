// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_PLATFORM_MBED_H_
#define SRC_SHARED_PLATFORM_MBED_H_

#ifndef SRC_SHARED_PLATFORM_H_
#error Do not include platform_mbed.h directly; use platform.h instead.
#endif

#if defined(FLETCH_TARGET_OS_MBED)

#include <errno.h>
#include <cmsis_os.h>

#include "src/shared/globals.h"

namespace fletch {

static const int kMutexSize = sizeof(int32_t) * 3;
static const int kSemaphoreSize = sizeof(int32_t) * 2;

// Forward declare [Platform::GetMicroseconds].
namespace Platform {
  uint64 GetMicroseconds();
}  // namespace Platform

class MutexImpl {
 public:
  MutexImpl() {
    memset((osMutex(mutex_def_))->mutex, 0, kMutexSize);
    mutex_ = osMutexCreate(osMutex(mutex_def_));
  }
  ~MutexImpl() { osMutexDelete(mutex_); }

  int Lock() { return osMutexWait(mutex_, 0); }
  int TryLock() { return osMutexWait(mutex_, 1); }
  int Unlock() { return osMutexRelease(mutex_); }

 private:
  osMutexDef(mutex_def_);
  osMutexId mutex_;
};

class MonitorImpl {
 public:
  MonitorImpl() {
    memset((osMutex(mutex_def_))->mutex, 0, kMutexSize);
    mutex_ = osMutexCreate(osMutex(mutex_def_));
    memset((osMutex(internal_def_))->mutex, 0, kMutexSize);
    internal_ = osMutexCreate(osMutex(internal_def_));
    memset((osSemaphore(semaphore_def_))->semaphore, 0, kSemaphoreSize);
    semaphore_ = osSemaphoreCreate(osSemaphore(semaphore_def_), 0);
  }

  ~MonitorImpl() {
    osMutexDelete(mutex_);
    osMutexDelete(internal_);
    osSemaphoreDelete(semaphore_);
  }

  int Lock() { return osMutexWait(mutex_, 0); }
  int Unlock() { return osMutexRelease(mutex_); }

  int Wait() {
    osMutexWait(internal_, 0);
    waiting_++;
    osMutexRelease(internal_);
    osMutexRelease(mutex_);
    osSemaphoreWait(semaphore_, 0);
    osMutexWait(mutex_, 0);
    // TODO(herhut): Check error codes.
    return 0;
  }

  bool Wait(uint64 microseconds) {
    osMutexWait(internal_, 0);
    waiting_++;
    osMutexRelease(internal_);
    osMutexRelease(mutex_);
    osSemaphoreWait(semaphore_, microseconds / 1000);
    osMutexWait(mutex_, 0);
    // TODO(herhut): Check error codes.
    return 0;
  }

  bool WaitUntil(uint64 microseconds_since_epoch) {
    uint64 us = microseconds_since_epoch - Platform::GetMicroseconds();
    return Wait(us);
  }

  int Notify() {
    osMutexWait(internal_, 0);
    bool hasWaiting = waiting_ > 0;
    if (hasWaiting) --waiting_;
    osMutexRelease(internal_);
    if (hasWaiting) {
      osSemaphoreRelease(semaphore_);
    }
    // TODO(herhut): Check error codes.
    return 0;
  }

  int NotifyAll() {
    osMutexWait(internal_, 0);
    int towake = waiting_;
    waiting_ = 0;
    osMutexRelease(internal_);
    while (towake-- > 0) {
      osSemaphoreRelease(semaphore_);
    }
    return 0;
  }

 private:
  osMutexDef(mutex_def_);
  osMutexId mutex_;
  osMutexDef(internal_def_);
  osMutexId internal_;
  osSemaphoreDef(semaphore_def_);
  osSemaphoreId(semaphore_);
  int waiting_;
};

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_MBED)

#endif  // SRC_SHARED_PLATFORM_MBED_H_

// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_PLATFORM_LK_H_
#define SRC_SHARED_PLATFORM_LK_H_

#ifndef SRC_SHARED_PLATFORM_H_
#error Do not include platform_lk.h directly; use platform.h instead.
#endif

#if defined(FLETCH_TARGET_OS_LK)

#include <err.h>
#include <kernel/thread.h>
#include <kernel/semaphore.h>

#include "src/shared/globals.h"

namespace fletch {

// Forward declare [Platform::GetMicroseconds].
namespace Platform {
  uint64 GetMicroseconds();
}  // namespace Platform

class MutexImpl {
 public:
  MutexImpl() { mutex_init(&mutex_);  }
  ~MutexImpl() { mutex_destroy(&mutex_); }

  int Lock() { return mutex_acquire(&mutex_); }
  int TryLock() { return mutex_acquire_timeout(&mutex_, 0); }
  int Unlock() { return mutex_release(&mutex_); }

 private:
  mutex_t mutex_;   // lk kernel mutex.
};

class MonitorImpl {
 public:
  MonitorImpl() {
    mutex_init(&mutex_);
    mutex_init(&internal_);
    sem_init(&sem_, 1);
  }

  ~MonitorImpl() {
    mutex_destroy(&mutex_);
    mutex_destroy(&internal_);
    sem_destroy(&sem_);
  }

  int Lock() { return mutex_acquire(&mutex_); }
  int Unlock() { return mutex_release(&mutex_); }

  int Wait() {
    mutex_acquire(&internal_);
    waiting_++;
    mutex_release(&internal_);
    mutex_release(&mutex_);
    sem_wait(&sem_);
    mutex_acquire(&mutex_);
    // TODO(herhut): check errors.
    return 0;
  }

  bool Wait(uint64 microseconds) {
    uint64 us = Platform::GetMicroseconds() + microseconds;
    return WaitUntil(us);
  }

  bool WaitUntil(uint64 microseconds_since_epoch) {
    mutex_acquire(&internal_);
    waiting_++;
    mutex_release(&internal_);
    mutex_release(&mutex_);
    // TODO(herhut): This is not really since epoch.
    status_t status = sem_timedwait(&sem_, microseconds_since_epoch);
    mutex_acquire(&mutex_);
    return status == ERR_TIMED_OUT;
  }

  int Notify() {
    mutex_acquire(&internal_);
    bool hasWaiting = waiting_ > 0;
    if (hasWaiting) --waiting_;
    mutex_release(&internal_);
    if (hasWaiting) {
      if (!sem_post(&sem_, false)) return -1;
    }
    return 0;
  }

  int NotifyAll() {
    mutex_acquire(&internal_);
    int towake = waiting_;
    waiting_ = 0;
    mutex_release(&internal_);
    while (towake-- > 0) {
     if (!sem_post(&sem_, false)) return -1;
    }
    return 0;
  }

 private:
  mutex_t mutex_;
  semaphore_t sem_;
  mutex_t internal_;
  int waiting_ = 0;
};

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_LK)

#endif  // SRC_SHARED_PLATFORM_LK_H_

// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_PLATFORM_POSIX_H_
#define SRC_SHARED_PLATFORM_POSIX_H_

#ifndef SRC_SHARED_PLATFORM_H_
#error Do not include platform_posix.h directly; use platform.h instead.
#endif

#if defined(FLETCH_TARGET_OS_POSIX)

#include <errno.h>
#include <pthread.h>

#include "src/shared/globals.h"

namespace fletch {

// Forward declare [Platform::GetMicroseconds].
namespace Platform {
  uint64 GetMicroseconds();
}  // namespace Platform

class MutexImpl {
 public:
  MutexImpl() { pthread_mutex_init(&mutex_, NULL);  }
  ~MutexImpl() { pthread_mutex_destroy(&mutex_); }

  int Lock() { return pthread_mutex_lock(&mutex_); }
  int TryLock() { return pthread_mutex_trylock(&mutex_); }
  int Unlock() { return pthread_mutex_unlock(&mutex_); }

 private:
  pthread_mutex_t mutex_;
};

class MonitorImpl {
 public:
  MonitorImpl() {
    pthread_mutex_init(&mutex_, NULL);
    pthread_cond_init(&cond_, NULL);
  }

  ~MonitorImpl() {
    pthread_mutex_destroy(&mutex_);
    pthread_cond_destroy(&cond_);
  }

  int Lock() { return pthread_mutex_lock(&mutex_); }
  int Unlock() { return pthread_mutex_unlock(&mutex_); }

  int Wait() { return pthread_cond_wait(&cond_, &mutex_); }

  bool Wait(uint64 microseconds) {
    uint64 us = Platform::GetMicroseconds() + microseconds;
    return WaitUntil(us);
  }

  bool WaitUntil(uint64 microseconds_since_epoch) {
    timespec ts;
    ts.tv_sec = microseconds_since_epoch / 1000000;
    ts.tv_nsec = (microseconds_since_epoch % 1000000) * 1000;
    return pthread_cond_timedwait(&cond_, &mutex_, &ts) == ETIMEDOUT;
  }

  int Notify() { return pthread_cond_signal(&cond_); }
  int NotifyAll() { return pthread_cond_broadcast(&cond_); }

 private:
  pthread_mutex_t mutex_;   // Pthread mutex for POSIX platforms.
  pthread_cond_t cond_;   // Pthread condition for POSIX platforms.
};

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_POSIX)

#endif  // SRC_SHARED_PLATFORM_POSIX_H_

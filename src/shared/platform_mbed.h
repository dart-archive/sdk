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

#ifdef DEBUG
#define CHECK_AND_RETURN(expr) {                                               \
  int status = expr;                                                           \
  if (status != osOK) {                                                        \
    char const *msg;                                                           \
    switch (status) {                                                          \
      case osErrorISR:                                                         \
        msg = "osErrorISR";                                                    \
        break;                                                                 \
      case osErrorResource:                                                    \
        msg = "osErrorResource";                                               \
        break;                                                                 \
      case osErrorParameter:                                                   \
        msg = "osErrorParameter";                                              \
        break;                                                                 \
      case osErrorTimeoutResource:                                             \
        msg = "osErrorTimeoutResource";                                        \
        break;                                                                 \
      default:                                                                 \
        msg = "<other>";                                                       \
    }                                                                          \
    printf("System call failed: %s at %s:%d.\n", msg, __FILE__, __LINE__);     \
    fflush(stdout);                                                            \
    return status;                                                             \
  }                                                                            \
}

#define CHECK_AND_FAIL(expr) {                                                 \
  int status = expr;                                                           \
  if (status != osOK) {                                                        \
    char const *msg;                                                           \
    switch (status) {                                                          \
      case osErrorISR:                                                         \
        msg = "osErrorISR";                                                    \
        break;                                                                 \
      case osErrorResource:                                                    \
        msg = "osErrorResource";                                               \
        break;                                                                 \
      case osErrorParameter:                                                   \
        msg = "osErrorParameter";                                              \
        break;                                                                 \
      case osErrorTimeoutResource:                                             \
        msg = "osErrorTimeoutResource";                                        \
        break;                                                                 \
      default:                                                                 \
        msg = "<other>";                                                       \
    }                                                                          \
    printf("System call failed: %s at %s:%d.\n", msg, __FILE__, __LINE__);     \
    fflush(stdout);                                                            \
    abort();                                                                   \
  }                                                                            \
}
#else
#define CHECK_AND_RETURN(expr) {                                               \
  int status = expr;                                                           \
  if (status != osOK) return status;                                           \
}
#define CHECK_AND_FAIL(expr) {                                                 \
  int status = expr;                                                           \
  if (status != osOK) {                                                        \
    FATAL("System call failed.\n");                                            \
  }                                                                            \
}
#endif

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
    ASSERT(mutex_ != NULL);
  }
  ~MutexImpl() { osMutexDelete(mutex_); }

  int Lock() { return osMutexWait(mutex_, osWaitForever); }
  int TryLock() { return osMutexWait(mutex_, 0); }
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
    ASSERT(mutex_ != NULL);
    memset((osMutex(internal_def_))->mutex, 0, kMutexSize);
    internal_ = osMutexCreate(osMutex(internal_def_));
    ASSERT(internal_ != NULL);
    memset((osSemaphore(semaphore_def_))->semaphore, 0, kSemaphoreSize);
    semaphore_ = osSemaphoreCreate(osSemaphore(semaphore_def_), 0);
    ASSERT(semaphore_ != NULL);
    waiting_ = 0;
  }

  ~MonitorImpl() {
    osMutexDelete(mutex_);
    osMutexDelete(internal_);
    osSemaphoreDelete(semaphore_);
  }

  int Lock() { return osMutexWait(mutex_, osWaitForever); }
  int Unlock() { return osMutexRelease(mutex_); }

  int Wait() {
    CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
    waiting_++;
    CHECK_AND_FAIL(osMutexRelease(internal_));
    CHECK_AND_RETURN(osMutexRelease(mutex_));
    int tokens = osSemaphoreWait(semaphore_, osWaitForever);
    ASSERT(tokens > 0);  // There should have been at least one token.
    CHECK_AND_RETURN(osMutexWait(mutex_, osWaitForever));
    return osOK;
  }

  bool Wait(uint64 microseconds) {
    CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
    waiting_++;
    CHECK_AND_FAIL(osMutexRelease(internal_));
    CHECK_AND_FAIL(osMutexRelease(mutex_));
    int tokens = osSemaphoreWait(semaphore_, microseconds / 1000);
    if (tokens == 0) {  // Timeout occured.
      CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
      --waiting_;
      CHECK_AND_FAIL(osMutexRelease(internal_));
    }
    CHECK_AND_RETURN(osMutexWait(mutex_, osWaitForever));
    return osOK;
  }

  bool WaitUntil(uint64 microseconds_since_epoch) {
    uint64 us = microseconds_since_epoch - Platform::GetMicroseconds();
    return Wait(us);
  }

  int Notify() {
    CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
    bool hasWaiting = waiting_ > 0;
    if (hasWaiting) --waiting_;
    CHECK_AND_FAIL(osMutexRelease(internal_));
    if (hasWaiting) {
      CHECK_AND_FAIL(osSemaphoreRelease(semaphore_));
    }
    return osOK;
  }

  int NotifyAll() {
    CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
    int towake = waiting_;
    waiting_ = 0;
    CHECK_AND_FAIL(osMutexRelease(internal_));
    while (towake-- > 0) {
      CHECK_AND_FAIL(osSemaphoreRelease(semaphore_));
    }
    return osOK;
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

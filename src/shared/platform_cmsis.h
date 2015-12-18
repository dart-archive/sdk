// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_PLATFORM_CMSIS_H_
#define SRC_SHARED_PLATFORM_CMSIS_H_

#ifndef SRC_SHARED_PLATFORM_H_
#error Do not include platform_cmsis.h directly; use platform.h instead.
#endif

#if defined(FLETCH_TARGET_OS_CMSIS)

#include <errno.h>
#include <cmsis_os.h>

#include "src/shared/globals.h"

#ifdef DEBUG
#define CHECK_AND_RETURN(expr)                                               \
  {                                                                          \
    int status = expr;                                                       \
    if (status != osOK) {                                                    \
      char const *msg;                                                       \
      switch (status) {                                                      \
        case osErrorISR:                                                     \
          msg = "osErrorISR";                                                \
          break;                                                             \
        case osErrorResource:                                                \
          msg = "osErrorResource";                                           \
          break;                                                             \
        case osErrorParameter:                                               \
          msg = "osErrorParameter";                                          \
          break;                                                             \
        case osErrorTimeoutResource:                                         \
          msg = "osErrorTimeoutResource";                                    \
          break;                                                             \
        default:                                                             \
          msg = "<other>";                                                   \
      }                                                                      \
      printf("System call failed: %s at %s:%d.\n", msg, __FILE__, __LINE__); \
      fflush(stdout);                                                        \
      return status;                                                         \
    }                                                                        \
  }

#define CHECK_AND_FAIL(expr)                                                 \
  {                                                                          \
    int status = expr;                                                       \
    if (status != osOK) {                                                    \
      char const *msg;                                                       \
      switch (status) {                                                      \
        case osErrorISR:                                                     \
          msg = "osErrorISR";                                                \
          break;                                                             \
        case osErrorResource:                                                \
          msg = "osErrorResource";                                           \
          break;                                                             \
        case osErrorParameter:                                               \
          msg = "osErrorParameter";                                          \
          break;                                                             \
        case osErrorTimeoutResource:                                         \
          msg = "osErrorTimeoutResource";                                    \
          break;                                                             \
        default:                                                             \
          msg = "<other>";                                                   \
      }                                                                      \
      printf("System call failed: %s at %s:%d.\n", msg, __FILE__, __LINE__); \
      fflush(stdout);                                                        \
      abort();                                                               \
    }                                                                        \
  }
#else
#define CHECK_AND_RETURN(expr)         \
  {                                    \
    int status = expr;                 \
    if (status != osOK) return status; \
  }
#define CHECK_AND_FAIL(expr)          \
  {                                   \
    int status = expr;                \
    if (status != osOK) {             \
      FATAL("System call failed.\n"); \
    }                                 \
  }
#endif

namespace fletch {

static const int kMutexSize = sizeof(int32_t) * 3;
static const int kSemaphoreSize = sizeof(int32_t) * 2;
static const int kMaxSemaphoreValue = 1024;

// Forward declare [Platform::GetMicroseconds].
namespace Platform {
uint64 GetMicroseconds();
}  // namespace Platform

class MutexImpl {
 public:
  MutexImpl() {
#ifdef CMSIS_OS_RTX
    memset((osMutex(mutex_def_))->mutex, 0, kMutexSize);
#endif
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
#ifdef CMSIS_OS_RTX
    memset((osMutex(mutex_def_))->mutex, 0, kMutexSize);
    memset((osMutex(internal_def_))->mutex, 0, kMutexSize);
    memset((osSemaphore(semaphore_def_))->semaphore, 0, kSemaphoreSize);
#endif
    mutex_ = osMutexCreate(osMutex(mutex_def_));
    ASSERT(mutex_ != NULL);
    internal_ = osMutexCreate(osMutex(internal_def_));
    ASSERT(internal_ != NULL);
    semaphore_ = osSemaphoreCreate(osSemaphore(semaphore_def_),
                                   kMaxSemaphoreValue);
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
#ifdef CMSIS_OS_RTX
    int tokens = osSemaphoreWait(semaphore_, osWaitForever);
    ASSERT(tokens > 0);  // There should have been at least one token.
#else
    // The implementation in STM32CubeF7 returns osOK if the
    // semaphore was acquired.
    // See https://github.com/dart-lang/fletch/issues/377.
    CHECK_AND_FAIL(osSemaphoreWait(semaphore_, osWaitForever));
#endif
    CHECK_AND_RETURN(osMutexWait(mutex_, osWaitForever));
    return osOK;
  }

  bool Wait(uint64 microseconds) {
    bool success = true;
    CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
    waiting_++;
    CHECK_AND_FAIL(osMutexRelease(internal_));
    CHECK_AND_FAIL(osMutexRelease(mutex_));
#ifdef CMSIS_OS_RTX
    int tokens = osSemaphoreWait(semaphore_, microseconds / 1000);
    success = (tokens == 0);
#else
    // The implementation in STM32CubeF7 returns osOK if the
    // semaphore was acquired and osErrorOS if it was not.
    // See https://github.com/dart-lang/fletch/issues/377.
    int status = osSemaphoreWait(semaphore_, microseconds / 1000);
    success = (status == osOK);
#endif
    if (!success) {
      CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
      --waiting_;
      CHECK_AND_FAIL(osMutexRelease(internal_));
    }
    CHECK_AND_RETURN(osMutexWait(mutex_, osWaitForever));
    return success;
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

#endif  // defined(FLETCH_TARGET_OS_CMSIS)

#endif  // SRC_SHARED_PLATFORM_CMSIS_H_

// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_PLATFORM_CMSIS_H_
#define SRC_SHARED_PLATFORM_CMSIS_H_

#ifndef SRC_SHARED_PLATFORM_H_
#error Do not include platform_cmsis.h directly; use platform.h instead.
#endif

#if defined(DARTINO_TARGET_OS_CMSIS)

#include <errno.h>
#include <cmsis_os.h>

#include "src/vm/vector.h"
#include "src/shared/globals.h"

#ifdef DEBUG
#define LOG_STATUS_MESSAGE                                                   \
      char const *msg;                                                       \
      switch (status) {                                                      \
        case osErrorOS:                                                      \
          msg = "osErrorOS";                                                 \
          break;                                                             \
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
      printf("System call failed: %s (%d) at %s:%d.\n",                      \
             msg, status, __FILE__, __LINE__);                               \
      fflush(stdout);                                                        \

#define CHECK_AND_RETURN(expr)                                               \
  {                                                                          \
    int status = expr;                                                       \
    if (status != osOK) {                                                    \
      LOG_STATUS_MESSAGE                                                     \
      return status;                                                         \
    }                                                                        \
  }

#define CHECK_AND_FAIL(expr)                                                 \
  {                                                                          \
    int status = expr;                                                       \
    if (status != osOK) {                                                    \
      LOG_STATUS_MESSAGE                                                     \
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

namespace dartino {

static const int kMutexSize = sizeof(int32_t) * 3;
static const int kSemaphoreSize = sizeof(int32_t) * 2;

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
#endif
    mutex_ = osMutexCreate(osMutex(mutex_def_));
    ASSERT(mutex_ != NULL);
    internal_ = osMutexCreate(osMutex(internal_def_));
    ASSERT(internal_ != NULL);
    first_waiting_ = NULL;
    last_waiting_ = NULL;
  }

  ~MonitorImpl() {
    osMutexDelete(mutex_);
    osMutexDelete(internal_);
  }

  int Lock() { return osMutexWait(mutex_, osWaitForever); }
  int Unlock() { return osMutexRelease(mutex_); }

  int Wait() {
    CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
    WaitListEntry wait_entry;
    AddToWaitList(&wait_entry);
    CHECK_AND_FAIL(osMutexRelease(internal_));
    CHECK_AND_RETURN(osMutexRelease(mutex_));
#ifdef CMSIS_OS_RTX
    int tokens = osSemaphoreWait(wait_entry.semaphore_, osWaitForever);
    ASSERT(tokens > 0);  // There should have been at least one token.
#else
    // The implementation in STM32CubeF7 returns osOK if the
    // semaphore was acquired.
    // See https://github.com/dartino/sdk/issues/377.
    CHECK_AND_FAIL(osSemaphoreWait(wait_entry.semaphore_, osWaitForever));
#endif
    CHECK_AND_RETURN(osMutexWait(mutex_, osWaitForever));
    return osOK;
  }

  bool Wait(uint64 microseconds) {
    CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
    WaitListEntry wait_entry;
    AddToWaitList(&wait_entry);
    CHECK_AND_FAIL(osMutexRelease(internal_));
    CHECK_AND_FAIL(osMutexRelease(mutex_));
#ifdef CMSIS_OS_RTX
    int tokens = osSemaphoreWait(wait_entry.semaphore_, microseconds / 1000);
    bool waited_successfully = (tokens == 0);
#else
    // The implementation in STM32CubeF7 returns osOK if the
    // semaphore was acquired and osErrorOS if it was not.
    // See https://github.com/dartino/sdk/issues/377.
    int status = osSemaphoreWait(wait_entry.semaphore_, microseconds / 1000);
    bool waited_successfully = (status == osErrorOS);
#endif
    if (waited_successfully) {
      CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
      // Remove our entry from the waitlist. If we are no longer in the list,
      // we have been notified before we could complete handling the timeout,
      // so we need to return false.
      if (!MaybeRemoveFromWaitList(&wait_entry)) waited_successfully = false;
      CHECK_AND_FAIL(osMutexRelease(internal_));
    }
    CHECK_AND_RETURN(osMutexWait(mutex_, osWaitForever));
    return waited_successfully;
  }

  bool WaitUntil(uint64 microseconds_since_epoch) {
    int64 us = microseconds_since_epoch - Platform::GetMicroseconds();
    if (us < 0) us = 0;
    return Wait(us);
  }

  int Notify() {
    CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
    WaitListEntry* to_notify = first_waiting_;
    if (to_notify != NULL) {
      if (first_waiting_ == last_waiting_) last_waiting_ = NULL;
      first_waiting_ = first_waiting_->next_;
    }
    CHECK_AND_FAIL(osMutexRelease(internal_));
    if (to_notify != NULL) {
      CHECK_AND_FAIL(osSemaphoreRelease(to_notify->semaphore_));
    }
    return osOK;
  }

  int NotifyAll() {
    CHECK_AND_FAIL(osMutexWait(internal_, osWaitForever));
    WaitListEntry* wake_list = first_waiting_;
    first_waiting_ = NULL;
    last_waiting_ = NULL;
    CHECK_AND_FAIL(osMutexRelease(internal_));
    while (wake_list != NULL) {
      // Grab the next value here. Releasing the semaphore can cause
      // the waiting thread to start running, which will cause the
      // stack allocated WaitListEntry to become invalid.
      WaitListEntry* next = wake_list->next_;
      CHECK_AND_FAIL(osSemaphoreRelease(wake_list->semaphore_));
      wake_list = next;
    }
    return osOK;
  }

 private:
  class WaitListEntry {
   public:
    WaitListEntry() {
  #ifdef CMSIS_OS_RTX
      memset((osSemaphore(semaphore_def_))->semaphore, 0, kSemaphoreSize);
      // In the KEIL implementation the 'count' argument in interpreted
      // as the number of resources initially available.
      semaphore_ = osSemaphoreCreate(osSemaphore(semaphore_def_), 0);
  #else
      // In the STM32CubeF7 FreeRTOS port of CMSIS-RTOS the 'count'
      // argument in interpreted as the maximum of resources
      // available, and therefore the second argument should be one
      // (1) here. However if the value is *exactly* one (1) it is
      // actually the number of resources initially available. The
      // reason for that is that when 'count' is one a binary
      // semaphore is created using the FreeRTOS macro
      // vSemaphoreCreateBinary which creates the semahopre as
      // available. The function xSemaphoreCreateBinary should have
      // been used, as that creates a binary semaphore which is not
      // initially available.
      semaphore_ = osSemaphoreCreate(osSemaphore(semaphore_def_), 2);
  #endif
      ASSERT(semaphore_ != NULL);
      next_ = NULL;
    }

    ~WaitListEntry() {
      osSemaphoreDelete(semaphore_);
    }

    osSemaphoreDef(semaphore_def_);
    osSemaphoreId(semaphore_);
    WaitListEntry* next_;
  };

  void AddToWaitList(WaitListEntry* wait_entry) {
    if (first_waiting_ == NULL) {
      ASSERT(last_waiting_ == NULL);
      first_waiting_ = wait_entry;
    } else {
      ASSERT(last_waiting_ != NULL);
      last_waiting_->next_ = wait_entry;
    }
    last_waiting_ = wait_entry;
  }

  // Removes [wait_entry] from the wait list and returns true on success.
  bool MaybeRemoveFromWaitList(WaitListEntry* wait_entry) {
    WaitListEntry* prev = NULL;
    WaitListEntry* curr = first_waiting_;
    while (curr != wait_entry) {
      // If we are no longer in the list, we do not need to clean up.
      if (curr == last_waiting_) return false;
      prev = curr;
      curr = curr->next_;
    }
    if (prev == NULL) {
      first_waiting_ = wait_entry->next_;
    } else {
      prev->next_ = wait_entry->next_;
    }
    if (last_waiting_ == wait_entry) {
      last_waiting_ = prev;
    }
    return true;
  }

  osMutexDef(mutex_def_);
  osMutexId mutex_;
  osMutexDef(internal_def_);
  osMutexId internal_;

  WaitListEntry* first_waiting_;
  WaitListEntry* last_waiting_;
};

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_CMSIS)

#endif  // SRC_SHARED_PLATFORM_CMSIS_H_

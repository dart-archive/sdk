// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
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

#define CHECK_AND_RETURN(expr)             \
  {                                        \
    int status = expr;                     \
    if (status != NO_ERROR) return status; \
  }
#define CHECK_AND_FAIL(expr)          \
  {                                   \
    int status = expr;                \
    if (status != NO_ERROR) {         \
      FATAL("System call failed.\n"); \
    }                                 \
  }

namespace fletch {

// Forward declare [Platform::GetMicroseconds].
namespace Platform {
uint64 GetMicroseconds();
}  // namespace Platform

class MutexImpl {
 public:
  MutexImpl() { mutex_init(&mutex_); }
  ~MutexImpl() { mutex_destroy(&mutex_); }

  int Lock() { return mutex_acquire(&mutex_); }
  int TryLock() { return mutex_acquire_timeout(&mutex_, 0); }
  int Unlock() { return mutex_release(&mutex_); }

 private:
  mutex_t mutex_;  // lk kernel mutex.
};

class MonitorImpl {
 public:
  MonitorImpl() {
    mutex_init(&mutex_);
    mutex_init(&internal_);
    first_waiting_ = NULL;
    last_waiting_ = NULL;
  }

  ~MonitorImpl() {
    mutex_destroy(&mutex_);
    mutex_destroy(&internal_);
  }

  int Lock() { return mutex_acquire(&mutex_); }
  int Unlock() { return mutex_release(&mutex_); }

  int Wait() {
    CHECK_AND_FAIL(mutex_acquire(&internal_));
    WaitListEntry wait_entry;
    AddToWaitList(&wait_entry);
    CHECK_AND_FAIL(mutex_release(&internal_));
    CHECK_AND_FAIL(mutex_release(&mutex_));
    CHECK_AND_FAIL(sem_wait(&wait_entry.semaphore_));
    CHECK_AND_RETURN(mutex_acquire(&mutex_));
    return 0;
  }

  bool Wait(uint64 microseconds) {
    CHECK_AND_FAIL(mutex_acquire(&internal_));
    WaitListEntry wait_entry;
    AddToWaitList(&wait_entry);
    CHECK_AND_FAIL(mutex_release(&internal_));
    CHECK_AND_FAIL(mutex_release(&mutex_));
    int result =
        sem_timedwait(&wait_entry.semaphore_, microseconds / 1000) == NO_ERROR;
    if (result != NO_ERROR) {
      CHECK_AND_FAIL(mutex_acquire(&internal_));
      MaybeRemoveFromWaitList(&wait_entry);
      CHECK_AND_FAIL(mutex_release(&internal_));
    }
    CHECK_AND_RETURN(mutex_acquire(&mutex_));
    return result != NO_ERROR;
  }

  bool WaitUntil(uint64 microseconds_since_epoch) {
    uint64 us = microseconds_since_epoch - Platform::GetMicroseconds();
    return Wait(us);
  }

  int Notify() {
    CHECK_AND_FAIL(mutex_acquire(&internal_));
    WaitListEntry* to_notify = first_waiting_;
    if (to_notify != NULL) {
      if (first_waiting_ == last_waiting_) last_waiting_ = NULL;
      first_waiting_ = first_waiting_->next_;
    }
    CHECK_AND_FAIL(mutex_release(&internal_));
    if (to_notify != NULL) sem_post(&to_notify->semaphore_, false);
    return 0;
  }

  int NotifyAll() {
    CHECK_AND_FAIL(mutex_acquire(&internal_));
    WaitListEntry* wake_list = first_waiting_;
    first_waiting_ = NULL;
    last_waiting_ = NULL;
    CHECK_AND_FAIL(mutex_release(&internal_));
    while (wake_list != NULL) {
      // Grab the next value here. Releasing the semaphore can cause
      // the waiting thread to start running, which will cause the
      // stack allocated WaitListEntry to become invalid.
      WaitListEntry* next = wake_list->next_;
      sem_post(&wake_list->semaphore_, false);
      wake_list = next;
    }
    return 0;
  }

 private:
  class WaitListEntry {
   public:
    WaitListEntry() {
      sem_init(&semaphore_, 0);
      next_ = NULL;
    }

    ~WaitListEntry() {
      sem_destroy(&semaphore_);
    }

    semaphore_t semaphore_;
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

  void MaybeRemoveFromWaitList(WaitListEntry* wait_entry) {
    WaitListEntry* prev = NULL;
    WaitListEntry* curr = first_waiting_;
    while (curr != wait_entry) {
      // If we are no longer in the list, we do not need to clean up.
      if (curr == last_waiting_) return;
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
  }

  mutex_t mutex_;
  mutex_t internal_;

  WaitListEntry* first_waiting_;
  WaitListEntry* last_waiting_;
};

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_LK)

#endif  // SRC_SHARED_PLATFORM_LK_H_

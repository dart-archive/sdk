// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <pthread.h>
#include <unistd.h>

#include "src/shared/assert.h"
#include "src/vm/platform.h"
#include "src/vm/thread.h"
#include "src/shared/test_case.h"

namespace fletch {

static void yield() {
  usleep(1);
}

static const int kLockCounterLimit = 50;
static int busy_lock_counter = 0;


static void LoopIncrement(Mutex* mutex, int rem) {
  while (true) {
    int count = 0;
    int last_count = -1;
    do {
      EXPECT_EQ(0, mutex->Lock());
      count = busy_lock_counter;
      EXPECT_EQ(0, mutex->Unlock());
      yield();
    } while (count % 2 == rem && count < kLockCounterLimit);
    if (count >= kLockCounterLimit) break;
    EXPECT_EQ(0, mutex->Lock());
    EXPECT_EQ(count, busy_lock_counter);
    EXPECT(last_count == -1 || count == last_count + 1);
    busy_lock_counter++;
    last_count = count;
    EXPECT_EQ(0, mutex->Unlock());
    yield();
  }
}

static void* RunTestBusyLock(void* arg) {
  LoopIncrement(static_cast<Mutex*>(arg), 0);
  return 0;
}

// Runs two threads that repeatedly acquire the lock and conditionally
// increment a variable.
TEST_CASE(Mutex) {
  pthread_t other;
  Mutex* mutex = Platform::CreateMutex();
  int thread_created = pthread_create(&other,
                                      NULL,
                                      &RunTestBusyLock,
                                      mutex);
  EXPECT_EQ(0, thread_created);
  LoopIncrement(mutex, 1);
  pthread_join(other, NULL);
  delete mutex;
}

}  // namespace fletch

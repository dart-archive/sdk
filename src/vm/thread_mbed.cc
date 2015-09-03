// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_MBED)

#include "src/vm/thread.h"  // NOLINT we don't include thread_posix.h.

#include <errno.h>
#include <stdio.h>

#include "src/shared/platform.h"

#include "src/shared/utils.h"

namespace fletch {

static const int kNumberOfFletchThreads = 2;
static const int kFletchStackSize = 1024;
static const int kFletchStackSizeInWords = kFletchStackSize / sizeof(uint32_t);

static osThreadDef_t mbed_thread_pool[FLETCH_NUMBER_OF_THREADS];
static char mbed_thread_no = 0;
static uint32_t mbed_stack[kNumberOfFletchThreads][kFletchStackSizeInWords];

bool Thread::IsCurrent(const ThreadIdentifier* thread) {
  return thread->IsSelf();
}

ThreadIdentifier Thread::Run(RunSignature run, void* data) {
  int thread_no = mbed_thread_no++;
  ASSERT(thread_no < FLETCH_NUMBER_OF_THREADS);
  osThreadDef_t* threadDef = &(mbed_thread_pool[thread_no]);
  threadDef->pthread = reinterpret_cast<void (*)(const void*)>(run);
  threadDef->tpriority = osPriorityNormal;
  threadDef->stacksize = FLETCH_STACK_SIZE;
  threadDef->stack_pointer = mbed_stack[thread_no];

  osThreadId thread = osThreadCreate(threadDef, data);

  if (thread == NULL) {
    FATAL("osThreadCreate failed\n");
  }
  return ThreadIdentifier(thread);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_MBED)

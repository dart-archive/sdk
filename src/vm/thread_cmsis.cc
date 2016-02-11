// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_CMSIS)

#include "src/vm/thread.h"  // NOLINT we don't include thread_posix.h.

#include <errno.h>
#include <stdio.h>

#include "src/shared/platform.h"

#include "src/shared/utils.h"

namespace dartino {

static const int kNumberOfDartinoThreads = 8;
static const int kDartinoStackSize = 2048;
static const int kDartinoStackSizeInWords =
    kDartinoStackSize / sizeof(uint32_t);

static osThreadDef_t cmsis_thread_pool[kNumberOfDartinoThreads];
static char cmsis_thread_no = 0;
#ifdef CMSIS_OS_RTX
static uint32_t cmsis_stack[kNumberOfDartinoThreads][kDartinoStackSizeInWords];
#endif

static const char* base_name = "cmsis_thread_";

void Thread::SetProcess(Process* process) {
  // Unused since tick sample is not available on cmsis.
}

Process* Thread::GetProcess() {
  // Unused since tick sample is not available on cmsis.
  return NULL;
}

bool Thread::IsCurrent(const ThreadIdentifier* thread) {
  return thread->IsSelf();
}

void Thread::Setup() {}

void Thread::TearDown() {}

void Thread::SetupOSSignals() {
  // Platform doesn't have signals.
}

void Thread::TeardownOSSignals() {
  // Platform doesn't have signals.
}

ThreadIdentifier Thread::Run(RunSignature run, void* data) {
  char* name = reinterpret_cast<char*>(malloc(strlen(base_name) + 5));

  snprintf(name, strlen(base_name) + 5, "cmsis_thread%d", cmsis_thread_no);
  int thread_no = cmsis_thread_no++;
  ASSERT(thread_no < kNumberOfDartinoThreads);
  osThreadDef_t* threadDef = &(cmsis_thread_pool[thread_no]);
  threadDef->pthread = reinterpret_cast<void (*)(const void*)>(run);
  threadDef->tpriority = osPriorityNormal;
  threadDef->stacksize = kDartinoStackSize;
  threadDef->name = const_cast<char*>(name);
#ifdef CMSIS_OS_RTX
  threadDef->stack_pointer = cmsis_stack[thread_no];
#endif

  osThreadId thread = osThreadCreate(threadDef, data);

  if (thread == NULL) {
    FATAL("osThreadCreate failed\n");
  }
  return ThreadIdentifier(thread);
}

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_CMSIS)

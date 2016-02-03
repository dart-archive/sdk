// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_LK)

#include "src/vm/thread.h"  // NOLINT we don't include thread_posix.h.

#include <errno.h>
#include <stdio.h>

#include "src/shared/platform.h"

namespace dartino {

void Thread::SetProcess(Process* process) {
  // Unused since tick sample is not available on LK.
}

Process* Thread::GetProcess() {
  // Unused since tick sample is not available on LK.
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
  // TODO(herhut): lk threads have int return values.
  thread_t* thread =
      thread_create("Dart thread", reinterpret_cast<thread_start_routine>(run),
                    data, DEFAULT_PRIORITY, 4096 /* stack size */);
  int result = thread_resume(thread);
  if (result != 0) {
    fprintf(stderr, "Error %d", result);
  }
  return ThreadIdentifier(thread);
}

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_LK)

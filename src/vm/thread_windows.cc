// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_WIN)

#include "src/vm/thread.h"  // NOLINT we don't include thread_posix.h.

#include "src/shared/platform.h"
#include "src/shared/utils.h"

namespace fletch {

static const int kFletchStackSize = 4096;

void Thread::SetProcess(Process* process) {
  // Unused since tick sample is not available on Windows.
}

Process* Thread::GetProcess() {
  // Unused since tick sample is not available on Windows.
  return NULL;
}

bool Thread::IsCurrent(const ThreadIdentifier* thread) {
  return thread->IsSelf();
}

void Thread::SetupOSSignals() {
  // Platform doesn't have signals.
}

void Thread::TeardownOSSignals() {
  // Platform doesn't have signals.
}

ThreadIdentifier Thread::Run(RunSignature run, void* data) {
  HANDLE thread = CreateThread(NULL, kFletchStackSize,
                               reinterpret_cast<LPTHREAD_START_ROUTINE>(run),
                               data, 0, NULL);
  if (thread == NULL) {
    FATAL("CreateThread failed\n");
  }
  return ThreadIdentifier(thread);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_WIN)

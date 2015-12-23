// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

#include "src/vm/thread.h"  // NOLINT we don't include thread_posix.h.

#include <errno.h>
#include <signal.h>
#include <stdio.h>

#include "src/shared/platform.h"

#include "src/shared/utils.h"

namespace fletch {

bool Thread::IsCurrent(const ThreadIdentifier* thread) {
  return thread->IsSelf();
}

void Thread::BlockOSSignals() {
  sigset_t set;
  sigfillset(&set);
  if (pthread_sigmask(SIG_BLOCK, &set, NULL) != 0) {
    FATAL("Failed to block signal on thread");
  }
}

void Thread::UnblockOSSignals() {
  sigset_t set;
  sigfillset(&set);
  if (pthread_sigmask(SIG_UNBLOCK, &set, NULL) != 0) {
    FATAL("Failed to unblock signal on thread");
  }
}

ThreadIdentifier Thread::Run(RunSignature run, void* data) {
  pthread_t thread;
  int result = pthread_create(&thread, NULL, run, data);
  if (result != 0) {
    if (result == EAGAIN) {
      Print::Error("Insufficient resources\n");
    } else {
      Print::Error("Error %d", result);
    }
    FATAL1("pthread_create failed with error %d\n", result);
  }
  return ThreadIdentifier(thread);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_POSIX)
